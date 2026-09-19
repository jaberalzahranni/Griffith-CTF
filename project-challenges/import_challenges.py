#!/usr/bin/env python3
import argparse
import hashlib
import json
import shutil
import uuid
from pathlib import Path

from CTFd import create_app
from CTFd.models import db
from sqlalchemy import MetaData, Table, select

ROOT = Path(__file__).resolve().parent
CHALLENGES_ROOT = ROOT / "challenges"

def load_items():
    items = []
    for folder in sorted(CHALLENGES_ROOT.iterdir()):
        if not folder.is_dir():
            continue
        f = folder / "challenge.json"
        if f.exists():
            data = json.loads(f.read_text(encoding="utf-8"))
            data["_folder"] = folder
            items.append(data)
    return items

def main(apply=False):
    app = create_app()
    with app.app_context():
        items = load_items()
        if not items:
            raise SystemExit("No challenge.json files found.")

        md = MetaData()
        names = ["challenges", "flags", "hints", "files"]
        tables = {n: Table(n, md, autoload_with=db.engine) for n in names}

        print(f"Found {len(items)} challenges:")
        for c in items:
            print(
                f"- {c['name']} | {c['category']} | {c['value']} pts | "
                f"{len(c.get('hints', []))} hints | file: {c.get('file')}"
            )

        # Validate everything before any write.
        for c in items:
            if c.get("type") != "standard":
                raise ValueError(f"Unsupported challenge type: {c['name']}")
            evidence = c["_folder"] / "files" / c["file"]
            if not evidence.is_file():
                raise FileNotFoundError(f"Missing evidence file for {c['name']}: {evidence}")

        if not apply:
            print("\nPREVIEW ONLY. No database changes were made.")
            return

        upload_folder = Path(app.config["UPLOAD_FOLDER"])
        if not upload_folder.is_absolute():
            upload_folder = Path(app.root_path) / upload_folder
        upload_folder.mkdir(parents=True, exist_ok=True)

        copied_dirs = []

        try:
            with db.engine.begin() as conn:
                # Stop rather than overwrite an existing challenge.
                for c in items:
                    exists = conn.execute(
                        select(tables["challenges"].c.id)
                        .where(tables["challenges"].c.name == c["name"])
                    ).first()
                    if exists:
                        raise ValueError(
                            f"Challenge already exists: {c['name']}. "
                            "Nothing existing will be overwritten."
                        )

                for c in items:
                    challenge_vals = {
                        "name": c["name"],
                        "category": c["category"],
                        "description": c["description"],
                        "value": c["value"],
                        "type": "standard",
                        "state": c.get("state", "visible"),
                        "logic": c.get("logic", "any"),
                        "max_attempts": c.get("max_attempts", 0),
                        "function": "static",
                    }
                    challenge_vals = {
                        k: v for k, v in challenge_vals.items()
                        if k in tables["challenges"].c
                    }
                    res = conn.execute(tables["challenges"].insert().values(**challenge_vals))
                    challenge_id = res.inserted_primary_key[0]

                    # Static flag.
                    flag = c["flag"]
                    flag_vals = {
                        "challenge_id": challenge_id,
                        "type": flag.get("type", "static"),
                        "content": flag["content"],
                        "data": flag.get("data", ""),
                    }
                    flag_vals = {k: v for k, v in flag_vals.items() if k in tables["flags"].c}
                    conn.execute(tables["flags"].insert().values(**flag_vals))

                    # Hints, including simple sequential prerequisites.
                    hint_ids = []
                    for h in c.get("hints", []):
                        hint_vals = {
                            "challenge_id": challenge_id,
                            "type": "standard",
                            "title": h.get("title"),
                            "content": h["content"],
                            "cost": h.get("cost", 0),
                            "requirements": None,
                        }
                        hint_vals = {k: v for k, v in hint_vals.items() if k in tables["hints"].c}
                        hr = conn.execute(tables["hints"].insert().values(**hint_vals))
                        hint_ids.append(hr.inserted_primary_key[0])

                    if "requirements" in tables["hints"].c:
                        for idx, h in enumerate(c.get("hints", [])):
                            req_index = h.get("requires")
                            if req_index is not None and req_index < len(hint_ids):
                                req = json.dumps({"prerequisites": [hint_ids[req_index]]})
                                conn.execute(
                                    tables["hints"].update()
                                    .where(tables["hints"].c.id == hint_ids[idx])
                                    .values(requirements=req)
                                )

                    # Challenge attachment.
                    source = c["_folder"] / "files" / c["file"]
                    target_dir = upload_folder / uuid.uuid4().hex
                    target_dir.mkdir(parents=True, exist_ok=False)
                    copied_dirs.append(target_dir)
                    target = target_dir / source.name
                    shutil.copy2(source, target)
                    location = target.relative_to(upload_folder).as_posix()

                    file_vals = {
                        "type": "challenge",
                        "location": location,
                        "challenge_id": challenge_id,
                        "page_id": None,
                        "solution_id": None,
                        "sha1sum": hashlib.sha1(source.read_bytes()).hexdigest(),
                    }
                    file_vals = {k: v for k, v in file_vals.items() if k in tables["files"].c}
                    conn.execute(tables["files"].insert().values(**file_vals))

            try:
                from CTFd.cache import cache
                cache.clear()
            except Exception:
                pass

            print("\nIMPORT COMPLETE.")
        except Exception:
            for d in copied_dirs:
                shutil.rmtree(d, ignore_errors=True)
            raise

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    main(args.apply)

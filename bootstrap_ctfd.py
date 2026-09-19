import os
import sys

from CTFd import create_app
from CTFd.models import Admins, Pages, Users, db
from CTFd.utils import get_config, set_config

app = create_app()

with app.app_context():
    current_setup = get_config("setup")

    if str(current_setup).lower() in ("true", "1"):
        print("CTFd is already initialized.")
        sys.exit(0)

    name = os.environ.get("CTFD_ADMIN_NAME", "").strip()
    email = os.environ.get("CTFD_ADMIN_EMAIL", "").strip()
    password = os.environ.get("CTFD_ADMIN_PASSWORD", "")

    if not name or not email or not password:
        raise SystemExit(
            "Missing CTFD_ADMIN_NAME, CTFD_ADMIN_EMAIL or CTFD_ADMIN_PASSWORD"
        )

    if Users.query.filter_by(name=name).first():
        raise SystemExit(f"User name already exists: {name}")

    if Users.query.filter_by(email=email).first():
        raise SystemExit(f"Email already exists: {email}")

    print("Initializing Griffith CTF...")

    set_config("ctf_name", "Griffith CTF")
    set_config(
        "ctf_description",
        "Cybersecurity Capture the Flag environment for high school students",
    )
    set_config("user_mode", "users")
    set_config("challenge_visibility", "public")
    set_config("registration_visibility", "public")
    set_config("score_visibility", "public")
    set_config("account_visibility", "public")
    set_config("verify_emails", False)
    set_config("social_shares", False)
    set_config("ctf_theme", "core")

    admin = Admins(
        name=name,
        email=email,
        password=password,
        type="admin",
        hidden=True,
    )

    db.session.add(admin)

    if Pages.query.filter_by(route="index").first() is None:
        page = Pages(
            title="Griffith CTF",
            route="index",
            content="""
<div class="container text-center py-5">
    <h1>Griffith CTF</h1>
    <p>Cybersecurity Capture the Flag</p>
</div>
""",
            draft=False,
        )
        db.session.add(page)

    set_config("setup", True)

    db.session.commit()

    print("CTFd initialization complete.")

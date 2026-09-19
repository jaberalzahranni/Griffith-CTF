$ErrorActionPreference = "Stop"

$Container = "groupctfd-ctfd-1"
$Remote = "/tmp/four_challenges_import"

Write-Host ""
Write-Host "=== Four CTFd challenges import ==="
Write-Host "Target: C:\Group\CTFd"
Write-Host ""

docker inspect $Container *> $null
if ($LASTEXITCODE -ne 0) {
    throw "groupctfd-ctfd-1 is not running. Start C:\Group\CTFd first."
}

Write-Host "Copying the prepared challenge package to the running CTFd container..."
docker exec $Container sh -lc "rm -rf $Remote"
docker cp "$PSScriptRoot" "${Container}:$Remote"

Write-Host ""
Write-Host "Preview:"
docker exec $Container sh -lc "cd /opt/CTFd && python $Remote/import_challenges.py"
if ($LASTEXITCODE -ne 0) {
    throw "Preview failed. Nothing was imported."
}

Write-Host ""
$confirm = Read-Host "Type IMPORT to add these four challenges"
if ($confirm -ne "IMPORT") {
    Write-Host "Cancelled. No challenges were added."
    exit 0
}

Write-Host ""
docker exec $Container sh -lc "cd /opt/CTFd && python $Remote/import_challenges.py --apply"
if ($LASTEXITCODE -ne 0) {
    throw "Import failed."
}

Write-Host ""
Write-Host "Current CTFd challenges:"
docker exec $Container python -c "from CTFd import create_app; from CTFd.models import Challenges; app=create_app(); app.app_context().push(); print([(c.id,c.name,c.category,c.value) for c in Challenges.query.order_by(Challenges.id).all()])"

Write-Host ""
Write-Host "Finished. Refresh http://localhost:8000/challenges"

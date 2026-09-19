$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "================================="
Write-Host " Griffith CTF Automatic Setup"
Write-Host "================================="
Write-Host ""

$AdminName = Read-Host "Admin username"
$AdminEmail = Read-Host "Admin email"
$SecurePassword = Read-Host "Admin password" -AsSecureString

$Ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)

try {
    $AdminPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Ptr)
}

if (
    [string]::IsNullOrWhiteSpace($AdminName) -or
    [string]::IsNullOrWhiteSpace($AdminEmail) -or
    [string]::IsNullOrWhiteSpace($AdminPassword)
) {
    throw "Admin username, email and password are required."
}

Write-Host ""
Write-Host "Starting Docker containers..."

docker compose up -d

if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose failed."
}

Write-Host ""
Write-Host "Waiting for CTFd..."

$Container = $null
$Ready = $false

for ($i = 1; $i -le 30; $i++) {

    $Container = docker compose ps -q ctfd

    if ($Container) {

        docker exec $Container sh -lc "cd /opt/CTFd && PYTHONPATH=/opt/CTFd /opt/venv/bin/python -c 'from CTFd import create_app; create_app()'" *> $null

        if ($LASTEXITCODE -eq 0) {
            $Ready = $true
            break
        }
    }

    Start-Sleep -Seconds 2
}

if (-not $Ready) {
    throw "CTFd did not become ready."
}

Write-Host "CTFd is ready."

Write-Host ""
Write-Host "Copying bootstrap..."

docker cp ".\bootstrap_ctfd.py" "${Container}:/tmp/bootstrap_ctfd.py"

Write-Host ""
Write-Host "Initializing CTFd..."

docker exec `
    -e "CTFD_ADMIN_NAME=$AdminName" `
    -e "CTFD_ADMIN_EMAIL=$AdminEmail" `
    -e "CTFD_ADMIN_PASSWORD=$AdminPassword" `
    $Container `
    sh -lc "cd /opt/CTFd && PYTHONPATH=/opt/CTFd /opt/venv/bin/python /tmp/bootstrap_ctfd.py"

if ($LASTEXITCODE -ne 0) {
    throw "CTFd initialization failed."
}

Write-Host ""
Write-Host "Installing Griffith challenges..."

docker exec -u 0 $Container sh -lc "rm -rf /tmp/project-challenges"

docker cp ".\project-challenges" "${Container}:/tmp/project-challenges"

docker exec $Container sh -lc "cd /opt/CTFd && PYTHONPATH=/opt/CTFd /opt/venv/bin/python /tmp/project-challenges/import_challenges.py --apply"

if ($LASTEXITCODE -ne 0) {
    throw "Challenge import failed."
}

Write-Host ""
Write-Host "================================="
Write-Host " Griffith CTF is ready"
Write-Host "================================="
Write-Host ""
Write-Host "Open: http://localhost"
Write-Host ""

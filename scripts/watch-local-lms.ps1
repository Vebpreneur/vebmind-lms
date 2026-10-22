# Run once from Windows PowerShell:
# powershell -ExecutionPolicy Bypass -File .\scripts\watch-local-lms.ps1
#
# Keeps the LMS source inside the running Docker container in sync with
# Vebpreneur/vebmind-lms feat/frappe-ui-dark-only. Stops when this window closes.
# Never deletes volumes, reinstalls Frappe, or force-resets local changes.

$ErrorActionPreference = 'Stop'
$container = 'lms-frappe-1'
$repo = 'https://github.com/Vebpreneur/vebmind-lms.git'
$branch = 'feat/frappe-ui-dark-only'
$directory = '/home/frappe/frappe-bench/apps/lms'

function Invoke-InLms([string]$command) {
    & docker exec $container bash -lc "cd $directory && $command"
    if ($LASTEXITCODE -ne 0) { throw "Docker command failed (exit $LASTEXITCODE): $command" }
}

Write-Host 'LMS automatic local preview: monitoring GitHub for updates.' -ForegroundColor Cyan
Write-Host 'Leave this PowerShell window open; Ctrl+C stops synchronization.'

Invoke-InLms 'git rev-parse --is-inside-work-tree'
Invoke-InLms "git remote get-url vebpreneur >/dev/null 2>&1 || git remote add vebpreneur $repo"
Invoke-InLms "git fetch vebpreneur $branch"
# Do not overwrite existing tracked modifications in the container.
Invoke-InLms 'test -z "$(git status --porcelain --untracked-files=no)"'
Invoke-InLms "if git show-ref --verify --quiet refs/heads/$branch; then git switch $branch; else git switch -c $branch --track vebpreneur/$branch; fi"

$lastBuilt = ''
while ($true) {
    try {
        Invoke-InLms "git fetch --quiet vebpreneur $branch"
        Invoke-InLms 'test -z "$(git status --porcelain --untracked-files=no)"'
        Invoke-InLms "git merge --ff-only vebpreneur/$branch"
        $head = (& docker exec $container bash -lc "cd $directory && git rev-parse HEAD").Trim()
        if ($LASTEXITCODE -ne 0) { throw 'Cannot read LMS revision.' }

        if ($head -ne $lastBuilt) {
            Write-Host "Building LMS revision $($head.Substring(0, 8))..." -ForegroundColor Yellow
            & docker exec $container bash -lc 'cd /home/frappe/frappe-bench && bench build --app lms && bench --site lms.localhost clear-cache'
            if ($LASTEXITCODE -ne 0) { throw 'LMS build failed; will retry.' }
            $lastBuilt = $head
            Write-Host 'Updated. Refresh http://localhost:8000/lms' -ForegroundColor Green
        }
    } catch {
        Write-Warning $_.Exception.Message
        Write-Warning 'Synchronization paused or failed; your existing site and database are not changed.'
    }
    Start-Sleep -Seconds 30
}

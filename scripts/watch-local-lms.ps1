# Start in Windows PowerShell:
# cd C:\Users\yogig\vebmind-lms
# powershell -ExecutionPolicy Bypass -File .\scripts\watch-local-lms.ps1
#
# Keep this window open. Ctrl+C stops checking GitHub.
# Never deletes Docker volumes, resets a repository, or reinstalls a site.

$ErrorActionPreference = 'Stop'
$container = 'lms-frappe-1'
$repository = 'https://github.com/Vebpreneur/vebmind-lms.git'
$branch = 'feat/frappe-ui-dark-only'
$directory = '/home/frappe/frappe-bench/apps/lms'

# Pass each argument directly to docker/git. Avoid Bash -lc interpolation:
# PowerShell otherwise eats the quotes inside $(git ...).
function Git-InLms {
    param([string[]]$GitArgs)
    & docker exec $container git -C $directory @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw "git $($GitArgs -join ' ') failed (exit $LASTEXITCODE)"
    }
}

function Protect-LocalChanges {
    $changes = @(& docker exec $container git -C $directory status --porcelain --untracked-files=no)
    if ($LASTEXITCODE -ne 0) { throw 'Could not check local changes.' }
    if ($changes.Count -gt 0) {
        Write-Host 'Saving container-local edits in Git stash before updating...' -ForegroundColor Yellow
        Git-InLms @('stash', 'push', '-m', 'auto-preview: saved local changes before synchronization')
        Write-Host 'Previous local edits were preserved in the container Git stash.' -ForegroundColor Yellow
    }
}

Write-Host 'LMS local preview: automatic GitHub synchronization.' -ForegroundColor Cyan
Write-Host 'Leave this PowerShell window open. Press Ctrl+C to stop.'

Git-InLms @('rev-parse', '--is-inside-work-tree')
$remotes = @(& docker exec $container git -C $directory remote)
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect Git remotes.' }
if ($remotes -notcontains 'vebpreneur') {
    Git-InLms @('remote', 'add', 'vebpreneur', $repository)
}
Git-InLms @('fetch', 'vebpreneur', $branch)
Protect-LocalChanges

$localBranches = @(& docker exec $container git -C $directory branch --format='%(refname:short)')
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect local branches.' }
if ($localBranches -contains $branch) {
    Git-InLms @('switch', $branch)
} else {
    Git-InLms @('switch', '-c', $branch, '--track', "vebpreneur/$branch")
}

$lastBuilt = ''
while ($true) {
    try {
        Git-InLms @('fetch', '--quiet', 'vebpreneur', $branch)
        Protect-LocalChanges
        Git-InLms @('merge', '--ff-only', "vebpreneur/$branch")

        $head = (& docker exec $container git -C $directory rev-parse HEAD | Select-Object -First 1)
        if ($LASTEXITCODE -ne 0 -or -not $head) { throw 'Could not identify current commit.' }
        $head = $head.Trim()

        if ($head -ne $lastBuilt) {
            Write-Host "Building LMS revision $($head.Substring(0,8))..." -ForegroundColor Yellow
            & docker exec $container bash -lc 'cd /home/frappe/frappe-bench && bench build --app lms && bench --site lms.localhost clear-cache'
            if ($LASTEXITCODE -ne 0) { throw 'LMS build failed; will retry next cycle.' }
            $lastBuilt = $head
            Write-Host 'Ready: refresh http://localhost:8000/lms' -ForegroundColor Green
        }
    } catch {
        Write-Warning $_.Exception.Message
        Write-Warning 'Existing LMS installation was not reinstalled or deleted.'
    }
    Start-Sleep -Seconds 30
}

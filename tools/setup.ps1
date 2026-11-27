# Installs everything needed to build the Go tools, the CLI and the Rails app in web/.
# Usage: pnpm setup   (or: powershell -ExecutionPolicy Bypass -File tools/setup.ps1)
# Safe to re-run: steps are skipped when the tool is already present.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# winget installs update PATH for new shells only; pull it into this one.
function Update-SessionPath {
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Install-IfMissing($command, $wingetId) {
  if (Get-Command $command -ErrorAction SilentlyContinue) { Write-Host "ok: $command"; return }
  Write-Host "installing $wingetId"
  winget install -e --id $wingetId --accept-package-agreements --accept-source-agreements
  # -1978335189 = already installed, no upgrade available
  if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) { throw "winget failed for $wingetId" }
  Update-SessionPath
}

function Invoke-Checked {
  & $args[0] $args[1..($args.Length - 1)]
  if ($LASTEXITCODE -ne 0) { throw "failed: $($args -join ' ')" }
}

Update-SessionPath
Install-IfMissing 'go' 'GoLang.Go'
Install-IfMissing 'node' 'OpenJS.NodeJS.LTS'
Install-IfMissing 'ruby' 'RubyInstallerTeam.RubyWithDevKit.3.4'

if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) { Invoke-Checked npm install -g pnpm; Update-SessionPath }

# MSYS2 base + toolchain (this also sets up the pacman keyring), then the MariaDB client lib mysql2 compiles against.
Invoke-Checked ridk install 1 2 3
Invoke-Checked ridk exec pacman -S --needed --noconfirm mingw-w64-ucrt-x86_64-libmariadbclient

Push-Location "$root/cmd/cli"
try { Invoke-Checked pnpm install } finally { Pop-Location }
Push-Location "$root/web"
try { Invoke-Checked bundle install } finally { Pop-Location }

Write-Host "`nDone. Fill in DB_PASSWORD and INVITE_CODE in web/.env, open a NEW terminal, then:"
Write-Host '  cd web; bin/rails db:migrate; bin/rails server'

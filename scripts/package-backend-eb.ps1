# Packages backend/ as a standalone zip for Elastic Beanstalk "Upload and
# deploy" (console) or `eb deploy --staged`.
#
# Important: this zips backend/ in isolation, NOT the repo root. The repo
# root's package.json declares npm workspaces (backend + frontend); if you
# zip the monorepo root instead, EB's `npm install` will try to resolve it
# as a workspace and fail or silently produce a broken install.
#
# Usage: powershell -File scripts/package-backend-eb.ps1 [-OutFile path]
param(
  [string]$OutFile = "$PSScriptRoot\..\backend-eb.zip"
)

$ErrorActionPreference = 'Stop'
$RootDir = (Resolve-Path "$PSScriptRoot\..").Path
$BackendDir = Join-Path $RootDir 'backend'

if (-not (Test-Path (Join-Path $BackendDir 'package-lock.json'))) {
  Write-Error "backend/package-lock.json is missing. Generate it before packaging - EB builds are not reproducible without it."
  exit 1
}

$Exclude = @('node_modules', '.env', '.env.*', 'coverage', 'tests', '.git', '*.log', '*.md', 'jest.config.js', '.eslintrc.js', 'scripts')

if (Test-Path $OutFile) { Remove-Item $OutFile -Force }

$StageDir = Join-Path $env:TEMP "eb-stage-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $StageDir | Out-Null

try {
  Get-ChildItem -Path $BackendDir -Force | Where-Object {
    $name = $_.Name
    -not ($Exclude | Where-Object { $name -like $_ })
  } | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination (Join-Path $StageDir $_.Name) -Recurse -Force
  }

  Compress-Archive -Path (Join-Path $StageDir '*') -DestinationPath $OutFile -Force
} finally {
  Remove-Item $StageDir -Recurse -Force -ErrorAction SilentlyContinue
}

$sizeMB = [math]::Round((Get-Item $OutFile).Length / 1MB, 2)
Write-Host "Created $OutFile ($sizeMB MB)"
Write-Host "Deploy via: EB console 'Upload and deploy', or: eb deploy --staged"

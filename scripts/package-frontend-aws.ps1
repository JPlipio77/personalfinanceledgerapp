# Builds frontend/ and zips the static output (dist/) for AWS - either
# Amplify Hosting's manual "drag and drop a zip" deploy, or extraction to
# an S3 static-website bucket. The zip contains the CONTENTS of dist/ at
# its root (index.html at the top level), not source code - there's no
# build step on the AWS side for a static zip upload, so it must already
# be built.
#
# Usage: powershell -File scripts/package-frontend-aws.ps1 [-OutFile path]
param(
  [string]$OutFile = "$PSScriptRoot\..\frontend-web.zip"
)

$ErrorActionPreference = 'Stop'
$RootDir = (Resolve-Path "$PSScriptRoot\..").Path
$FrontendDir = Join-Path $RootDir 'frontend'
$DistDir = Join-Path $FrontendDir 'dist'

if (-not (Test-Path (Join-Path $FrontendDir '.env.production'))) {
  Write-Warning "frontend/.env.production not found."
  Write-Warning "  VITE_API_BASE_URL and VITE_VAPID_PUBLIC_KEY are baked in at build time -"
  Write-Warning "  without this file the build falls back to frontend/.env.example defaults"
  Write-Warning "  (localhost), which will not work against a deployed backend."
  Write-Warning "  Copy frontend/.env.example -> frontend/.env.production and fill in real values first."
}

Push-Location $FrontendDir
try {
  npm ci
  if ($LASTEXITCODE -ne 0) { throw "npm ci failed" }

  npm run build
  if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }
} finally {
  Pop-Location
}

if (-not (Test-Path $DistDir)) {
  throw "frontend/dist was not produced by the build."
}

if (Test-Path $OutFile) { Remove-Item $OutFile -Force }

# Deliberately NOT using Compress-Archive: on this platform it writes zip
# entry names with Windows-style backslashes (e.g. "assets\index.js")
# instead of the forward slashes the ZIP format and S3/browsers expect.
# S3 then stores that literally as a flat key containing a backslash
# character, not a real "assets/" prefix - so a request for
# /assets/index.js (forward slash, from index.html) 404s even though the
# file did upload. Build the archive manually instead and force "/" in
# every entry name.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::Open($OutFile, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  $distFullPath = (Resolve-Path $DistDir).Path
  Get-ChildItem -Path $DistDir -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Substring($distFullPath.Length).TrimStart('\', '/')
    $entryName = $relativePath.Replace('\', '/')
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
      $zip, $_.FullName, $entryName, [System.IO.Compression.CompressionLevel]::Optimal
    ) | Out-Null
  }
} finally {
  $zip.Dispose()
}

$sizeMB = [math]::Round((Get-Item $OutFile).Length / 1MB, 2)
Write-Host "Created $OutFile ($sizeMB MB)"
Write-Host "Deploy via: Amplify Console -> 'Deploy without Git provider' -> drag & drop this zip"
Write-Host "        or: unzip and 'aws s3 sync . s3://<bucket>' for S3 static hosting"

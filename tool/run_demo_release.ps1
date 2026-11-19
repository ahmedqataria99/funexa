$ErrorActionPreference = 'Stop'

if ($env:LOCALAPPDATA -eq $null -or $env:LOCALAPPDATA.Trim().Length -eq 0) {
  throw 'LOCALAPPDATA is not available.'
}

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$releaseExecutable = Join-Path $projectRoot 'build\windows\x64\runner\Release\furnexa.exe'
$demoDatabase = Join-Path $env:LOCALAPPDATA 'Furnexa\demo\furnexa-demo.db'

if (-not (Test-Path -LiteralPath $releaseExecutable -PathType Leaf)) {
  throw "Windows Release executable not found: $releaseExecutable"
}
if (-not (Test-Path -LiteralPath $demoDatabase -PathType Leaf)) {
  throw "Demo database not found. Run dart run tool/seed_demo_data.dart first: $demoDatabase"
}

$env:FURNEXA_DATABASE_PATH = $demoDatabase
Push-Location (Split-Path -Parent $releaseExecutable)
try {
  & $releaseExecutable
  if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "Furnexa exited with code $LASTEXITCODE."
  }
} finally {
  Pop-Location
  Remove-Item Env:FURNEXA_DATABASE_PATH -ErrorAction SilentlyContinue
}

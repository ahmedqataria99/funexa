param(
  [switch]$SkipFlutterBuild,
  [switch]$CreatePortableArchive
)

$ErrorActionPreference = 'Stop'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$aiRoot = Resolve-Path (Join-Path $projectRoot '..\furnixa-ai')
$aiPython = Join-Path $aiRoot '.venv\Scripts\python.exe'
$serviceScript = Join-Path $aiRoot 'src\api\local_ai_service.py'
$releaseDirectory = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$pythonWorkDirectory = Join-Path $projectRoot 'build\python-runtime'
$portableDirectory = Join-Path $projectRoot 'build\release'
$portableArchive = Join-Path $portableDirectory 'furnexa-windows-x64-portable.zip'

if (-not (Test-Path -LiteralPath $aiPython -PathType Leaf)) {
  throw "AI virtual environment not found: $aiPython"
}
if (-not (Test-Path -LiteralPath $serviceScript -PathType Leaf)) {
  throw "Local AI service source not found: $serviceScript"
}
& $aiPython -c "import PyInstaller" 2>$null
if ($LASTEXITCODE -ne 0) {
  throw "PyInstaller is missing. Install it with: `"$aiPython`" -m pip install pyinstaller"
}

if (-not $SkipFlutterBuild) {
  Push-Location $projectRoot
  try {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
      throw "Flutter Windows release build failed with exit code $LASTEXITCODE."
    }
  } finally {
    Pop-Location
  }
}

if (-not (Test-Path -LiteralPath (Join-Path $releaseDirectory 'furnexa.exe') -PathType Leaf)) {
  throw "Furnexa release executable not found: $releaseDirectory"
}
New-Item -ItemType Directory -Force -Path $pythonWorkDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $portableDirectory | Out-Null
$aiRuntimeDirectory = Join-Path $releaseDirectory 'ai_runtime'
New-Item -ItemType Directory -Force -Path $aiRuntimeDirectory | Out-Null
$env:PYTHONPATH = $aiRoot
Push-Location $aiRoot
try {
  & $aiPython -m PyInstaller `
    --clean `
    --noconfirm `
    --onefile `
    --noconsole `
    --name furnexa_ai_service `
    --hidden-import uvicorn.lifespan.on `
    --hidden-import uvicorn.lifespan.off `
    --hidden-import uvicorn.protocols.http.auto `
    --hidden-import uvicorn.protocols.http.h11_impl `
    --hidden-import uvicorn.protocols.websockets.auto `
    --hidden-import uvicorn.loops.auto `
    --collect-all fastapi `
    --collect-all pydantic `
    --collect-all uvicorn `
    --collect-all pandas `
    --collect-all numpy `
    --distpath $aiRuntimeDirectory `
    --workpath (Join-Path $pythonWorkDirectory 'work') `
    --specpath $pythonWorkDirectory `
    $serviceScript
  if ($LASTEXITCODE -ne 0) {
    throw "Python AI runtime packaging failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
  Remove-Item Env:PYTHONPATH -ErrorAction SilentlyContinue
}

$serviceExecutable = Join-Path $aiRuntimeDirectory 'furnexa_ai_service.exe'
if (-not (Test-Path -LiteralPath $serviceExecutable -PathType Leaf)) {
  throw "Packaged AI service executable not found: $serviceExecutable"
}
$databaseFiles = Get-ChildItem -LiteralPath $releaseDirectory -Recurse -File |
  Where-Object { $_.Extension -in @('.db', '.sqlite', '.sqlite3') }
if ($databaseFiles.Count -gt 0) {
  throw "A SQLite database was found in the release directory: $($databaseFiles[0].FullName)"
}

Add-Type -AssemblyName System.Drawing
$appExecutable = Join-Path $releaseDirectory 'furnexa.exe'
$appIcon = [System.Drawing.Icon]::ExtractAssociatedIcon($appExecutable)
if ($null -eq $appIcon) {
  throw 'The Furnexa application icon is missing from furnexa.exe.'
}
$appVersion = (Get-Item -LiteralPath $appExecutable).VersionInfo
if ($appVersion.ProductName -ne 'Furnexa ERP') {
  throw "Unexpected Windows product metadata: $($appVersion.ProductName)"
}

Write-Host "Furnexa executable: $appExecutable"
Write-Host "Packaged Python AI service: $serviceExecutable"
Write-Host "Product version: $($appVersion.ProductVersion)"
Write-Host "SQLite files in release: $($databaseFiles.Count)"
if ($CreatePortableArchive) {
  Compress-Archive -Path (Join-Path $releaseDirectory '*') -DestinationPath $portableArchive -Force
  $archive = Get-Item -LiteralPath $portableArchive
  Write-Host "Portable release: $($archive.FullName)"
  Write-Host "Portable release size bytes: $($archive.Length)"
}

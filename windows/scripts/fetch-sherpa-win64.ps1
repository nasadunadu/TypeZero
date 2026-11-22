$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WinRoot = Split-Path -Parent $ScriptDir
$RuntimeDir = Join-Path $WinRoot "src-tauri\runtime"
New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null

$TargetDll = Join-Path $RuntimeDir "sherpa-onnx-c-api.dll"
if (Test-Path $TargetDll) {
    Write-Host "==> sherpa-onnx Windows x64 runtime already present at $RuntimeDir"
    exit 0
}

$Version = "v1.13.8"
$ArchiveName = "sherpa-onnx-$Version-win-x64-shared-MT-Release-no-tts-lib.tar.bz2"
$Url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/$Version/$ArchiveName"
$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("tz_sherpa_" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

try {
    $ArchivePath = Join-Path $TempDir $ArchiveName
    Write-Host "==> Downloading $ArchiveName (static CRT MT, zero VC++ Redist dependency)..."
    Invoke-WebRequest -Uri $Url -OutFile $ArchivePath -UseBasicParsing

    Write-Host "==> Extracting archive..."
    & tar -xjf $ArchivePath -C $TempDir
    if ($LASTEXITCODE -ne 0) {
        throw "tar extraction failed with exit code $LASTEXITCODE"
    }

    $Dlls = Get-ChildItem -Path $TempDir -Recurse -Filter "*.dll" | Where-Object {
        $_.Name -in @("sherpa-onnx-c-api.dll", "onnxruntime.dll", "onnxruntime_providers_shared.dll")
    }
    if ($Dlls.Count -eq 0) {
        throw "No sherpa-onnx DLLs found in extracted archive!"
    }

    foreach ($dll in $Dlls) {
        Copy-Item -Path $dll.FullName -Destination (Join-Path $RuntimeDir $dll.Name) -Force
        Write-Host "  + Copied $($dll.Name)"
    }
    Write-Host "==> Windows x64 sherpa-onnx runtime ready at $RuntimeDir"
} finally {
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

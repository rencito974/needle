param(
    [Parameter(Mandatory=$true)][string]$Ipa,
    [string]$Deb,
    [string]$Out = "Needle-Spotify.ipa"
)

$ErrorActionPreference = "Stop"
$tweakRoot = $PSScriptRoot

if (-not (Test-Path $Ipa)) { throw "IPA not found: $Ipa" }

python --version 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Python is not on PATH. Install from python.org then rerun." }

python -c "import pyzule_rw" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Installing pyzule-rw..."
    python -m pip install --quiet pyzule-rw
}

if (-not $Deb) {
    $candidate = Get-ChildItem "$tweakRoot\packages\*.deb" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $candidate) {
        throw "No .deb in $tweakRoot\packages. Build it first in WSL or macOS: cd Tweak && make package FINALPACKAGE=1"
    }
    $Deb = $candidate.FullName
}
if (-not (Test-Path $Deb)) { throw "Deb not found: $Deb" }

$ipaFull = (Resolve-Path $Ipa).Path
$outFull = Join-Path (Get-Location) $Out

Write-Host ""
Write-Host "IPA   : $ipaFull"
Write-Host "Deb   : $Deb"
Write-Host "Out   : $outFull"
Write-Host ""

& pyzule -i $ipaFull -o $outFull -f $Deb
if ($LASTEXITCODE -ne 0) { throw "pyzule failed with exit code $LASTEXITCODE" }

Write-Host ""
Write-Host "Done. Open Sideloadly, drop $Out on it, sign with your Apple ID, install to the iPhone."
Write-Host ""

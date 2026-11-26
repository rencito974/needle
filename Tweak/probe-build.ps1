param(
    [Parameter(Mandatory=$true)][string]$Ipa,
    [string]$Out = "Needle-Probe.ipa"
)

$ErrorActionPreference = "Stop"
$tweakRoot = $PSScriptRoot

Write-Host "Building probe variant on the WSL side..."
wsl bash -c "cd '$(wsl wslpath -a $tweakRoot)' && make clean >/dev/null && NEEDLE_PROBE=1 make package FINALPACKAGE=1"
if ($LASTEXITCODE -ne 0) { throw "Theos build failed. Check WSL output above." }

$deb = Get-ChildItem "$tweakRoot\packages\*.deb" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $deb) { throw "Build produced no .deb" }

& "$tweakRoot\inject.ps1" -Ipa $Ipa -Deb $deb.FullName -Out $Out

Write-Host ""
Write-Host "Probe variant ready: $Out"
Write-Host "Install with Sideloadly, open Spotify, let it idle 5-10 seconds, play a song, wait another 2 min."
Write-Host "Then pull Documents/needle-probe.txt from the Spotify sandbox with iMazing or 3uTools."

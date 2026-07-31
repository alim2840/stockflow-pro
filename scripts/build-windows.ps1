# =============================================================================
# StockFlow Pro — local Windows build (for a build machine, NOT end users).
# End users install the finished StockFlow-Pro-Setup-x64.exe only.
#
# Prereqs on the BUILD machine (one time):
#   1. Node.js 20+            https://nodejs.org
#   2. Rust (MSVC toolchain)  https://rustup.rs
#   3. Microsoft VS Build Tools with "Desktop development with C++"
# Then run from the project root:  powershell -File scripts/build-windows.ps1
# =============================================================================
$ErrorActionPreference = 'Stop'

Write-Host '1/4 Installing JS dependencies…'
npm ci

Write-Host '2/4 Building Tauri bundles (NSIS .exe + WiX .msi)…'
npx tauri build

Write-Host '3/4 Assembling release folder…'
New-Item -ItemType Directory -Force -Path release-out | Out-Null
$setup = Get-ChildItem src-tauri/target/release/bundle/nsis/*-setup.exe | Select-Object -First 1
Copy-Item $setup.FullName release-out/StockFlow-Pro-Setup-x64.exe -Force
$msi = Get-ChildItem src-tauri/target/release/bundle/msi/*.msi | Select-Object -First 1
Copy-Item $msi.FullName release-out/StockFlow-Pro-x64.msi -Force
New-Item -ItemType Directory -Force -Path portable | Out-Null
Copy-Item src-tauri/target/release/stockflow-pro.exe 'portable/StockFlow Pro.exe' -Force
Compress-Archive -Path portable/* -DestinationPath release-out/StockFlow-Pro-Portable-x64.zip -Force
Copy-Item release/LICENSE.txt, release/RELEASE-NOTES.md release-out/ -Force
Copy-Item docs/INSTALLATION-GUIDE.md, docs/ADMIN-DEPLOYMENT-GUIDE.md, docs/USER-GUIDE.md release-out/ -Force

Write-Host '4/4 Writing SHA-256 checksums…'
Get-ChildItem release-out -File | Where-Object Name -ne 'SHA256SUMS.txt' | ForEach-Object {
  '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(), $_.Name
} | Out-File release-out/SHA256SUMS.txt -Encoding utf8

Write-Host "`nDone. Files in release-out/:" -ForegroundColor Green
Get-ChildItem release-out | Format-Table Name, Length

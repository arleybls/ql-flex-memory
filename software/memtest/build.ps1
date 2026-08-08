# Builds memtest_bin from memtest_asm with the vasm cross assembler.
#
# vasm (M68k backend, Motorola syntax) is available prebuilt for Windows:
#   http://sun.hasenbraten.de/vasm/  ->  "Last release binaries"
#   file: vasmm68k_mot_Win64.zip
#
# Usage:
#   .\build.ps1                                # vasmm68k_mot on PATH
#   .\build.ps1 -Vasm C:\tools\vasmm68k_mot.exe
#   .\build.ps1 -Deploy C:\sQLux\flp1          # also copy files to an
#                                              # emulator-mapped directory
param(
    [string]$Vasm = "vasmm68k_mot",
    [string]$Deploy = ""
)
$ErrorActionPreference = "Stop"
$src = Join-Path $PSScriptRoot "memtest_asm"
$out = Join-Path $PSScriptRoot "memtest_bin"
$lst = Join-Path $PSScriptRoot "memtest_lst"

# -no-opt keeps every instruction exactly as written, so the fixed entry
# offsets (+0 safe, +4 destructive, +8 magic) cannot move.
& $Vasm -Fbin -m68008 -no-opt -o $out -L $lst $src
if ($LASTEXITCODE -ne 0) { throw "vasm failed with exit code $LASTEXITCODE" }

$bin = [System.IO.File]::ReadAllBytes($out)
if ($bin.Length -gt 4096) {
    throw "binary is $($bin.Length) bytes - must fit the 4096-byte slot memtest_bas reserves"
}
$magic = [System.Text.Encoding]::ASCII.GetString($bin, 8, 4)
if ($magic -ne "QFMT") {
    throw "magic 'QFMT' not found at offset 8 - header layout broken"
}
$sum = 0
foreach ($b in $bin) { $sum = ($sum + $b) % 65536 }
Write-Host ("memtest_bin: {0} bytes, checksum {1:X4}, magic OK" -f $bin.Length, $sum)

if ($Deploy -ne "") {
    Copy-Item $out (Join-Path $Deploy "memtest_bin") -Force
    Copy-Item (Join-Path $PSScriptRoot "memtest_bas") (Join-Path $Deploy "memtest_bas") -Force
    Write-Host "Deployed memtest_bin + memtest_bas to $Deploy"
}

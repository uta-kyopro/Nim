$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    nim cpp -r -d:debug --hints:off --nimcache:build/nimcache --outdir:build/tests tests/test_all.nim
}
finally {
    Pop-Location
}

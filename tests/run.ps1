$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    nim cpp -r -d:debug --hints:off --nimcache:build/nimcache --outdir:build/tests tests/test_all.nim
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    nim cpp -r -d:debug --hints:off --nimcache:build/nimcache_mcf --outdir:build/tests tests/test_min_cost_flow.nim
}
finally {
    Pop-Location
}

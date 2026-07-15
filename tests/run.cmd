@echo off
cd /d "%~dp0.."
nim cpp -r -d:debug --hints:off --nimcache:build/nimcache --outdir:build/tests tests/test_all.nim
if errorlevel 1 exit /b %errorlevel%
nim cpp -r -d:debug --hints:off --nimcache:build/nimcache_mcf --outdir:build/tests tests/test_min_cost_flow.nim

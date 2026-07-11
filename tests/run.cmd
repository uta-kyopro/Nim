@echo off
cd /d "%~dp0.."
nim cpp -r -d:debug --hints:off --nimcache:build/nimcache --outdir:build/tests tests/test_all.nim

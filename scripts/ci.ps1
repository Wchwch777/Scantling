$ErrorActionPreference = "Stop"

Write-Host "[Scantling CI] Checking code formatting..."
moon fmt --check

Write-Host "[Scantling CI] Typechecking project..."
moon check

Write-Host "[Scantling CI] Running all 12 test suites..."
moon test

Write-Host "[Scantling CI] Verifying CLI terminal execution..."
moon run cmd

Write-Host "[Scantling CI] All verification checks passed successfully!"

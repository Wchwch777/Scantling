$ErrorActionPreference = "Stop"

Write-Host "[Scantling CI] Checking code formatting..."
moon fmt --check

Write-Host "[Scantling CI] Typechecking project..."
moon check

Write-Host "[Scantling CI] Running the test suite..."
moon test

Write-Host "[Scantling CI] Verifying CLI terminal execution..."
moon run cmd

Write-Host "[Scantling CI] Verifying public API quickstart demo..."
moon run examples/quickstart

Write-Host "[Scantling CI] All verification checks passed successfully!"

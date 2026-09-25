$ErrorActionPreference = "Stop"

function Invoke-MoonChecked {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & moon @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "moon $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

Write-Host "[Scantling CI] Checking code formatting..."
Invoke-MoonChecked @("fmt", "--check")

Write-Host "[Scantling CI] Typechecking project..."
Invoke-MoonChecked @("check")

Write-Host "[Scantling CI] Running the test suite..."
Invoke-MoonChecked @("test")

Write-Host "[Scantling CI] Verifying CLI terminal execution..."
Invoke-MoonChecked @("run", "cmd")

Write-Host "[Scantling CI] Verifying public API quickstart demo..."
Invoke-MoonChecked @("run", "examples/quickstart")

Write-Host "[Scantling CI] All verification checks passed successfully!"

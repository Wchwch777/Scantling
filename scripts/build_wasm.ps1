Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "[Scantling] Compiling MoonBit packages to WebAssembly..."
& moon build --target wasm
if ($LASTEXITCODE -ne 0) {
    throw "moon build --target wasm failed with exit code $LASTEXITCODE"
}
Write-Host "[Scantling] Wasm build complete. Artifacts located in _build/wasm/"

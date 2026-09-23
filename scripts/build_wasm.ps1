Write-Host "[Scantling] Compiling MoonBit packages to WebAssembly..."
moon build --target wasm
Write-Host "[Scantling] Wasm build complete. Artifacts located in _build/wasm/"

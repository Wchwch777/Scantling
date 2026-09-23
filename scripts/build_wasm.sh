#!/usr/bin/env bash
set -e

echo "[Scantling] Compiling MoonBit packages to WebAssembly..."
moon build --target wasm

echo "[Scantling] Wasm build complete. Artifacts located in _build/wasm/"

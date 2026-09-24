#!/usr/bin/env bash
set -e

echo "[Scantling CI] Checking code formatting..."
moon fmt --check

echo "[Scantling CI] Typechecking project..."
moon check

echo "[Scantling CI] Running the test suite..."
moon test

echo "[Scantling CI] Verifying CLI terminal execution..."
moon run cmd

echo "[Scantling CI] All verification checks passed successfully!"

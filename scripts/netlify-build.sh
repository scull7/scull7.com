#!/usr/bin/env bash
# Netlify build: install MoonBit toolchain, fetch deps, produce dist/
set -euo pipefail

export PATH="${HOME}/.moon/bin:${PATH}"

if ! command -v moon >/dev/null 2>&1; then
  echo "→ Installing MoonBit CLI"
  curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
  export PATH="${HOME}/.moon/bin:${PATH}"
fi

echo "→ moon version"
moon version

echo "→ moon update (deps)"
moon update

echo "→ moon build --target js --release"
moon build --target js --release

echo "→ vite build"
npx vite build

echo "→ build ok"
ls -la dist

#!/usr/bin/env bash
# Netlify build: Elm + ReScript + Vite → dist/
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"

if ! command -v elm >/dev/null 2>&1; then
  echo "→ Installing Elm"
  npm install -g elm@0.19.1-6 || npx --yes elm@0.19.1-6 --version
  export PATH="$(npm root -g)/../bin:${PATH}"
fi

echo "→ elm version"
elm --version || npx elm --version

echo "→ rescript"
npx rescript

echo "→ vite build"
npx vite build

echo "→ build ok"
ls -la dist

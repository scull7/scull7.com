#!/usr/bin/env bash
# Netlify build: Elm + Melange (opam/dune) + Vite → dist/
set -euo pipefail

export PATH="${HOME}/.local/bin:${HOME}/.opam/default/bin:${PATH}"
export OPAMYES=1
export OPAMROOT="${OPAMROOT:-${HOME}/.opam}"

if ! command -v elm >/dev/null 2>&1; then
  echo "→ Installing Elm"
  npm install -g elm@0.19.1-6 || true
  export PATH="$(npm root -g)/../bin:${PATH}"
fi

echo "→ elm version"
elm --version || npx --yes elm@0.19.1-6 --version

if ! command -v opam >/dev/null 2>&1; then
  echo "→ Installing opam"
  bash -c "sh <(curl -fsSL https://opam.ocaml.org/install.sh)" -- --download-only /tmp/opam-bin || true
  # Binary install for linux
  if [ ! -x /tmp/opam ] && [ ! -x "${HOME}/.local/bin/opam" ]; then
    ARCH=$(uname -m)
    case "$ARCH" in
      x86_64) OPAM_ARCH=x86_64 ;;
      aarch64|arm64) OPAM_ARCH=arm64 ;;
      *) OPAM_ARCH=x86_64 ;;
    esac
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    curl -fsSL "https://github.com/ocaml/opam/releases/download/2.2.1/opam-2.2.1-${OPAM_ARCH}-${OS}" \
      -o "${HOME}/.local/bin/opam"
    chmod +x "${HOME}/.local/bin/opam"
  fi
  export PATH="${HOME}/.local/bin:${PATH}"
fi

echo "→ opam version"
opam --version

if [ ! -d "${OPAMROOT}" ] || ! opam switch list >/dev/null 2>&1; then
  echo "→ opam init"
  opam init --bare --disable-sandboxing -a
fi

# Local switch at project root (created once, cached on Netlify if OPAMROOT cached)
if [ ! -d "_opam" ]; then
  echo "→ creating local opam switch 5.2.0"
  opam switch create . 5.2.0 -y --no-install
fi

eval "$(opam env)"
echo "→ opam install deps"
opam install . --deps-only -y

echo "→ dune build @site (Melange)"
opam exec -- dune build @site
node _build/default/src/melange/artifacts/src/melange/emit_artifacts.cjs

echo "→ interview tests"
node _build/default/src/melange/e2e/src/melange/e2e_cli.cjs interview

echo "→ vite build"
npx vite build --config _build/default/src/melange/vite/src/melange/vite_config.js

echo "→ build ok"
ls -la dist

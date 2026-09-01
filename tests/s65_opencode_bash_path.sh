#!/usr/bin/env bash
# tests/s65_opencode_bash_path.sh — S65 (AC-R047).
# Lima lance OpenCode via /bin/bash (non-login) : ~/.zshenv n'est pas lu,
# donc ~/.opencode/bin n'est pas dans le PATH → « opencode: command not found ».
# Compatible bash 3.2. Sandbox HOME, aucune écriture hors bac.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; }

echo "S65 — OpenCode visible du bash Lima (PATH ~/.local/bin + lancement zsh -l)"
echo

# --- 1. phase_run lance via login zsh, pas un opencode nu ----------------------
# `_vm opencode` → limactl shell … opencode → /bin/bash -c opencode → PATH mort.
phases="$SELF_DIR/lib/phases.sh"
if grep -q 'zsh -l -c "opencode --auto"' "$phases"; then
  pass "phase_run lance OpenCode via zsh -l (PATH ~/.zshenv)"
else
  fail "phase_run doit lancer via zsh -l -c \"opencode --auto\", pas _vm opencode nu"
fi

if grep -E 'apply "lancer la VM isolée" _vm( --cpus.*)? opencode' "$phases" >/dev/null; then
  fail "phase_run appelle encore _vm opencode (PATH bash Lima vide)"
else
  pass "plus d'appel _vm opencode nu dans phase_run"
fi

# --- 2. check_opencode pose un symlink dans ~/.local/bin -----------------------
SB="$(mktemp -d)"
export HOME="$SB/home"
mkdir -p "$HOME"
trap 'rm -rf "$SB"' EXIT

# Extraire les fonctions du runtime, sans le bloc d'exécution final.
awk 'BEGIN{p=1} /^_info "Runtime Albert Code/{p=0} p' \
  "$SELF_DIR/runtime/agent-vm.runtime.sh" > "$SB/runtime-lib.sh"

# Le runtime utilise DRY_RUN ; forcer réel dans le bac.
DRY_RUN=0
export DRY_RUN
# shellcheck disable=SC1090
source "$SB/runtime-lib.sh"

mkdir -p "$HOME/.opencode/bin"
printf '#!/bin/sh\necho fake-opencode\n' > "$HOME/.opencode/bin/opencode"
chmod +x "$HOME/.opencode/bin/opencode"

# PATH bash Lima : ~/.local/bin + système, SANS ~/.opencode/bin.
PATH="$HOME/.local/bin:/usr/bin:/bin"
export PATH

if command -v opencode >/dev/null 2>&1; then
  fail "précondition : opencode ne doit pas être sur le PATH bash avant check_opencode"
else
  pass "précondition : opencode absent du PATH bash (comme Lima)"
fi

check_opencode >/dev/null

if [ -L "$HOME/.local/bin/opencode" ]; then
  pass "symlink ~/.local/bin/opencode posé"
else
  fail "check_opencode doit symlinker ~/.opencode/bin/opencode → ~/.local/bin/opencode"
fi

if command -v opencode >/dev/null 2>&1; then
  pass "opencode résolu sur le PATH bash après check_opencode"
else
  fail "opencode toujours introuvable sur le PATH bash après check_opencode"
fi

# Idempotence : 2e run ne casse pas.
check_opencode >/dev/null
if [ -L "$HOME/.local/bin/opencode" ] && command -v opencode >/dev/null 2>&1; then
  pass "check_opencode idempotent (2e run)"
else
  fail "2e run de check_opencode a cassé le symlink"
fi

# Pas de contournement hors-VM (AC-R009).
if grep -q 'npm i -g opencode-ai' "$SELF_DIR/runtime/agent-vm.runtime.sh"; then
  fail "check_opencode ne doit plus suggérer npm i -g opencode-ai"
else
  pass "plus de suggestion npm i -g opencode-ai"
fi

echo
if [ "$FAIL" -ne 0 ]; then
  echo "S65 ÉCHEC"
  exit 1
fi
echo "S65 OK"
exit 0

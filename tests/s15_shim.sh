#!/usr/bin/env bash
# tests/s15_shim.sh — S15 (résolution immédiate du shim agent-vm), rejouable en CI.
# Sandbox jetable via SHIM_BIN_DIR/HOME/XDG_DATA_HOME : aucune écriture hors sandbox.
# Compatible bash 3.2.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_HOME="$HOME"
FAIL=0

pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; }

# --- Snapshot AVANT (pour prouver la non-pollution après coup) -----------------
HOMEBREW_HAD_AGENT_VM=0
[ -e /opt/homebrew/bin/agent-vm ] && HOMEBREW_HAD_AGENT_VM=1
USRLOCAL_HAD_AGENT_VM=0
[ -e /usr/local/bin/agent-vm ] && USRLOCAL_HAD_AGENT_VM=1
REAL_ZSHENV="$REAL_HOME/.zshenv"
REAL_ZSHENV_BEFORE=""
[ -e "$REAL_ZSHENV" ] && REAL_ZSHENV_BEFORE="$(cksum "$REAL_ZSHENV" 2>/dev/null || true)"

# --- Sandbox jetable -------------------------------------------------------------
SB="$(mktemp -d)"
export HOME="$SB/home" SHIM_BIN_DIR="$SB/bin" XDG_DATA_HOME="$SB/home/.local/share"
mkdir -p "$SB/home" "$SB/bin"
trap 'rm -rf "$SB"' EXIT

# --- Stub agent-vm (fonction shell sourcée, comme le vrai agent-vm) -------------
cat > "$SB/agent-vm.sh" <<'STUB'
agent-vm() { echo "STUB OK $*"; }
STUB

echo "S15 — shim agent-vm résolution immédiate (sandbox: $SB)"
echo

# --- Précondition : agent-vm introuvable dans un PATH minimal ------------------
PATH="$SHIM_BIN_DIR:/usr/bin:/bin"
if command -v agent-vm >/dev/null 2>&1; then
  fail "précondition : agent-vm ne devrait pas être trouvable avant install_shim"
else
  pass "précondition : agent-vm introuvable (command -v exit 1)"
fi

# --- Exécution : install_shim avec SHIM_BIN_DIR ---------------------------------
DRY_RUN=0
export DRY_RUN
# shellcheck source=../lib/ui.sh
source "$SELF_DIR/lib/ui.sh"

install_shim "agent-vm" "$SB/agent-vm.sh" >/dev/null

# --- Assertions -------------------------------------------------------------------
resolved="$(command -v agent-vm || true)"
if [ "$resolved" = "$SHIM_BIN_DIR/agent-vm" ]; then
  pass "command -v agent-vm == \$SHIM_BIN_DIR/agent-vm ($resolved)"
else
  fail "command -v agent-vm attendu $SHIM_BIN_DIR/agent-vm, obtenu '$resolved'"
fi

if [ -x "$SHIM_BIN_DIR/agent-vm" ]; then
  pass "le shim est exécutable (-x)"
else
  fail "le shim n'est pas exécutable"
fi

output="$("$SHIM_BIN_DIR/agent-vm" ping 2>&1 || true)"
case "$output" in
  *"STUB OK ping"*) pass "agent-vm ping → contient 'STUB OK ping'" ;;
  *) fail "agent-vm ping → sortie inattendue : $output" ;;
esac

# --- Non-pollution : le shim ne doit rien écrire hors de la sandbox ------------
if [ "$HOMEBREW_HAD_AGENT_VM" -eq 0 ] && [ -e /opt/homebrew/bin/agent-vm ]; then
  fail "pollution détectée : /opt/homebrew/bin/agent-vm a été créé"
else
  pass "/opt/homebrew/bin non pollué"
fi

if [ "$USRLOCAL_HAD_AGENT_VM" -eq 0 ] && [ -e /usr/local/bin/agent-vm ]; then
  fail "pollution détectée : /usr/local/bin/agent-vm a été créé"
else
  pass "/usr/local/bin non pollué"
fi

REAL_ZSHENV_AFTER=""
[ -e "$REAL_ZSHENV" ] && REAL_ZSHENV_AFTER="$(cksum "$REAL_ZSHENV" 2>/dev/null || true)"
if [ "$REAL_ZSHENV_BEFORE" = "$REAL_ZSHENV_AFTER" ]; then
  pass "le vrai \$HOME (\$REAL_HOME) n'a pas été modifié"
else
  fail "pollution détectée : $REAL_ZSHENV a changé"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "S15 : OK — sandbox nettoyée en sortie."
  exit 0
else
  echo "S15 : ÉCHEC — voir les assertions ✗ ci-dessus." >&2
  exit 1
fi

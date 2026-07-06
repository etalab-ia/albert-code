#!/usr/bin/env bash
# =============================================================================
# Albert Code — amorçage de l'installation (rétrocompat, délègue à bin/albert-code).
# -----------------------------------------------------------------------------
# Usage :
#   ./install.sh                    # amorce + pose le shim « albert-code »
#   ./install.sh --dry-run          # simulation
#   ./install.sh --help             # aide
#
# Après installation, utilise :
#   albert-code setup   → configurer un projet
#   albert-code run     → lancer la bulle agent-vm
#
# Non-destructif : ne réinstalle rien déjà présent, n'écrase aucune config.
# Compatible bash 3.2 (macOS).
# =============================================================================
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SELF_DIR/lib"
source "$LIB_DIR/ui.sh"

# --- Parsing ----------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; export DRY_RUN ;;
    --help|-h) usage_install; exit 0 ;;
    *) err "Option inconnue : $1"; usage_install; exit 1 ;;
  esac
  shift
done

# Source les phases (contient phase_a, phase_b, phase_run)
if [ -f "$LIB_DIR/phases.sh" ]; then
  source "$LIB_DIR/phases.sh"
else
  err "lib/phases.sh introuvable. Albert Code est-il complet ?"
  exit 1
fi

# --- Ressources VM -----------------------------------------------------------
AC_VM_CPUS="${AC_VM_CPUS:-4}"
AC_VM_MEMORY="${AC_VM_MEMORY:-8}"
AC_VM_DISK="${AC_VM_DISK:-32}"

AGENT_VM_DIR="${AGENT_VM_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/agent-vm}"
AGENT_VM_REPO="https://github.com/sylvinus/agent-vm.git"
RUNTIME_VM_FILE="$HOME/.agent-vm/runtime.sh"
ZSHENV="$HOME/.zshenv"

# --- Détection ancien installeur (albert-code() dans shell rc) -----------------
_detect_old_albert_code_function() {
  local rc_file="$1"
  [ -f "$rc_file" ] || return 1
  grep -qE '^[[:space:]]*(function[[:space:]]+)?albert-code[[:space:]]*\(\s*\{?' "$rc_file" 2>/dev/null
}

_remove_old_albert_code_function() {
  local rc_file="$1"
  info "Ancienne fonction albert-code() détectée dans %s — elle surcharge la nouvelle commande." "$rc_file"
  if confirm "Retirer l'ancienne fonction albert-code() de $rc_file ?"; then
    _tmp="$(mktemp)"
    if grep -qE '^function albert-code\s*\{?' "$rc_file" 2>/dev/null; then
      # Function-style: `function albert-code {` or `function albert-code{`
      awk '/^function albert-code[[:space:]]*\{/ {skip=1; next}
           skip && /\{/ { depth++ }
           skip && /\}/ { depth--; if(depth<=0) {skip=0} next }
           !skip { print }' "$rc_file" > "$_tmp"
    else
      # Brace-style: `albert-code() {`
      awk '/^[[:space:]]*albert-code\(\)/ {skip=1; next}
           skip && /\{/ { depth++ }
           skip && /\}/ { depth--; if(depth<=0) {skip=0} next }
           !skip { print }' "$rc_file" > "$_tmp"
    fi
    mv "$_tmp" "$rc_file"
    ok "Fonction albert-code() retirée de $rc_file"
  fi
}

# --- Exécution (shim + Phase A, rétrocompat) ----------------------------------
# Le shim doit être posé AVANT la VM de base (fragile). Si agent-vm setup
# échoue (429, réseau, etc.), la commande `albert-code` est quand même
# disponible pour un essai ultérieur. Cf. AC-R021.
banner
echo
install_shim "albert-code" "$SELF_DIR/bin/albert-code"
echo
phase_a

# Migration ancien installeur : détecter `albert-code()` dans shell rc
RC_FILE="$HOME/.zshrc"
case "${SHELL##*/}" in
  zsh)  RC_FILE="$HOME/.zshrc" ;;
  bash) RC_FILE="$HOME/.bashrc" ;;
  *)    RC_FILE="$HOME/.profile" ;;
esac
for _check_rc in "$RC_FILE" "$HOME/.zshenv"; do
  if _detect_old_albert_code_function "$_check_rc"; then
    _remove_old_albert_code_function "$_check_rc"
    break
  fi
done

echo
title "C'est prêt. Bon code avec Albert."
echo
info "Utilise « albert-code setup » pour configurer un projet,"
info "ou « albert-code run » pour lancer la bulle."

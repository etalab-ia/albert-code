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

# --- Exécution (Phase A + shim, rétrocompat) ----------------------------------
banner
phase_a
echo
install_shim "albert-code" "$SELF_DIR/bin/albert-code"
echo
title "C'est prêt. Bon code avec Albert."
echo
info "Utilise « albert-code setup » pour configurer un projet,"
info "ou « albert-code run » pour lancer la bulle."

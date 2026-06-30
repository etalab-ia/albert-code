#!/usr/bin/env bash
# =============================================================================
# Albert Code — désinstallation propre.
# -----------------------------------------------------------------------------
# Retire ce qu'Albert Code a ajouté, sans toucher au reste du poste :
#   - skills clonées dans ~/.config/opencode/skills/
#   - bloc Albert Code dans ~/.agent-vm/runtime.sh
#   - clés Albert/Context7 dans ~/.zshenv
#   - ligne de sourcing agent-vm dans le shell rc
#   - fichiers projet (opencode.json, .agent-vm.runtime.sh, AGENTS.md de profil)
#
# Ne supprime JAMAIS la config OpenCode globale perso (~/.config/opencode/opencode.*),
# ni les autres providers (Scaleway, etc.), ni les VM existantes (sauf demande).
# Compatible bash 3.2. Idempotent.
# =============================================================================
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/ui.sh
source "$SELF_DIR/lib/ui.sh"

SKILLS_DIR="$HOME/.config/opencode/skills"
RUNTIME_VM_FILE="$HOME/.agent-vm/runtime.sh"
ZSHENV="$HOME/.zshenv"
AGENT_VM_DIR="${AGENT_VM_DIR:-$HOME/Dev/agent-vm}"
AC_MARKER="# --- albert-code : clés VM ---"

banner
title "Désinstallation d'Albert Code"
echo

# 1. Skills État (clone local)
if [ -d "$SKILLS_DIR" ] && confirm "Supprimer les skills État ($SKILLS_DIR) ?"; then
  rm -rf "$SKILLS_DIR"
  ok "skills supprimées"
else
  info "skills conservées"
fi

# 2. Bloc Albert Code dans ~/.agent-vm/runtime.sh
#    Retire : la ligne marqueur + les exports ALBERT_API_KEY / CONTEXT7_API_KEY.
if [ -f "$RUNTIME_VM_FILE" ] && file_contains "$RUNTIME_VM_FILE" "$AC_MARKER"; then
  if confirm "Retirer le bloc Albert Code de ~/.agent-vm/runtime.sh ?"; then
    _tmp="$(mktemp)"
    grep -vE "$AC_MARKER|^export (ALBERT_API_KEY|CONTEXT7_API_KEY)=" "$RUNTIME_VM_FILE" > "$_tmp" || true
    mv "$_tmp" "$RUNTIME_VM_FILE"
    chmod 600 "$RUNTIME_VM_FILE" 2>/dev/null || true
    ok "bloc Albert Code retiré de ~/.agent-vm/runtime.sh"
  fi
fi

# 3. Clés dans ~/.zshenv
for var in ALBERT_API_KEY CONTEXT7_API_KEY; do
  if file_contains "$ZSHENV" "^export ${var}="; then
    if confirm "Retirer $var de ~/.zshenv ?"; then
      _tmp="$(mktemp)"
      grep -vE "^export ${var}=" "$ZSHENV" > "$_tmp" || true
      mv "$_tmp" "$ZSHENV"
      chmod 600 "$ZSHENV" 2>/dev/null || true
      ok "$var retirée de ~/.zshenv"
    fi
  fi
done

# 4. Sourcing agent-vm dans le shell rc
rc=""
case "${SHELL##*/}" in
  zsh)  rc="$HOME/.zshrc" ;;
  bash) rc="$HOME/.bashrc" ;;
  *)    rc="$HOME/.profile" ;;
esac
if [ -f "$rc" ] && file_contains "$rc" "agent-vm.sh"; then
  if confirm "Retirer le sourcing d'agent-vm de $rc ?"; then
    _tmp="$(mktemp)"
    grep -v "agent-vm.sh" "$rc" > "$_tmp" || true
    mv "$_tmp" "$rc"
    ok "sourcing retiré de $rc"
  fi
fi

# 5. agent-vm (clone + VMs) — optionnel, lourd
if [ -d "$AGENT_VM_DIR" ] && confirm "Supprimer agent-vm ($AGENT_VM_DIR) et ses VMs ?"; then
  command -v agent-vm >/dev/null 2>&1 && agent-vm destroy-all 2>/dev/null || true
  rm -rf "$AGENT_VM_DIR"
  ok "agent-vm supprimé"
fi

# 6. Fichiers projet (dans le dossier courant)
echo
title "Fichiers du projet courant ($PWD)"
for f in opencode.json .agent-vm.runtime.sh AGENTS.md; do
  if [ -f "./$f" ] && confirm "Supprimer ./$f ?"; then
    rm -f "./$f"
    ok "./$f supprimé"
  fi
done

echo
warn "La config OpenCode globale perso (~/.config/opencode/opencode.*) est conservée."
ok "Désinstallation terminée."

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
SKILLS_CACHE="$HOME/.config/opencode/.albert-skills-cache"
RUNTIME_VM_FILE="$HOME/.agent-vm/runtime.sh"
ZSHENV="$HOME/.zshenv"
AGENT_VM_DIR="${AGENT_VM_DIR:-$SELF_DIR/vendor/vm}"
AC_MARKER="# --- albert-code : clés VM ---"

banner
title "Désinstallation d'Albert Code"
echo

# 1. Skills État (symlinks + cache, préserve les skills perso)
if [ -d "$SKILLS_DIR" ] && confirm "Retirer les liens des skills État et le cache ($SKILLS_DIR) ?"; then
  # Retire uniquement les symlinks pointant vers le cache
  removed=0
  for _f in "$SKILLS_DIR"/*; do
    [ -L "$_f" ] || continue
    target="$(readlink "$_f")"
    if echo "$target" | grep -q "$SKILLS_CACHE"; then
      rm -f "$_f"
      removed=$((removed + 1))
    fi
  done
  # Supprime le cache
  rm -rf "$SKILLS_CACHE" 2>/dev/null || true
  ok "%d symlinks retirés, cache skills État supprimé" "$removed"
  info "Les skills perso dans $SKILLS_DIR sont conservées."
else
  info "skills conservées"
fi

# 2. Bloc Albert Code dans ~/.agent-vm/runtime.sh
#    Supprime UNIQUEMENT les lignes entre AC_MARKER et AC_MARKER_END (inclusif)
#    (ou du marqueur jusqu'au 1er contenu non-export pour l'ancien format).
#    Ne touche JAMAIS aux lignes hors de cette plage (exports perso, etc.).
if [ -f "$RUNTIME_VM_FILE" ] && file_contains "$RUNTIME_VM_FILE" "$AC_MARKER"; then
  if confirm "Retirer le bloc Albert Code de ~/.agent-vm/runtime.sh ?"; then
    _tmp="$(mktemp)"
    if file_contains "$RUNTIME_VM_FILE" "$AC_MARKER_END"; then
      sed -E "\|^${AC_MARKER}$|,\|^${AC_MARKER_END}$|d" "$RUNTIME_VM_FILE" > "$_tmp"
    else
      awk -v marker="$AC_MARKER" '
        $0 == marker { in_block=1; next }
        in_block && $0 ~ /^export (ALBERT_API_KEY|CONTEXT7_API_KEY)=/ { next }
        in_block && $0 ~ /^[[:space:]]*$/ { next }
        in_block { in_block=0 }
        { print }
      ' "$RUNTIME_VM_FILE" > "$_tmp"
    fi
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

# 4. Ancien installeur : fonction `albert-code()` dans shell rc (surcharge le shim)
_detect_old_albert_code_function() {
  local rc_file="$1"
  [ -f "$rc_file" ] || return 1
  grep -qE '^[[:space:]]*(function[[:space:]]+)?albert-code[[:space:]]*\(\s*\{?' "$rc_file" 2>/dev/null
}

_remove_old_albert_code_function() {
  local rc_file="$1"
  info "Ancienne fonction albert-code() détectée dans %s" "$rc_file"
  if confirm "Retirer l'ancienne fonction albert-code() de $rc_file ?"; then
    local _tmp
    _tmp="$(mktemp)"
    if grep -qE '^function albert-code\s*\{?' "$rc_file" 2>/dev/null; then
      # Function-style: `function albert-code {`
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

RC_FILE_ALBERT=""
case "${SHELL##*/}" in
  zsh)  RC_FILE_ALBERT="$HOME/.zshrc" ;;
  bash) RC_FILE_ALBERT="$HOME/.bashrc" ;;
  *)    RC_FILE_ALBERT="$HOME/.profile" ;;
esac
for _check_rc in "$RC_FILE_ALBERT" "$HOME/.zshenv"; do
  if _detect_old_albert_code_function "$_check_rc"; then
    _remove_old_albert_code_function "$_check_rc"
    break
  fi
done

# 5. Ancien sourçage agent-vm dans le shell rc (migration)
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

# 6. VMs Lima (optionnel) — les VMs créées par agent-vm
if command -v limactl >/dev/null 2>&1 && limactl list -q 2>/dev/null | grep -q '^agent-vm-'; then
  if confirm "Supprimer toutes les VMs agent-vm (Lima) ?"; then
    if command -v agent-vm >/dev/null 2>&1; then
      agent-vm destroy-all 2>/dev/null || true
    fi
    ok "VMs agent-vm supprimées"
  fi
fi


# 7. Fichiers projet (dans le dossier courant)
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
warn "Le ~/.zshenv de la VM n'est pas nettoyé (la VM est jetable : agent-vm destroy + réinstall)."
ok "Désinstallation terminée."

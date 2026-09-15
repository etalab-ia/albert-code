#!/usr/bin/env bash
# =============================================================================
# Albert Code — désinstallation propre.
# -----------------------------------------------------------------------------
# Retire ce qu'Albert Code a ajouté, sans toucher au reste du poste :
#   - skills clonées dans ~/.config/opencode/skills/
#   - les 5 clés gérées par Albert Code dans ~/.agent-vm/env
#   - bloc Albert Code dans ~/.agent-vm/runtime.sh (installations antérieures)
#   - clés Albert/Context7 dans ~/.zshenv
#   - ligne d'ajout de ~/.local/bin au PATH posée par install_shim (fichier rc)
#   - fichiers projet (opencode.json, .agent-vm.runtime.sh, AGENTS.md de profil)
#
# Ne supprime JAMAIS la config OpenCode globale perso (~/.config/opencode/opencode.*),
# ni les autres providers (Scaleway, etc.), ni les VM existantes (sauf demande),
# ni agent-vm lui-même : c'est un outil séparé, sa ligne de sourçage reste en
# place pour que la commande « agent-vm » continue de fonctionner.
# Compatible bash 3.2. Idempotent.
# =============================================================================
set -euo pipefail

# CDPATH= : cf. install.sh — un relatif nu serait résolu via CDPATH.
SELF_DIR="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
# shellcheck source=lib/ui.sh
source "$SELF_DIR/lib/ui.sh"
# shellcheck source=lib/vm.sh
source "$SELF_DIR/lib/vm.sh"

SKILLS_DIR="$HOME/.config/opencode/skills"
SKILLS_CACHE="$HOME/.config/opencode/.albert-skills-cache"
RUNTIME_VM_FILE="${RUNTIME_VM_FILE:-$HOME/.agent-vm/runtime.sh}"
ZSHENV="${ZSHENV:-$HOME/.zshenv}"
AC_ENV_FILE="${AC_ENV_FILE:-$HOME/.agent-vm/env}"
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

# 2bis. Secrets poussés dans les VM (~/.agent-vm/env)
#       Ne retire QUE les lignes des variables gérées par Albert Code ; les
#       autres lignes du fichier (posées à la main, ou par un autre outil)
#       sont conservées — c'est un fichier d'agent-vm, pas d'Albert Code.
#
#       Seul endroit du bundle qui lit ce fichier directement plutôt que de
#       passer par `agent-vm env unset`, et c'est délibéré : une désinstallation
#       doit fonctionner quand l'outil est déjà à moitié parti. Si le moteur a
#       été retiré avant Albert Code, ses clés resteraient sinon en place.
if [ -f "$AC_ENV_FILE" ]; then
  if confirm "Retirer les clés d'Albert Code de ~/.agent-vm/env ?"; then
    _before="$(grep -cE "^(ALBERT_API_KEY|CONTEXT7_API_KEY|GH_TOKEN|AC_GIT_USER_NAME|AC_GIT_USER_EMAIL)=" "$AC_ENV_FILE" || true)"
    _tmp="$(mktemp)"
    grep -vE "^(ALBERT_API_KEY|CONTEXT7_API_KEY|GH_TOKEN|AC_GIT_USER_NAME|AC_GIT_USER_EMAIL)=" \
      "$AC_ENV_FILE" > "$_tmp" || true
    mv "$_tmp" "$AC_ENV_FILE"
    chmod 600 "$AC_ENV_FILE" 2>/dev/null || true
    # Annoncer ce qui s'est réellement passé, pas ce qu'on a tenté.
    if [ "${_before:-0}" -gt 0 ]; then
      ok "%s clé(s) retirée(s) de ~/.agent-vm/env" "$_before"
      info "Les autres lignes du fichier sont conservées."
    else
      info "Aucune clé d'Albert Code dans ~/.agent-vm/env — fichier inchangé."
    fi
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

# 3bis. Ligne d'ajout de ~/.local/bin au PATH posée par install_shim (T5.4, symétrie).
#      Ne retire QUE la ligne exacte du bundle ; un ajout d'une autre provenance
#      est conservé et signalé.
AC_PATH_RC="$(path_rc_file)"
if file_contains "$AC_PATH_RC" 'export PATH="\$HOME/.local/bin:\$PATH"'; then
  if confirm "Retirer l'ajout de ~/.local/bin au PATH de $AC_PATH_RC ?"; then
    _tmp="$(mktemp)"
    grep -vF 'export PATH="$HOME/.local/bin:$PATH"' "$AC_PATH_RC" > "$_tmp" || true
    mv "$_tmp" "$AC_PATH_RC"
    chmod 600 "$AC_PATH_RC" 2>/dev/null || true
    ok "ajout au PATH retiré de $AC_PATH_RC"
  fi
elif file_contains "$AC_PATH_RC" "\.local/bin"; then
  warn "Un ajout de ~/.local/bin est présent dans $AC_PATH_RC mais n'est pas la ligne du bundle : il est conservé."
fi

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

# 5. Sourçage d'agent-vm dans le shell rc.
#    agent-vm est un outil SÉPARÉ, qu'Albert Code n'a pas forcément installé :
#    retirer cette ligne casserait la commande « agent-vm » de l'utilisateur.
#    On ne la propose donc plus par défaut, on signale seulement.
rc="$(shell_rc_file)"
if [ -f "$rc" ] && file_contains "$rc" "agent-vm.sh"; then
  info "Le sourçage d'agent-vm dans %s est conservé." "$rc"
  info "agent-vm est un outil indépendant : Albert Code n'y touche pas."
fi

# 6. VMs Lima (optionnel) — les VMs créées par agent-vm
#    Capture d'abord, pas de « | grep -q » : sous pipefail, grep -q ferme le
#    pipe et limactl part en SIGPIPE (faux négatif intermittent).
if command -v limactl >/dev/null 2>&1; then
  _vms="$(limactl list -q 2>/dev/null || true)"
  case $'\n'"$_vms"$'\n' in
    *$'\n'agent-vm-*)
      if confirm "Supprimer toutes les VMs agent-vm (Lima) ?"; then
        if ac_vm_present; then
          # Le moteur redemande confirmation et peut être annulé : on ne peut
          # pas affirmer la suppression depuis ici, on laisse sa sortie parler.
          _vm destroy-all || true
        else
          warn "Moteur de VM introuvable — supprime-les avec « agent-vm destroy-all »."
        fi
      fi ;;
  esac
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

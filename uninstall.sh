#!/usr/bin/env bash
# =============================================================================
# Albert Code — désinstallation propre.
# -----------------------------------------------------------------------------
# Retire ce qu'Albert Code a ajouté, sans toucher au reste du poste :
#   - skills clonées dans ~/.config/opencode/skills/
#   - bloc Albert Code dans ~/.agent-vm/runtime.sh
#   - les 5 secrets/identités que persist_zshenv écrit dans ~/.zshenv
#     (ALBERT_API_KEY, CONTEXT7_API_KEY, GH_TOKEN, AC_GIT_USER_NAME,
#     AC_GIT_USER_EMAIL)
#   - ligne d'ajout de ~/.local/bin au PATH posée par install_shim (fichier rc)
#   - ligne de sourcing agent-vm dans le shell rc (avec sauvegarde .bak)
#   - le shim `albert-code` posé par install_shim (uniquement s'il s'agit du sien)
#   - les VMs Lima nommées `agent-vm-…` (sur acceptation, défaut OUI)
#   - .agent-vm.runtime.sh du projet courant (AGENTS.md/opencode.json conservés)
#
# Ne supprime JAMAIS la config OpenCode globale perso (~/.config/opencode/opencode.*),
# ni les autres providers (Scaleway, etc.), ni un binaire albert-code étranger.
# Compatible bash 3.2. Idempotent. `--dry-run` = aucune modification.
# =============================================================================
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/ui.sh
source "$SELF_DIR/lib/ui.sh"

# --- Parsing -----------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; export DRY_RUN ;;
    --help|-h)
      echo "Usage : ./uninstall.sh [--dry-run]"
      echo "Retire proprement ce qu'Albert Code a posé (secrets, VM, shim, project files)."
      exit 0 ;;
    *) err "Option inconnue : $1"; exit 1 ;;
  esac
  shift
done

SKILLS_DIR="$HOME/.config/opencode/skills"
SKILLS_CACHE="$HOME/.config/opencode/.albert-skills-cache"
RUNTIME_VM_FILE="${RUNTIME_VM_FILE:-$HOME/.agent-vm/runtime.sh}"
ZSHENV="${ZSHENV:-$HOME/.zshenv}"
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
      # Ancien format (sans AC_MARKER_END) : ne retire que les exports posés par
      # persist_zshenv, dans le bloc, jamais une ligne hors plage.
      awk -v marker="$AC_MARKER" '
        $0 == marker { in_block=1; next }
        in_block && $0 ~ /^export (ALBERT_API_KEY|CONTEXT7_API_KEY|GH_TOKEN|AC_GIT_USER_NAME|AC_GIT_USER_EMAIL)=/ { next }
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

# 3. Clés et identité dans ~/.zshenv (les cinq variables que persist_zshenv écrit)
for var in ALBERT_API_KEY CONTEXT7_API_KEY GH_TOKEN AC_GIT_USER_NAME AC_GIT_USER_EMAIL; do
  if file_contains "$ZSHENV" "^export ${var}="; then
    if confirm "Retirer $var de ~/.zshenv ?"; then
      _tmp="$(mktemp)"
      grep -vE "^export ${var}=" "$ZSHENV" > "$_tmp" || true
      _dry_gate "retirer $var de ~/.zshenv" && mv "$_tmp" "$ZSHENV"
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

# 4bis. Shim `albert-code` posé par install_shim (symétrie de l'installation).
#       Ne retire QUE le shim du bundle (en-tête « Shim pour albert-code »,
#       détection reprise d'install_shim) ; un binaire albert-code d'une autre
#       provenance est conservé et signalé.
_ac_shim=""
_ac_shim_foreign=""
_ac_old_ifs="$IFS"; IFS=':'
for _dir in $PATH; do
  [ -z "$_dir" ] && continue
  if [ -f "$_dir/albert-code" ] && [ -x "$_dir/albert-code" ]; then
    if head -3 "$_dir/albert-code" 2>/dev/null | grep -q "Shim pour albert-code"; then
      _ac_shim="$_dir/albert-code"
      break
    elif [ -z "$_ac_shim_foreign" ]; then
      _ac_shim_foreign="$_dir/albert-code"
    fi
  fi
done
IFS="$_ac_old_ifs"
if [ -n "$_ac_shim" ]; then
  if confirm "Retirer le shim albert-code ($_ac_shim) ?"; then
    _dry_gate "retirer le shim $_ac_shim" && rm -f "$_ac_shim"
    ok "shim albert-code retiré de $_ac_shim"
  fi
elif [ -n "$_ac_shim_foreign" ]; then
  warn "Un binaire albert-code d'une autre provenance est présent ($_ac_shim_foreign) :"
  warn "il est conservé — supprime-le à la main si tu le souhaites."
else
  info "aucun shim albert-code trouvé sur le PATH"
fi

# 5. Ancien sourçage agent-vm dans le shell rc (migration)
#    Ne retire QUE les lignes qui sourcent agent-vm.sh (commande source ou `.`,
#    y compris sous la forme `[ -f … ] && source …`), en comparaison littérale
#    sur agent-vm.sh — jamais une simple mention de « agent-vm ». Sauvegarde le
#    rc en <rc>.bak avant modification.
rc=""
case "${SHELL##*/}" in
  zsh)  rc="$HOME/.zshrc" ;;
  bash) rc="$HOME/.bashrc" ;;
  *)    rc="$HOME/.profile" ;;
esac
if [ -f "$rc" ] && awk '
    /(^|[[:space:]](&&[[:space:]]+)?)(source|[.])[[:space:]]+/ && index($0, "agent-vm.sh") > 0 { found=1; exit }
    END { exit !found }
  ' "$rc"; then
  if confirm "Retirer le sourcing d'agent-vm de $rc ?"; then
    _dry_gate "sauvegarder $rc dans $rc.bak" && cp "$rc" "$rc.bak"
    _tmp="$(mktemp)"
    awk '/(^|[[:space:]](&&[[:space:]]+)?)(source|[.])[[:space:]]+/ && index($0, "agent-vm.sh") > 0 { next } { print }' "$rc" > "$_tmp"
    _dry_gate "retirer le sourcing d'agent-vm de $rc" && mv "$_tmp" "$rc"
    chmod 600 "$rc" 2>/dev/null || true
    ok "sourcing d'agent-vm retiré de $rc (sauvegarde : $rc.bak)"
  fi
fi

# 6. VMs Lima agent-vm — suppression propre, définitive, jamais déguisée.
#    Ne passe pas par agent-vm destroy-all : on supprime directement via
#    limactl, VM par VM, et on rend un compte HONNÊTE de l'état restant.
echo
title "VMs agent-vm (Lima)"
if ! command -v limactl >/dev/null 2>&1; then
  warn "limactl est absent du PATH : aucune VM Lima ne peut être supprimée ici."
else
  _ac_vms="$(limactl list -q 2>/dev/null | grep '^agent-vm-' || true)"
  if [ -z "$_ac_vms" ]; then
    info "Aucune VM Lima « agent-vm-… » détectée — rien à supprimer."
  else
    echo
    info "VMs Albert Code détectées :"
    printf '%s\n' "$_ac_vms" | sed 's/^/    - /'
    echo
    warn "Les supprimer retire, de façon définitive, les clés (ALBERT_API_KEY,"
    warn "GH_TOKEN, …) et l'historique de travail stockés dans ces VMs."
    if confirm_yes "Supprimer ces VMs (défaut: oui) ?"; then
      printf '%s\n' "$_ac_vms" | while read -r _vm; do
        [ -z "$_vm" ] && continue
        if _dry_gate "supprimer la VM $_vm"; then
          limactl stop "$_vm" >/dev/null 2>&1 || true
          limactl delete --force "$_vm" >/dev/null 2>&1 || true
        fi
      done
      # Compte honnête après coup.
      _ac_remaining="$(limactl list -q 2>/dev/null | grep '^agent-vm-' || true)"
      if [ "$DRY_RUN" -eq 1 ]; then
        warn "dry-run : aucune VM supprimée."
      elif [ -z "$_ac_remaining" ]; then
        ok "Toutes les VMs agent-vm ont été supprimées."
      else
        warn "Des VMs agent-vm existent encore :"
        printf '%s\n' "$_ac_remaining" | sed 's/^/    - /'
      fi
    else
      warn "VMs conservées — leurs clés et leur historique restent sur cette machine"
      warn "(aucune suppression effectuée)."
    fi
  fi
fi

# 7. Fichiers du projet courant — ne retire QUE le runtime partie projet.
#    AGENTS.md et opencode.json appartiennent à l'utilisateur : jamais supprimés.
echo
title "Fichiers du projet courant ($PWD)"
if [ -f "./.agent-vm.runtime.sh" ] && confirm "Retirer ./.agent-vm.runtime.sh ?"; then
  _dry_gate "retirer ./.agent-vm.runtime.sh" && rm -f "./.agent-vm.runtime.sh"
  ok "./.agent-vm.runtime.sh retiré"
fi
info "AGENTS.md, opencode.json et .albert-code/ sont conservés (tes fichiers)."
info "Dans tes autres projets, retire .agent-vm.runtime.sh à la main si tu le souhaites."

# 8. Récapitulatif final — remplace les anciens warn de fin.
echo
title "Récapitulatif"
info "Cette désinstallation a retiré : skills État (liens + cache), bloc Albert"
info "Code du runtime VM, les 5 secrets/identité de ~/.zshenv, le sourcing"
info "agent-vm du rc (avec .bak), le shim albert-code, les VMs agent-vm (si"
info "accepté) et .agent-vm.runtime.sh du projet."
echo
warn "Reste volontairement en place (retire-le à la main si besoin) :"
warn "  - Lima (installé via Homebrew) :          brew uninstall lima"
warn "  - le clone du dépôt albert-code :          supprime le dossier du dépôt"
warn "  - ~/.agent-vm/ :                           hors bloc Albert Code, conservé"
warn "  - config OpenCode globale (perso) :        ~/.config/opencode/opencode.*"
echo
warn "Pense à révoquer le jeton GitHub utilisé par Albert Code sur"
warn "https://github.com/settings/tokens pour couper tout accès résiduel."
ok "Désinstallation terminée."

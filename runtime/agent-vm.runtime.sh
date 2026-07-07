#!/usr/bin/env bash
# =============================================================================
# Albert Code — runtime de référence (VM).
# -----------------------------------------------------------------------------
# Ce script est copié à la racine du projet cible sous le nom `.agent-vm.runtime.sh`.
# Il s'exécute DANS la VM à chaque démarrage, juste après `~/.agent-vm/runtime.sh`.
#
# Rôles :
#   1. Persister ALBERT_API_KEY (et CONTEXT7_API_KEY) dans le ~/.zshenv de la VM
#      ( piège : shells non-interactifs ne lisent pas ~/.zshrc).
#   2. Synchroniser les skills État (clone ou git pull de etalab-ia/skills).
#   3. Vérifier la présence d'OpenCode.
#
# Principes : idempotent (relançable sans casser) · non-destructif (additif).
# Compatible bash 3.2. Ne jamais contenir de secret en clair.
# =============================================================================
set -euo pipefail

# --- Parsing des arguments -----------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --help|-h)
      cat <<'USAGE'
Albert Code — runtime VM

Usage: ./.agent-vm.runtime.sh [--dry-run] [--help]

Options:
  --dry-run   Affiche chaque action sans l'exécuter (test sur VM déjà configurée).
  --help      Affiche cette aide.

Variables d'environnement (sandbox) :
  HOME                   Redirige ~/.zshenv, ~/.config/opencode dans la VM.
  OPENCODE_CONFIG_DIR     Dossier de config OpenCode (défaut: ~/.config/opencode).
USAGE
      exit 0 ;;
    *) ;;
  esac
  shift
done

DRY_RUN="${DRY_RUN:-0}"
OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"

# --- Couleurs (silencieuses hors TTY) -----------------------------------------
if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_RED=$'\033[31m'; C_GREY=$'\033[90m'
else
  C_RESET=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_RED=""; C_GREY=""
fi
_info() { printf '%s→ %s%s\n'  "${C_BLUE}"   "$*" "${C_RESET}"; }
_ok()   { printf '%s✓ %s%s\n'  "${C_GREEN}"  "$*" "${C_RESET}"; }
_warn() { printf '%s! %s%s\n'  "${C_YELLOW}" "$*" "${C_RESET}"; }
_err()  { printf '%s✗ %s%s\n'  "${C_RED}"    "$*" "${C_RESET}" >&2; }

# --- Dry-run gate (identique à lib/ui.sh) -------------------------------------
# _dry_gate : LE point d'entrée unique pour toute mutation.
_dry_gate() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s[dry-run] %s%s\n' "${C_GREY}" "$1" "${C_RESET}"
    return 1
  fi
  return 0
}
_apply()        { local d="$1"; shift; _dry_gate "$d" || return 0; "$@"; }
_apply_append() { local d="$1" f="$2" l="$3"; _dry_gate "$d" || return 0; printf '%s\n' "$l" >> "$f"; }
_apply_mkdir()  { local d="$1" dir="$2"; _dry_gate "$d" || return 0; mkdir -p "$dir"; }
_apply_touch()  { local d="$1" f="$2"; _dry_gate "$d" || return 0; touch "$f" 2>/dev/null || true; }
_apply_chmod()  { local d="$1" mode="$2" f="$3"; _dry_gate "$d" || return 0; chmod "$mode" "$f" 2>/dev/null || true; }
_apply_symlink() { local d="$1" t="$2" l="$3"; _dry_gate "$d" || return 0; ln -sf "$t" "$l" 2>/dev/null || true; }

SKILLS_REPO="https://github.com/etalab-ia/skills.git"
SKILLS_CACHE="$OPENCODE_CONFIG_DIR/.albert-skills-cache"
SKILLS_TARGET="$OPENCODE_CONFIG_DIR/skills"

# -----------------------------------------------------------------------------
# persist_env_var <VAR> <VALEUR>
#   Écrit `export VAR=VALEUR` dans ~/.zshenv si la ligne n'existe pas déjà.
#   Additif : n'écrase jamais une valeur déjà posée par l'utilisateur.
# -----------------------------------------------------------------------------
persist_env_var() {
  local var="$1" val="$2"
  local zshenv="$HOME/.zshenv"

  [ -z "$val" ] && return 0

  _apply_touch "créer $zshenv si absent" "$zshenv"
  _apply_chmod "chmod 600 $zshenv (contient une clé)" 600 "$zshenv"

  if grep -qE "^export ${var}=" "$zshenv" 2>/dev/null; then
    _ok "$var déjà présente dans ~/.zshenv (inchangée)"
  else
    # Valeur entre simples quotes ; on neutralise les quotes internes.
    local safe_val
    safe_val="${val//\'/\'\"\'\"\'}"
    _apply_append "ajouter $var à ~/.zshenv" "$zshenv" "export ${var}='${safe_val}'"
    [ "$DRY_RUN" -eq 0 ] && export "$var=$val" || true
    [ "$DRY_RUN" -eq 0 ] && _ok "$var ajoutée à ~/.zshenv" || true
  fi
}

# -----------------------------------------------------------------------------
# setup_github_auth — câble l'auth GitHub de la VM (push + ouverture de PR)
#   SANS jamais contenir de secret : actif uniquement si GH_TOKEN est déjà dans
#   l'environnement (posé par ~/.agent-vm/runtime.sh → ~/.zshenv de la VM).
#   Rôles : (1) persister GH_TOKEN, (2) poser l'identité git globale
#   (AC_GIT_USER_NAME / AC_GIT_USER_EMAIL), (3) brancher git sur le token via
#   `gh auth setup-git` (credential helper HTTPS). Idempotent. Token jamais loggé.
#   SSH ne suffirait pas : `gh pr create` exige un token, pas une clé SSH.
# -----------------------------------------------------------------------------
setup_github_auth() {
  if [ -z "${GH_TOKEN:-}" ]; then
    _warn "GH_TOKEN absent — push/PR depuis la VM non configurés (voir README § Push & PR depuis la VM)"
    return 0
  fi

  # 1. Persister le token (shells non-interactifs + TUI).
  persist_env_var "GH_TOKEN" "$GH_TOKEN"

  # 2. Identité git globale (sinon commits sous une identité par défaut douteuse).
  if [ -n "${AC_GIT_USER_NAME:-}" ] && [ -n "${AC_GIT_USER_EMAIL:-}" ]; then
    _apply "identité git : user.name"  git config --global user.name  "$AC_GIT_USER_NAME"
    _apply "identité git : user.email" git config --global user.email "$AC_GIT_USER_EMAIL"
    [ "$DRY_RUN" -eq 0 ] && _ok "identité git posée (${AC_GIT_USER_NAME} <${AC_GIT_USER_EMAIL}>)" || true
  else
    _warn "AC_GIT_USER_NAME / AC_GIT_USER_EMAIL absents — identité git non posée"
  fi

  # 3. Brancher git sur le token pour le push HTTPS (idempotent).
  if command -v gh >/dev/null 2>&1; then
    if _apply "gh auth setup-git (credential helper HTTPS)" gh auth setup-git; then
      [ "$DRY_RUN" -eq 0 ] && _ok "git branché sur le token — push + PR actifs" || true
    else
      _warn "gh auth setup-git a échoué (token invalide ou expiré ?)"
    fi
  else
    _warn "gh CLI absent de la VM — credential helper non branché"
  fi
}

# -----------------------------------------------------------------------------
# sync_skills — clone ou met à jour les skills État (cache + symlinks).
# Si le projet courant a un fichier .albert-code/skills.txt, seules les skills
# listées sont symlinkées (et les non-sélectionnées sont retirées du dossier
# global skills/). Sans manifeste, toutes les skills sont installées (rétrocompat).
# Les skills perso (non-symlinks) ne sont JAMAIS touchées.
# -----------------------------------------------------------------------------
sync_skills() {
  # 1. Cache repo
  if [ -d "$SKILLS_CACHE/.git" ]; then
    _ok "cache skills déjà cloné — mise à jour…"
    _apply "maj cache skills (git pull)" git -C "$SKILLS_CACHE" pull --ff-only --quiet 2>/dev/null || true
    [ "$DRY_RUN" -eq 0 ] && _ok "cache skills à jour" || true
  else
    _info "Clonage du cache skills État (etalab-ia/skills)…"
    _apply_mkdir "créer $(dirname "$SKILLS_CACHE")" "$(dirname "$SKILLS_CACHE")"
    if [ "$DRY_RUN" -eq 1 ]; then
      _apply "cloner cache skills dans $SKILLS_CACHE" true
    elif git clone --depth 1 --quiet "$SKILLS_REPO" "$SKILLS_CACHE" 2>/dev/null; then
      _ok "cache skills cloné dans $SKILLS_CACHE"
    else
      _warn "clonage cache impossible (hors ligne ?)"
    fi
  fi

  # 2. Déterminer la liste des skills à installer
  local manifest="$PWD/.albert-code/skills.txt"
  local use_manifest=0
  local selected_skills=""
  if [ -f "$manifest" ]; then
    selected_skills="$(grep -v '^[[:space:]]*$' "$manifest" 2>/dev/null || true)"
    if [ -n "$selected_skills" ]; then
      use_manifest=1
      _info "Skills sélectionnées via .albert-code/skills.txt"
    fi
  fi

  # 3. Symlink les skills sélectionnées (ou toutes si pas de manifeste),
  #    et réconcilier : retirer les symlinks albert-code non sélectionnés.
  _apply_mkdir "créer $SKILLS_TARGET" "$SKILLS_TARGET"
  if [ -d "$SKILLS_CACHE/skills" ]; then
    local linked=0 skipped=0 removed=0

    # Construire la liste des noms disponibles dans le cache
    local all_skills=""
    for _entry in "$SKILLS_CACHE/skills"/*/; do
      [ -d "$_entry" ] || continue
      local name="$(basename "$_entry")"
      case "$name" in .*|.experimental|.git) continue ;; esac
      all_skills="${all_skills} ${name}"

      if [ "$use_manifest" -eq 1 ]; then
        # Vérifier si la skill est dans la sélection
        if echo "$selected_skills" | grep -qFx "$name"; then
          local link_path="$SKILLS_TARGET/$name"
          if [ -e "$link_path" ] && [ ! -L "$link_path" ]; then
            [ "$DRY_RUN" -eq 0 ] && _warn "skill « ${name} » déjà présente (perso) — conservée" || true
            skipped=$((skipped + 1))
          else
            _apply_symlink "symlink $name" "$_entry" "$link_path"
            linked=$((linked + 1))
          fi
        fi
        # else : skill non sélectionnée → ne pas symlinker
      else
        # Rétrocompat : toutes les skills
        local link_path="$SKILLS_TARGET/$name"
        if [ -e "$link_path" ] && [ ! -L "$link_path" ]; then
          [ "$DRY_RUN" -eq 0 ] && _warn "skill « ${name} » déjà présente (perso) — conservée" || true
          skipped=$((skipped + 1))
        else
          _apply_symlink "symlink $name" "$_entry" "$link_path"
          linked=$((linked + 1))
        fi
      fi
    done

    # 4. Réconciliation : retirer les symlinks orphelins (skills État non sélectionnées)
    if [ "$use_manifest" -eq 1 ]; then
      for _existing in "$SKILLS_TARGET"/*/; do
        [ -L "$_existing" ] || continue
        local ename="$(basename "$_existing")"
        # Ne retirer QUE les symlinks vers le cache skills État
        local resolved="$(readlink "$_existing" 2>/dev/null || true)"
        case "$resolved" in
          */etalab-ia/*|*/skills/*) ;;
          *) continue ;; # pas une skill État, on laisse
        esac
        # Si la skill n'est plus dans la sélection
        if ! echo "$selected_skills" | grep -qFx "$ename"; then
          _apply "retirer symlink obsolète $ename" rm "$_existing"
          removed=$((removed + 1))
        fi
      done
    fi

    [ "$DRY_RUN" -eq 0 ] && _ok "${linked} skills liées, ${skipped} ignorées (existantes), ${removed} retirées (non sélectionnées)" || true
  fi
}

# -----------------------------------------------------------------------------
# check_opencode — OpenCode est préinstallé dans la VM de base agent-vm.
# -----------------------------------------------------------------------------
check_opencode() {
  if command -v opencode >/dev/null 2>&1; then
    _ok "OpenCode présent ($(opencode --version 2>/dev/null || echo 'installé'))"
  else
    _warn "OpenCode absent — installe-le (npm i -g opencode-ai) puis relance"
  fi
}

# =============================================================================
# Exécution
# =============================================================================
_info "Runtime Albert Code — démarrage…"

# 1. Persistance des clés dans le ~/.zshenv de la VM (shells non-interactifs).
#    Les valeurs proviennent de l'environnement (posées par ~/.agent-vm/runtime.sh).
persist_env_var "ALBERT_API_KEY"  "${ALBERT_API_KEY:-}"
persist_env_var "CONTEXT7_API_KEY" "${CONTEXT7_API_KEY:-}"

# 2. Auth GitHub (push + ouverture de PR depuis la VM) — actif si GH_TOKEN présent.
setup_github_auth

# 3. Synchronisation des skills (fraîches à chaque boot).
sync_skills

# 4. Vérification d'OpenCode.
check_opencode

_ok "Runtime Albert Code prêt. Lance « opencode » pour démarrer."

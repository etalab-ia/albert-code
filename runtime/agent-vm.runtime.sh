#!/usr/bin/env bash
# =============================================================================
# Albert Code — runtime de référence (agent-vm).
# -----------------------------------------------------------------------------
# Ce script est copié à la racine du projet cible sous le nom `.agent-vm.runtime.sh`.
# Il s'exécute DANS la VM agent-vm à chaque démarrage, juste après `~/.agent-vm/runtime.sh`.
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

# --- Couleurs (silencieuses hors TTY) -----------------------------------------
if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_RED=$'\033[31m'
else
  C_RESET=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_RED=""
fi
_info() { printf '%s→ %s%s\n'  "${C_BLUE}"   "$*" "${C_RESET}"; }
_ok()   { printf '%s✓ %s%s\n'  "${C_GREEN}"  "$*" "${C_RESET}"; }
_warn() { printf '%s! %s%s\n'  "${C_YELLOW}" "$*" "${C_RESET}"; }
_err()  { printf '%s✗ %s%s\n'  "${C_RED}"    "$*" "${C_RESET}" >&2; }

SKILLS_REPO="https://github.com/etalab-ia/skills.git"
SKILLS_DIR="$HOME/.config/opencode/skills"

# -----------------------------------------------------------------------------
# persist_env_var <VAR> <VALEUR>
#   Écrit `export VAR=VALEUR` dans ~/.zshenv si la ligne n'existe pas déjà.
#   Additif : n'écrase jamais une valeur déjà posée par l'utilisateur.
# -----------------------------------------------------------------------------
persist_env_var() {
  local var="$1" val="$2"
  local zshenv="$HOME/.zshenv"

  [ -z "$val" ] && return 0

  touch "$zshenv" 2>/dev/null || return 0

  if grep -qE "^export ${var}=" "$zshenv" 2>/dev/null; then
    _ok "$var déjà présente dans ~/.zshenv (inchangée)"
  else
    # Valeur entre simples quotes ; on neutralise les quotes internes.
    local safe_val
    safe_val="${val//\'/\'\"\'\"\'}"
    printf "export %s='%s'\n" "$var" "$safe_val" >> "$zshenv"
    export "$var=$val"
    _ok "$var ajoutée à ~/.zshenv"
  fi
}

# -----------------------------------------------------------------------------
# sync_skills — clone ou met à jour les skills État.
# -----------------------------------------------------------------------------
sync_skills() {
  if [ -d "$SKILLS_DIR/.git" ]; then
    _ok "skills déjà clonées — mise à jour…"
    if git -C "$SKILLS_DIR" pull --ff-only --quiet 2>/dev/null; then
      _ok "skills à jour"
    else
      _warn "mise à jour des skills impossible (hors ligne ?) — on garde l'existant"
    fi
  else
    _info "Clonage des skills État (etalab-ia/skills)…"
    mkdir -p "$(dirname "$SKILLS_DIR")"
    if git clone --depth 1 --quiet "$SKILLS_REPO" "$SKILLS_DIR" 2>/dev/null; then
      _ok "skills clonées dans $SKILLS_DIR"
    else
      _warn "clonage impossible (hors ligne ?) — OpenCode démarrera sans skills État"
    fi
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

# 2. Synchronisation des skills (fraîches à chaque boot).
sync_skills

# 3. Vérification d'OpenCode.
check_opencode

_ok "Runtime Albert Code prêt. Lance « opencode » pour démarrer."

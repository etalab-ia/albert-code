#!/usr/bin/env bash
# =============================================================================
# Albert Code — wizard d'installation.
# -----------------------------------------------------------------------------
# Deux phases, toutes idempotentes et non-destructives :
#   A. Bootstrap hôte   : agent-vm, clés Albert/Context7, skills, runtime VM.
#   B. Scaffold projet  : copie le profil choisi + opencode.json + runtime.
#
# Usage :
#   ./install.sh                          # depuis le dépôt albert-code (Phase A)
#   ~/Dev/albert-code/install.sh          # depuis un dossier projet (A + B)
#
# Non-destructif : ne réinstalle rien déjà présent, n'écrase aucune config
# existante (globale ou projet). Portée projet pour opencode.json.
# Compatible bash 3.2 (macOS).
# =============================================================================
set -euo pipefail

# --- Localisation du dépôt source (templates) ---------------------------------
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SELF_DIR/lib"
# shellcheck source=lib/ui.sh
source "$LIB_DIR/ui.sh"

ALBERT_CODE_REPO="${ALBERT_CODE_REPO:-$HOME/Dev/albert-code}"
AGENT_VM_DIR="${AGENT_VM_DIR:-$HOME/Dev/agent-vm}"
AGENT_VM_REPO="https://github.com/sylvinus/agent-vm.git"
SKILLS_REPO="https://github.com/etalab-ia/skills.git"
SKILLS_DIR_HOST="$HOME/.config/opencode/skills"
RUNTIME_VM_FILE="$HOME/.agent-vm/runtime.sh"
ZSHENV="$HOME/.zshenv"

# =============================================================================
# Phase A — Bootstrap hôte (idempotent)
# =============================================================================
phase_a() {
  title "Phase A — Bootstrap de ton poste"
  echo

  # A.1 Prérequis OS + Lima
  local os
  os="$(uname -s)"
  case "$os" in
    Darwin) ok "macOS détecté" ;;
    Linux)  ok "Linux détecté" ;;
    *) err "Système non supporté ($os). macOS ou Linux requis." ; exit 1 ;;
  esac

  if ! require_cmd "lima" 2>/dev/null; then
    warn "Lima absent — agent-vm en a besoin pour créer la bulle isolée."
    if confirm "Installer Lima maintenant (via Homebrew) ?"; then
      if ! command -v brew >/dev/null 2>&1; then
        err "Homebrew absent. Installe Lima manuellement : https://lima-vm.io/docs/installation/"
        exit 1
      fi
      brew install lima
    else
      warn "Sans Lima, la bulle isolée ne peut pas démarrer. Installe-le puis relance."
    fi
  fi
  check_cmd "git" || true
  check_cmd "node" || warn "Node.js absent — requis pour npx (MCP). Installe-le."

  echo

  # A.2 Clé Albert API (jamais affichée, jamais dans le dépôt)
  local albert_key=""
  if [ -n "${ALBERT_API_KEY:-}" ]; then
    ok "ALBERT_API_KEY déjà présente dans l'environnement"
    albert_key="$ALBERT_API_KEY"
  elif file_contains "$ZSHENV" "ALBERT_API_KEY"; then
    ok "ALBERT_API_KEY déjà présente dans ~/.zshenv"
    albert_key="<<from-zshenv>>"
  else
    echo
    title "Clé Albert API"
    info "Réservée aux agents publics. Obtiens-la sur https://albert.api.etalab.gouv.fr"
    albert_key="$(prompt_secret "Colle ta clé Albert API (Entrée pour passer)")"
    if [ -z "$albert_key" ]; then
      warn "Pas de clé pour l'instant — tu pourras la configurer plus tard dans ~/.zshenv."
    fi
  fi
  persist_zshenv "ALBERT_API_KEY" "$albert_key"

  # A.3 Clé Context7 (optionnelle)
  local ctx7_key=""
  if [ -n "${CONTEXT7_API_KEY:-}" ]; then
    ok "CONTEXT7_API_KEY déjà présente dans l'environnement"
    ctx7_key="$CONTEXT7_API_KEY"
  elif file_contains "$ZSHENV" "CONTEXT7_API_KEY"; then
    ok "CONTEXT7_API_KEY déjà présente dans ~/.zshenv"
    ctx7_key="<<from-zshenv>>"
  else
    echo
    info "Connecteur context7 (doc des librairies à jour) — clé gratuite : https://context7.com/plans"
    ctx7_key="$(prompt_secret "Clé Context7 (optionnelle, Entrée pour ignorer)")"
  fi
  persist_zshenv "CONTEXT7_API_KEY" "$ctx7_key"

  echo

  # A.4 agent-vm (clone + source dans le shell rc)
  install_agent_vm

  # A.5 Runtime VM (~/.agent-vm/runtime.sh) — exporte les clés dans la VM
  ensure_vm_runtime

  # A.6 Skills État (côté hôte, pour OpenCode hors VM)
  sync_skills_host

  # A.7 OpenCode
  if check_cmd "opencode" 2>/dev/null; then
    :
  else
    warn "OpenCode absent du PATH. Il est préinstallé dans la VM agent-vm."
    info "Hors VM, installe-le : npm i -g opencode-ai"
  fi

  echo
  ok "Phase A terminée — ton poste est prêt."
}

# --- A.4 Installation d'agent-vm (idempotente) --------------------------------
install_agent_vm() {
  if command -v agent-vm >/dev/null 2>&1; then
    ok "agent-vm déjà installé"
    return 0
  fi
  if [ -f "$AGENT_VM_DIR/agent-vm.sh" ]; then
    ok "agent-vm déjà cloné dans $AGENT_VM_DIR"
  else
    info "Clonage d'agent-vm…"
    mkdir -p "$(dirname "$AGENT_VM_DIR")"
    git clone --depth 1 --quiet "$AGENT_VM_REPO" "$AGENT_VM_DIR"
    ok "agent-vm cloné dans $AGENT_VM_DIR"
  fi
  # Sourcing dans le shell rc (idempotent)
  local rc=""
  case "${SHELL##*/}" in
    zsh)  rc="$HOME/.zshrc" ;;
    bash) rc="$HOME/.bashrc" ;;
    *)    rc="$HOME/.profile" ;;
  esac
  touch "$rc"
  if file_contains "$rc" "agent-vm.sh"; then
    ok "agent-vm déjà sourcé dans $rc"
  else
    printf '\n# Albert Code — agent-vm\n[ -f "%s/agent-vm.sh" ] && source "%s/agent-vm.sh"\n' "$AGENT_VM_DIR" "$AGENT_VM_DIR" >> "$rc"
    ok "agent-vm sourcé dans $rc"
    warn "Ouvre un nouveau terminal (ou « source %s ») pour activer agent-vm." "$rc"
  fi
  # Activation pour la session courante
  # shellcheck disable=SC1090
  [ -f "$AGENT_VM_DIR/agent-vm.sh" ] && source "$AGENT_VM_DIR/agent-vm.sh" 2>/dev/null || true
}

# --- A.5 ~/.agent-vm/runtime.sh — exporte les clés dans la VM au démarrage -----
ensure_vm_runtime() {
  mkdir -p "$(dirname "$RUNTIME_VM_FILE")"
  touch "$RUNTIME_VM_FILE"
  info "Configuration du runtime VM (~/.agent-vm/runtime.sh)…"

  # En-tête idempotent
  if ! file_contains "$RUNTIME_VM_FILE" "albert-code"; then
    {
      printf '\n# --- Albert Code : export des clés dans la VM ---\n'
    } >> "$RUNTIME_VM_FILE"
  fi

  # ALBERT_API_KEY
  local albert_val="${ALBERT_API_KEY:-}"
  if [ -z "$albert_val" ] && file_contains "$ZSHENV" "ALBERT_API_KEY"; then
    albert_val="$(grep -E "^export ALBERT_API_KEY=" "$ZSHENV" | head -1 | sed -E "s/^export ALBERT_API_KEY=['\"]?//; s/['\"]?$//")"
  fi
  add_runtime_export "ALBERT_API_KEY" "$albert_val"

  # CONTEXT7_API_KEY
  local ctx7_val="${CONTEXT7_API_KEY:-}"
  if [ -z "$ctx7_val" ] && file_contains "$ZSHENV" "CONTEXT7_API_KEY"; then
    ctx7_val="$(grep -E "^export CONTEXT7_API_KEY=" "$ZSHENV" | head -1 | sed -E "s/^export CONTEXT7_API_KEY=['\"]?//; s/['\"]?$//")"
  fi
  add_runtime_export "CONTEXT7_API_KEY" "$ctx7_val"

  ok "Runtime VM configuré"
}

# add_runtime_export <VAR> <VAL> — ajoute export si absent, additive.
add_runtime_export() {
  local var="$1" val="$2"
  if file_contains "$RUNTIME_VM_FILE" "^export ${var}="; then
    return 0
  fi
  if [ -z "$val" ]; then
    printf 'export %s=""\n' "$var" >> "$RUNTIME_VM_FILE"
  else
    local safe="${val//\'/\'\"\'\"\'}"
    printf "export %s='%s'\n" "$var" "$safe" >> "$RUNTIME_VM_FILE"
  fi
}

# --- A.6 Skills côté hôte ------------------------------------------------------
sync_skills_host() {
  info "Synchronisation des skills État…"
  if [ -d "$SKILLS_DIR_HOST/.git" ]; then
    git -C "$SKILLS_DIR_HOST" pull --ff-only --quiet 2>/dev/null && ok "skills à jour" || warn "maj skills impossible (hors ligne ?)"
  else
    mkdir -p "$(dirname "$SKILLS_DIR_HOST")"
    if git clone --depth 1 --quiet "$SKILLS_REPO" "$SKILLS_DIR_HOST" 2>/dev/null; then
      ok "skills clonées dans $SKILLS_DIR_HOST"
    else
      warn "clonage skills impossible (hors ligne ?)"
    fi
  fi
}

# --- Persistance ~/.zshenv (additive, idempotente) -----------------------------
persist_zshenv() {
  local var="$1" val="$2"
  [ -z "$val" ] && return 0
  [ "$val" = "<<from-zshenv>>" ] && return 0
  touch "$ZSHENV" 2>/dev/null || return 0
  if file_contains "$ZSHENV" "^export ${var}="; then
    ok "$var déjà présente dans ~/.zshenv"
    return 0
  fi
  local safe="${val//\'/\'\"\'\"\'}"
  printf "export %s='%s'\n" "$var" "$safe" >> "$ZSHENV"
  ok "$var ajoutée à ~/.zshenv"
}

# =============================================================================
# Phase B — Scaffold du projet courant (choix du contexte)
# =============================================================================
phase_b() {
  # Si on est dans le dépôt source lui-même, on ne scaffold pas le dépôt.
  if [ "$PWD" = "$SELF_DIR" ]; then
    echo
    info "Tu es dans le dépôt albert-code. Pour scaffold un projet :"
    info "  mkdir -p ~/Dev/mon-projet && cd ~/Dev/mon-projet"
    info "  ~/Dev/albert-code/install.sh"
    return 0
  fi

  title "Phase B — Configuration de ce projet"
  echo

  # B.1 Choix du contexte (obligatoire, pas de défaut)
  local context
  context="$(prompt_choice "Dans quel contexte travailles-tu ?" "beta.gouv" "La Suite" "IAE / Albert" "Autre")"
  echo

  # B.2 Profil AGENTS.md (isolation physique)
  case "$context" in
    "beta.gouv")
      copy_template "profiles/beta.gouv/AGENTS.md" "./AGENTS.md" "profil beta.gouv"
      ;;
    "La Suite")
      copy_template "profiles/lasuite/AGENTS.md" "./AGENTS.md" "profil La Suite"
      ;;
    "IAE / Albert")
      copy_template "profiles/iae/AGENTS.md" "./AGENTS.md" "profil IAE"
      ;;
    "Autre")
      info "Profil « Autre » : aucune convention imposée. Albert Code reste neutre."
      if [ -f "./AGENTS.md" ]; then
        ok "AGENTS.md existant conservé (non écrasé)"
      else
        info "Tu peux fournir ton propre AGENTS.md (ou aucun)."
      fi
      ;;
  esac

  # B.3 opencode.json (portée projet, non-destructif)
  copy_template "config/opencode.template.json" "./opencode.json" "config OpenCode (Albert + MCP + permissions)"

  # B.4 .agent-vm.runtime.sh (runtime de référence)
  copy_template "runtime/agent-vm.runtime.sh" "./.agent-vm.runtime.sh" "runtime VM (sync skills + clés)"
  chmod +x "./.agent-vm.runtime.sh" 2>/dev/null || true

  echo
  ok "Projet configuré pour le contexte « $context »."
  echo
  title "Prochaines étapes"
  info "1. Ouvre la bulle isolée :  agent-vm opencode"
  info "2. Parle en français à l'assistant."
  echo
  info "Au 1er lancement, agent-vm crée la VM (~quelques minutes)."
  info "Les skills se synchronisent automatiquement au démarrage."
}

# copy_template <src relative to SELF_DIR> <dest> <label>
copy_template() {
  local src="$SELF_DIR/$1" dest="$2" label="$3"
  if [ -f "$dest" ]; then
    warn "%s existe déjà — conservé (non écrasé)" "$dest"
  elif [ ! -f "$src" ]; then
    err "Modèle introuvable : $src"
  else
    cp "$src" "$dest"
    ok "%s posé (%s)" "$dest" "$label"
  fi
}

# =============================================================================
# Point d'entrée
# =============================================================================
banner
phase_a
echo
phase_b
echo
title "C'est prêt. Bon code avec Albert."


# copy_template <src relative to SELF_DIR> <dest> <label>

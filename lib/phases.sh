#!/usr/bin/env bash
# =============================================================================
# Albert Code — phases d'installation, sourçables par install.sh ET bin/albert-code.
# -----------------------------------------------------------------------------
# Ce fichier définit les 3 phases :
#   phase_a()  — bootstrap hôte : moteur VM, clés, skills, runtime VM.
#   phase_b()  — scaffold projet : AGENTS.md + opencode.json + runtime + choix skills/MCP.
#   phase_run() — lancement de la VM isolée.
#
# Nécessite que lib/ui.sh ait été sourcé avant (pour apply_*, confirm, etc.).
# Variables requises : SELF_DIR, LIB_DIR, AGENT_VM_DIR, AC_VM_*.
# =============================================================================

# =============================================================================
# Source agent-vm.sh (vendored) — rend la fonction agent-vm() disponible
# en interne pour _vm() sans shim ni PATH user.
# =============================================================================
_agent_vm_sourced=0
if [ -f "$AGENT_VM_DIR/agent-vm.sh" ]; then
  source "$AGENT_VM_DIR/agent-vm.sh" 2>/dev/null && _agent_vm_sourced=1
fi

# _vm : wrapper interne pour appeler agent-vm (setup, opencode, etc.)
# sans dépendre d'un shim sur le PATH. Usage : _vm setup --disk 32
_vm() {
  if [ "$_agent_vm_sourced" -eq 1 ]; then
    # Le vendored (agent-vm.sh) est écrit pour bash récent : sous set -u de
    # bash 3.2 (macOS), l'expansion d'un tableau vide "${arr[@]}" plante en
    # "unbound variable". On l'exécute dans un sous-shell permissif (comme le
    # faisait l'ancien shim), sans toucher au vendored.
    ( set +u +e +o pipefail; agent-vm "$@" )
  else
    err "agent-vm.sh introuvable dans $AGENT_VM_DIR — réinstalle Albert Code."
    return 1
  fi
}

# =============================================================================
# Phase A — Bootstrap hôte (idempotent)
# =============================================================================
phase_a() {
  title "Phase A — Bootstrap de ton poste"
  echo

  # A.1 Pédagogie isolation
  echo
  title "À propos de l'isolation"
  info "Albert Code fait tourner OpenCode dans une VM isolée (moteur Lima) :"
  info "le modèle ne touche qu'à ton code, pas à tes fichiers perso,"
  info "clés SSH, cookies ou sessions navigateur."
  info "Tu peux le laisser tourner en autonomie en toute sécurité."
  info "Ce qu'on va installer :"
  info "  • Lima (moteur de VM)"
  info "  • Le moteur d'isolation d'Albert Code"
  info "  • Une clé Albert API dédiée révocable"
  echo

  # A.2 Prérequis OS + Lima
  local os
  os="$(uname -s)"
  case "$os" in
    Darwin) ok "macOS détecté" ;;
    Linux)  ok "Linux détecté" ;;
    *) err "Système non supporté ($os). macOS ou Linux requis." ; exit 1 ;;
  esac

  if ! require_cmd "lima" 2>/dev/null; then
    warn "Lima absent — le moteur de VM en a besoin pour créer la bulle isolée."
    if confirm "Installer Lima maintenant (via Homebrew) ?"; then
      if ! command -v brew >/dev/null 2>&1; then
        err "Homebrew absent. Installe Lima manuellement : https://lima-vm.io/docs/installation/"
        exit 1
      fi
      apply "installer Lima via Homebrew" brew install lima
    else
      warn "Sans Lima, la bulle isolée ne peut pas démarrer. Installe-le puis relance."
    fi
  fi
  check_cmd "git" || true
  check_cmd "node" || warn "Node.js absent — requis pour npx (MCP). Installe-le."

  echo

  # A.3 Clé Albert API (jamais affichée, jamais dans le dépôt)
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

  # GitHub PAT (optionnel) — gestions des 3 cas : activation, token, dérivation
  _github_auth

  echo

  # A.5 Source le moteur de VM vendored (agent-vm)
  install_agent_vm

  # A.6 Runtime VM (~/.agent-vm/runtime.sh) — exporte les clés dans la VM
  ensure_vm_runtime

  # A.7 Skills État (côté hôte, pour OpenCode hors VM)
  sync_skills_host

  # A.8 OpenCode s'exécute exclusivement dans la VM isolée
  info "OpenCode s'exécute dans la VM isolée — rien à installer sur ton poste."

  # A.9 Ressources VM (détection hôte + garde-fou, lecture seule)
  compute_effective_vm_resources
  check_disk_space_warning

  # A.10 VM de base (préalable obligatoire)
  check_base_vm

  echo
  ok "Phase A terminée — ton poste est prêt."
}

# =============================================================================
# Phase B — Scaffold du projet courant (AGENTS.md + opencode.json + skills/MCP)
# =============================================================================
phase_b() {
  # Si on est dans le dépôt source, on ne scaffold pas.
  if [ "$PWD" = "$SELF_DIR" ]; then
    echo
    info "Tu es dans le dépôt albert-code. Pour scaffold un projet :"
    info "  mkdir -p ~/mon-projet && cd ~/mon-projet"
    info "  albert-code setup"
    return 0
  fi

  banner
  echo
  title "Phase B — Configuration de ce projet"
  echo

  # Variables globales pour le récap
  AC_SELECTED_MCP=""
  AC_SELECTED_SKILLS=""

  # B.1 [1/4] AGENTS.md par défaut (non-destructif)
  title "[1/4] AGENTS.md"
  copy_template "templates/AGENTS.default.md" "./AGENTS.md" "AGENTS.md (règles sécurité + conventions)"
  echo

  # B.2 [2/4] opencode.json avec MCP interactifs (non-destructif)
  title "[2/4] Connecteurs MCP"
  scaffold_opencode_json
  echo

  # B.3 [3/4] Sélection des skills
  title "[3/4] Skills"
  scaffold_skills_selection
  echo

  # B.4 [4/4] Runtime de la VM
  title "[4/4] Runtime VM"
  copy_template "runtime/agent-vm.runtime.sh" "./.agent-vm.runtime.sh" "runtime VM (sync skills + clés)"
  apply "chmod +x .agent-vm.runtime.sh" chmod +x "./.agent-vm.runtime.sh" 2>/dev/null || true
  # Synchroniser les clés potentiellement persistées par le setup (ex. Context7)
  # vers le runtime VM (~/.agent-vm/runtime.sh). ensure_vm_runtime est idempotent :
  # il remplace le bloc marqué sans dupliquer et sans écraser GH_TOKEN / identité git.
  ensure_vm_runtime

  compute_effective_vm_resources
  echo
  if [ -n "${GH_TOKEN:-}" ] || file_contains "$ZSHENV" "GH_TOKEN"; then
    ok "Push et PR GitHub configurés depuis la VM."
  else
    info "Push/PR GitHub non configuré — voir le § Push & PR depuis la VM du README."
  fi
  ok "Projet configuré."
  echo

  # Panneau récap
  print_setup_summary

  print_next_steps
}

# =============================================================================
# phase_run — Lancement de la VM isolée
# =============================================================================
phase_run() {
  title "Albert Code — lancement"
  echo

  # Garde-fou : ce projet doit déclarer le provider Albert dans ./opencode.json,
  # sinon OpenCode s'ouvre sur ses modèles par défaut (Albert absent de /models).
  # Cas observé : `run` lancé dans un dossier jamais `setup`. Détection sur fichier
  # (grep direct sur un fichier, pas de pipe → pas de course SIGPIPE).
  if [ ! -f ./opencode.json ] || ! grep -q '"albert"' ./opencode.json 2>/dev/null; then
    warn "Ce projet n'est pas configuré pour Albert (pas d'opencode.json avec le provider Albert)."
    info "Fais d'abord, dans ce dossier :  albert-code setup"
    info "Sinon OpenCode s'ouvrira sans Albert (modèles par défaut, Albert absent de /models)."
    if ! confirm "Lancer quand même sans Albert ?"; then
      return 1
    fi
  fi

  # Calculer les ressources si pas déjà fait
  compute_effective_vm_resources
  check_disk_space_warning

  # Créer la VM de base si nécessaire
   if ! base_vm_exists; then
    info "Création de la VM de base nécessaire…"
    if confirm "Créer la VM de base maintenant ?"; then
      apply "créer la VM de base (setup VM isolée)" _vm setup --preinstall=node,gh,chromium,opencode --disk "${AC_VM_DISK}" || {
        warn "Création de la VM de base échouée."
        return 1
      }
    else
      warn "VM de base absente."
      return 1
    fi
  fi

  # Lancer la VM (ou rattachement si déjà créée — pas de pipe, cf. post-mortem v1)
  echo
  info "Ouverture de la bulle isolée…"
  info "  Albert Code lance OpenCode dans la VM"
  echo

  local _vm_name _vm_list
  _vm_name="$(_agent_vm_name)"
  # Capture d'abord (aucun pipe → immunisé SIGPIPE/pipefail, cf. T7.6 post-mortem).
  # `|| true` : sortie vide ne casse pas set -e.
  _vm_list="$(limactl list -q 2>/dev/null || true)"
  case $'\n'"$_vm_list"$'\n' in
    *$'\n'"$_vm_name"$'\n'*)
      info "VM déjà créée — rattachement sans re-réglage des ressources."
      apply "lancer la VM isolée" _vm opencode ;;
    *)
      apply "lancer la VM isolée" _vm --cpus "${EFF_CPUS}" --memory "${EFF_MEM}" --disk "${AC_VM_DISK}" opencode ;;
  esac
}

# =============================================================================
# Fonctions helpers (extraites de install.sh ou nouvelles)
# =============================================================================

# check_base_vm — détection et création de la VM de base
check_base_vm() {
  if ! command -v limactl >/dev/null 2>&1; then
    return 0
  fi
  if base_vm_exists; then
    ok "VM de base déjà créée"
    return 0
  fi
  echo
  if confirm "Créer la VM de base maintenant (~plusieurs minutes) ?"; then
    apply "créer la VM de base (setup VM isolée)" _vm setup --preinstall=node,gh,chromium,opencode --disk "${AC_VM_DISK}" || {
      warn "Création de la VM de base échouée — tu pourras la créer plus tard."
    }
  fi
}

# base_vm_exists — 0 si la VM de base existe
# Détection sans pipe : `limactl list -q | grep -q` est un faux négatif
# intermittent sous set -o pipefail (course SIGPIPE, cf. T7.6 post-mortem) —
# grep -q ferme le pipe, limactl prend un SIGPIPE, pipefail fait échouer le tout.
# base_vm_exists est appelé dans phase_run/check_base_vm : un faux négatif
# reproposait la création de la VM de base à chaque run. Capture d'abord, case pur.
base_vm_exists() {
  command -v limactl >/dev/null 2>&1 || return 1
  local _list
  _list="$(limactl list -q 2>/dev/null || true)"
  case $'\n'"$_list"$'\n' in
    *$'\n'agent-vm-base$'\n'*) return 0 ;;
    *) return 1 ;;
  esac
}

# install_agent_vm — vérifie que le bundle vendored est présent (plus de clone).
install_agent_vm() {
  if [ ! -f "$AGENT_VM_DIR/agent-vm.sh" ]; then
    err "agent-vm.sh introuvable dans $AGENT_VM_DIR — le bundle est incomplet."
    exit 1
  fi
  if [ "$_agent_vm_sourced" -eq 0 ]; then
    # Si le source a échoué (bash 3.2) on ressource ici
    source "$AGENT_VM_DIR/agent-vm.sh" 2>/dev/null && _agent_vm_sourced=1
  fi
  if [ "$_agent_vm_sourced" -eq 1 ]; then
    ok "Moteur de VM prêt (vendored dans $AGENT_VM_DIR)"
  else
    err "Échec du chargement du moteur de VM ($AGENT_VM_DIR/agent-vm.sh) — bundle incomplet."
    exit 1
  fi

  # Nettoyage non-destructif : si un ancien shim agent-vm ou un sourçage
  # dans le rc traîne, proposer de les retirer.
  if command -v agent-vm >/dev/null 2>&1; then
    local _vm_real
    _vm_real="$(command -v agent-vm 2>/dev/null)"
    # Si c'est un shim exécutable (pas la fonction shell), proposer le retrait
    if [ -x "$_vm_real" ] && [ -f "$_vm_real" ]; then
      warn "Ancien shim du moteur de VM détecté : $_vm_real"
      if confirm "Retirer l'ancien shim (Albert Code utilise désormais le moteur vendored) ?"; then
        rm -f "$_vm_real"
        ok "Ancien shim retiré"
      fi
    fi
  fi

  # Vérifier les lignes de sourçage dans les rc (installations pré-vendor)
  for _rc_file in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
    [ -f "$_rc_file" ] || continue
    if file_contains "$_rc_file" "agent-vm.sh"; then
      warn "Ancienne ligne de sourçage du moteur de VM trouvée dans $_rc_file"
      if confirm "Retirer la ligne de sourçage obsolète de $_rc_file ?"; then
        _tmp="$(mktemp)"
        grep -v "agent-vm.sh" "$_rc_file" > "$_tmp" || true
        mv "$_tmp" "$_rc_file"
        ok "Ligne retirée de $_rc_file"
      fi
    fi
  done
}

# ensure_vm_runtime — ~/.agent-vm/runtime.sh
ensure_vm_runtime() {
  apply_mkdir "créer $(dirname "$RUNTIME_VM_FILE")" "$(dirname "$RUNTIME_VM_FILE")"
  apply_touch "créer $RUNTIME_VM_FILE si absent" "$RUNTIME_VM_FILE"
  apply_chmod "chmod 600 $RUNTIME_VM_FILE (contient une clé)" 600 "$RUNTIME_VM_FILE"
  info "Configuration du runtime VM (~/.agent-vm/runtime.sh)…"

  local albert_val="${ALBERT_API_KEY:-}"
  if [ -z "$albert_val" ] && file_contains "$ZSHENV" "ALBERT_API_KEY"; then
    albert_val="$(grep -E "^export ALBERT_API_KEY=" "$ZSHENV" | head -1 | sed -E "s/^export ALBERT_API_KEY=['\"]?//; s/['\"]?$//")"
  fi
  local ctx7_val="${CONTEXT7_API_KEY:-}"
  if [ -z "$ctx7_val" ] && file_contains "$ZSHENV" "CONTEXT7_API_KEY"; then
    ctx7_val="$(grep -E "^export CONTEXT7_API_KEY=" "$ZSHENV" | head -1 | sed -E "s/^export CONTEXT7_API_KEY=['\"]?//; s/['\"]?$//")"
  fi
  local gh_token_val="${GH_TOKEN:-}"
  if [ -z "$gh_token_val" ] && file_contains "$ZSHENV" "GH_TOKEN"; then
    gh_token_val="$(grep -E "^export GH_TOKEN=" "$ZSHENV" | head -1 | sed -E "s/^export GH_TOKEN=['\"]?//; s/['\"]?$//")"
  fi
  local git_name_val="${AC_GIT_USER_NAME:-}"
  if [ -z "$git_name_val" ] && file_contains "$ZSHENV" "AC_GIT_USER_NAME"; then
    git_name_val="$(grep -E "^export AC_GIT_USER_NAME=" "$ZSHENV" | head -1 | sed -E "s/^export AC_GIT_USER_NAME=['\"]?//; s/['\"]?$//")"
  fi
  local git_email_val="${AC_GIT_USER_EMAIL:-}"
  if [ -z "$git_email_val" ] && file_contains "$ZSHENV" "AC_GIT_USER_EMAIL"; then
    git_email_val="$(grep -E "^export AC_GIT_USER_EMAIL=" "$ZSHENV" | head -1 | sed -E "s/^export AC_GIT_USER_EMAIL=['\"]?//; s/['\"]?$//")"
  fi

  local safe_albert="" safe_ctx="" safe_gh="" safe_name="" safe_email=""
  [ -n "$albert_val" ] && safe_albert="${albert_val//\'/\'\"\'\"\'}"
  [ -n "$ctx7_val" ] && safe_ctx="${ctx7_val//\'/\'\"\'\"\'}"
  [ -n "$gh_token_val" ] && safe_gh="${gh_token_val//\'/\'\"\'\"\'}"
  [ -n "$git_name_val" ] && safe_name="${git_name_val//\'/\'\"\'\"\'}"
  [ -n "$git_email_val" ] && safe_email="${git_email_val//\'/\'\"\'\"\'}"

  if file_contains "$RUNTIME_VM_FILE" "$AC_MARKER"; then
    _tmp="$(mktemp)"
    if file_contains "$RUNTIME_VM_FILE" "$AC_MARKER_END"; then
      sed -E "\|^${AC_MARKER}$|,\|^${AC_MARKER_END}$|d" "$RUNTIME_VM_FILE" > "$_tmp"
    else
      awk -v marker="$AC_MARKER" '
        $0 == marker { in_block=1; next }
        in_block && $0 ~ /^export (ALBERT_API_KEY|CONTEXT7_API_KEY|GH_TOKEN|AC_GIT_USER_NAME|AC_GIT_USER_EMAIL)=/ { next }
        in_block && $0 ~ /^[[:space:]]*$/ { next }
        in_block { in_block=0 }
        { print }
      ' "$RUNTIME_VM_FILE" > "$_tmp"
    fi
    mv "$_tmp" "$RUNTIME_VM_FILE"
    info "Ancien bloc runtime.sh supprimé (migration ou réécriture)."
  fi

  if ! file_contains "$RUNTIME_VM_FILE" "$AC_MARKER"; then
    apply_append "blank line dans runtime.sh" "$RUNTIME_VM_FILE" ""
    apply_append "albert-code block start" "$RUNTIME_VM_FILE" "$AC_MARKER"
    if [ -n "$albert_val" ]; then
      apply_append "persist ALBERT_API_KEY dans runtime.sh" "$RUNTIME_VM_FILE" \
        "grep -q 'ALBERT_API_KEY' ~/.zshenv 2>/dev/null || echo \"export ALBERT_API_KEY='${safe_albert}'\" >> ~/.zshenv"
      apply_append "export ALBERT_API_KEY dans runtime.sh" "$RUNTIME_VM_FILE" \
        "export ALBERT_API_KEY='${safe_albert}'"
    else
      apply_append "persist ALBERT_API_KEY (vide) dans runtime.sh" "$RUNTIME_VM_FILE" \
        "grep -q 'ALBERT_API_KEY' ~/.zshenv 2>/dev/null || echo \"export ALBERT_API_KEY=''\" >> ~/.zshenv"
      apply_append "export ALBERT_API_KEY (vide) dans runtime.sh" "$RUNTIME_VM_FILE" \
        "export ALBERT_API_KEY=''"
    fi
    if [ -n "$ctx7_val" ]; then
      apply_append "persist CONTEXT7_API_KEY dans runtime.sh" "$RUNTIME_VM_FILE" \
        "grep -q 'CONTEXT7_API_KEY' ~/.zshenv 2>/dev/null || echo \"export CONTEXT7_API_KEY='${safe_ctx}'\" >> ~/.zshenv"
      apply_append "export CONTEXT7_API_KEY dans runtime.sh" "$RUNTIME_VM_FILE" \
        "export CONTEXT7_API_KEY='${safe_ctx}'"
    else
      apply_append "persist CONTEXT7_API_KEY (vide) dans runtime.sh" "$RUNTIME_VM_FILE" \
        "grep -q 'CONTEXT7_API_KEY' ~/.zshenv 2>/dev/null || echo \"export CONTEXT7_API_KEY=''\" >> ~/.zshenv"
      apply_append "export CONTEXT7_API_KEY (vide) dans runtime.sh" "$RUNTIME_VM_FILE" \
        "export CONTEXT7_API_KEY=''"
    fi
    if [ -n "$gh_token_val" ]; then
      apply_append "persist GH_TOKEN dans runtime.sh" "$RUNTIME_VM_FILE" \
        "grep -q 'GH_TOKEN' ~/.zshenv 2>/dev/null || echo \"export GH_TOKEN='${safe_gh}'\" >> ~/.zshenv"
      apply_append "export GH_TOKEN dans runtime.sh" "$RUNTIME_VM_FILE" \
        "export GH_TOKEN='${safe_gh}'"
    fi
    if [ -n "$git_name_val" ]; then
      apply_append "persist AC_GIT_USER_NAME dans runtime.sh" "$RUNTIME_VM_FILE" \
        "grep -q 'AC_GIT_USER_NAME' ~/.zshenv 2>/dev/null || echo \"export AC_GIT_USER_NAME='${safe_name}'\" >> ~/.zshenv"
      apply_append "export AC_GIT_USER_NAME dans runtime.sh" "$RUNTIME_VM_FILE" \
        "export AC_GIT_USER_NAME='${safe_name}'"
    fi
    if [ -n "$git_email_val" ]; then
      apply_append "persist AC_GIT_USER_EMAIL dans runtime.sh" "$RUNTIME_VM_FILE" \
        "grep -q 'AC_GIT_USER_EMAIL' ~/.zshenv 2>/dev/null || echo \"export AC_GIT_USER_EMAIL='${safe_email}'\" >> ~/.zshenv"
      apply_append "export AC_GIT_USER_EMAIL dans runtime.sh" "$RUNTIME_VM_FILE" \
        "export AC_GIT_USER_EMAIL='${safe_email}'"
    fi
    # T8.3: Garde-fou OpenCode --auto execute dans la VM au boot
    # Si opencode est trop ancien pour --auto, upgrade auto.
    apply_append "garde-fou OpenCode --auto (T8.3)" "$RUNTIME_VM_FILE" \
      "  _oc_help=\"\$(opencode --help 2>&1 || true)\""
    apply_append "garde-fou OpenCode --auto (T8.3)" "$RUNTIME_VM_FILE" \
      "  case \"\$_oc_help\" in"
    apply_append "garde-fou OpenCode --auto (T8.3)" "$RUNTIME_VM_FILE" \
      "    *--auto*) : ;;"
    apply_append "garde-fou OpenCode --auto (T8.3)" "$RUNTIME_VM_FILE" \
      "    *) echo \"OpenCode trop ancien pour --auto - mise a jour...\"; opencode upgrade || true ;;"
    apply_append "garde-fou OpenCode --auto (T8.3)" "$RUNTIME_VM_FILE" \
      "  esac"
    apply_append "garde-fou OpenCode --auto (T8.3)" "$RUNTIME_VM_FILE" \
      "  unset _oc_help"
    apply_append "albert-code block end" "$RUNTIME_VM_FILE" "$AC_MARKER_END"
  fi

  ok "Runtime VM configuré"
  [ "$DRY_RUN" -eq 0 ] || true
}

# sync_skills_host — skills côté hôte
sync_skills_host() {
  sync_skills_cached
}

# persist_zshenv — ajout idempotent à ~/.zshenv
persist_zshenv() {
  local var="$1" val="$2"
  [ -z "$val" ] && return 0
  [ "$val" = "<<from-zshenv>>" ] && return 0
  apply_touch "créer $ZSHENV si absent" "$ZSHENV"
  apply_chmod "chmod 600 $ZSHENV (contient une clé)" 600 "$ZSHENV"
  if file_contains "$ZSHENV" "^export ${var}="; then
    ok "$var déjà présente dans ~/.zshenv"
    return 0
  fi
  local safe="${val//\'/\'\"\'\"\'}"
  apply_append "ajouter $var à ~/.zshenv" "$ZSHENV" "export ${var}='${safe}'"
  [ "$DRY_RUN" -eq 0 ] && ok "$var ajoutée à ~/.zshenv" || true
}

# =============================================================================
# _github_auth — config GitHub : activation UNE FOIS, token masqué, retry
# sur prompt_secret uniquement (jamais [o/N]).
# =============================================================================
_github_auth() {
  local gh_token="" git_name="" git_email=""
  local gh_id="" gh_login=""
  local _attempt=0 _max_attempts=3

  # Regex pour détecter un PAT collé (ghp_, github_pat_, gho_, ghs_, ghr_, >30 car.)
  local _pat_regex='^(ghp_|github_pat_|gho_|ghs_|ghr_|.{31,}$)'

  echo
  info "Étape suivante : colle ton PAT GitHub (scope repo) pour activer le push."

  # 1. Activation UNE FOIS — pas dans la boucle
  local _answer=""
  printf '%sActiver le push et les PR GitHub depuis la VM ?%s [o/N] : ' "${C_BOLD}" "${C_RESET}" >&2
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s[dry-run] confirm: Activer le push et les PR GitHub depuis la VM ? → non%s\n' "${C_GREY}" "${C_RESET}" >&2
    _answer="n"
  elif [ -t 0 ]; then
    read -r _answer </dev/tty
  else
    read -r _answer
  fi

  case "$_answer" in
    o|O|y|Y)
      # OK — aller à la boucle token
      ;;
    n|N|"")
      warn "Pas de connexion GitHub — le push/PR depuis la VM restera inactif."
      return 0
      ;;
    *)
      if [[ "$_answer" =~ $_pat_regex ]]; then
        warn "On dirait que tu as collé ton token à la mauvaise étape (réponds d'abord o)."
        warn "Ce token vient d'être affiché en clair dans le terminal : pense à le révoquer"
        warn "et à en régénérer un (github.com/settings/tokens)."
        if confirm "Continuer la connexion GitHub ?"; then
          # Aller directement à la boucle token, ne pas re-demander o/N
          :
        else
          warn "GitHub non connecté."
          return 0
        fi
      else
        # Ni oui, ni non, ni token
        if confirm "Réponse non reconnue. Réessayer ?"; then
          # Re-poser l'activation (appel récursif — une fois max)
          _github_auth
          return $?
        fi
        warn "GitHub non connecté."
        return 0
      fi
      ;;
  esac

  # 2. Boucle token — TOUJOURS via prompt_secret (masqué), jamais de [o/N]
  while [ "$_attempt" -lt "$_max_attempts" ]; do
    local _prompt_msg="Colle ton PAT GitHub (scope repo"
    if [ "$_attempt" -gt 0 ]; then
      _prompt_msg="Recolle ton PAT (tentative $((_attempt+1))/${_max_attempts}"
    fi
    _prompt_msg="${_prompt_msg} ; Entrée pour abandonner)"

    gh_token="$(prompt_secret "$_prompt_msg")"
    if [ -z "$gh_token" ]; then
      warn "Pas de PAT — le push/PR depuis la VM restera inactif."
      return 0
    fi

    # Validation du token via API GitHub
    local _raw="" _http_code=""
    _raw="$(curl -fsS -w "\n%{http_code}" -H "Authorization: Bearer ${gh_token}" -H "Accept: application/vnd.github+json" "https://api.github.com/user" 2>/dev/null)" || _raw=""
    if [ -n "$_raw" ]; then
      _http_code="$(printf '%s' "$_raw" | tail -1)"
      _raw="$(printf '%s' "$_raw" | sed '$d')"
    fi

    if [ "${_http_code:-0}" -ge 200 ] 2>/dev/null && [ "${_http_code:-0}" -lt 300 ] 2>/dev/null && [ -n "$_raw" ]; then
      # Dérivation réussie
      gh_login="$(printf '%s' "$_raw" | sed -n 's/.*"login"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
      gh_id="$(printf '%s' "$_raw" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')"

      if [ -n "$gh_login" ] && [ -n "$gh_id" ]; then
        git_name="$gh_login"
        git_email="${gh_id}+${gh_login}@users.noreply.github.com"
        ok "Compte GitHub : ${gh_login} <${git_email}>"
        persist_zshenv "GH_TOKEN" "$gh_token"
        persist_zshenv "AC_GIT_USER_NAME" "$git_name"
        persist_zshenv "AC_GIT_USER_EMAIL" "$git_email"
        return 0
      fi
      # 2xx mais parsing vide (cas rare) → token valide, persist puis fallback
      persist_zshenv "GH_TOKEN" "$gh_token"
      _github_fallback
      return 0
    fi

    # Échec : token invalide ou API injoignable
    _attempt=$((_attempt + 1))
    if [ "$_attempt" -lt "$_max_attempts" ]; then
      warn "Échec : GitHub non connecté (token invalide ou API injoignable)."
      warn "Tentative $_attempt/${_max_attempts} — recolle ton PAT dans le champ masqué ci-dessous."
      # Rebouble DIRECTEMENT sur prompt_secret (pas de [o/N])
      continue
    fi

    # Tentatives épuisées — fallback sans persister le token non validé
    _github_fallback
    return 0
  done
}

# _github_fallback — prompts manuels nom/email (quand la dérivation API échoue)
_github_fallback() {
  local git_name git_email git_name_def
  git_name_def="$(git config --global user.name 2>/dev/null || true)"
  git_name="$(prompt_input "Nom pour les commits" "${git_name_def:-}")"

  local email_attempts=0
  while [ "$email_attempts" -lt 3 ]; do
    warn "Introuvable automatiquement. Ton email noreply est de la forme <id>+<login>@users.noreply.github.com, visible sur GitHub > Paramètres > Emails (https://github.com/settings/emails)."
    git_email="$(prompt_input "Email noreply GitHub (doit finir en users.noreply.github.com)" "$(git config --global user.email 2>/dev/null || true)")"
    case "$git_email" in
      *users.noreply.github.com) break ;;
    esac
    email_attempts=$((email_attempts + 1))
    if [ "$email_attempts" -lt 3 ]; then
      warn "L'email doit finir par users.noreply.github.com. Réessaie (tentative $email_attempts/3)."
    fi
  done
  if [ "$email_attempts" -ge 3 ]; then
    warn "3 tentatives échouées — on accepte l'email tel quel."
  fi
  persist_zshenv "AC_GIT_USER_NAME" "$git_name"
  persist_zshenv "AC_GIT_USER_EMAIL" "$git_email"
}

# copy_template — copie non-destructive
copy_template() {
  local src="$SELF_DIR/$1" dest="$2" label="$3"
  if [ -f "$dest" ]; then
    warn "%s existe déjà — conservé (non écrasé)" "$dest"
  elif [ ! -f "$src" ]; then
    err "Modèle introuvable : $src"
  else
    apply_cp "poser $dest ($label)" "$src" "$dest"
    ok "%s posé (%s)" "$dest" "$label"
  fi
}

# compute_effective_vm_resources — EFF_CPUS/EFF_MEM
compute_effective_vm_resources() {
  local host_cpus host_ram cap_cpus cap_mem
  host_cpus="$(detect_host_cpus)"
  host_ram="$(detect_host_ram_gib)"

  EFF_CPUS="$AC_VM_CPUS"
  EFF_MEM="$AC_VM_MEMORY"

  if [ -n "$host_cpus" ]; then
    cap_cpus=$(( host_cpus / 2 ))
    [ "$cap_cpus" -lt 1 ] && cap_cpus=1
    [ "$AC_VM_CPUS" -gt "$cap_cpus" ] && EFF_CPUS="$cap_cpus"
  fi

  if [ -n "$host_ram" ]; then
    cap_mem=$(( host_ram / 2 ))
    [ "$cap_mem" -lt 2 ] && cap_mem=2
    [ "$AC_VM_MEMORY" -gt "$cap_mem" ] && EFF_MEM="$cap_mem"
  fi

  if [ -n "$host_cpus" ] || [ -n "$host_ram" ]; then
    info "Ressources hôte détectées : %s CPU / %s GiB RAM." "${host_cpus:-?}" "${host_ram:-?}"
  fi

  if [ "$EFF_CPUS" != "$AC_VM_CPUS" ] || [ "$EFF_MEM" != "$AC_VM_MEMORY" ]; then
    info "Hôte limité (%s CPU / %s GiB) → VM à %s CPU / %s GiB (au lieu de %s CPU / %s GiB demandés)." \
      "${host_cpus:-?}" "${host_ram:-?}" "$EFF_CPUS" "$EFF_MEM" "$AC_VM_CPUS" "$AC_VM_MEMORY"
  fi
}

# detect_host_cpus — nombre de CPU hôte
detect_host_cpus() {
  local n
  if n="$(sysctl -n hw.ncpu 2>/dev/null)" && [ -n "$n" ]; then
    printf '%s' "$n"
  elif n="$(nproc 2>/dev/null)" && [ -n "$n" ]; then
    printf '%s' "$n"
  fi
}

# detect_host_ram_gib — RAM hôte en GiB
detect_host_ram_gib() {
  local bytes kib
  if bytes="$(sysctl -n hw.memsize 2>/dev/null)" && [ -n "$bytes" ]; then
    printf '%s' "$(( bytes / 1073741824 ))"
  elif [ -f /proc/meminfo ] && kib="$(awk '/^MemTotal:/ { print $2; exit }' /proc/meminfo 2>/dev/null)" && [ -n "$kib" ]; then
    printf '%s' "$(( kib / 1024 / 1024 ))"
  fi
}

# check_disk_space_warning — avertit si espace libre insuffisant
check_disk_space_warning() {
  local avail_kib avail_gib
  avail_kib="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
  case "$avail_kib" in
    ''|*[!0-9]*) return 0 ;;
  esac
  avail_gib=$(( avail_kib / 1024 / 1024 ))
  if [ "$avail_gib" -lt "$AC_VM_DISK" ]; then
    warn "Espace disque libre limité (~%s GiB) pour un disque VM de %s GiB (sparse : alloué à l'usage, pas d'un coup)." \
      "$avail_gib" "$AC_VM_DISK"
  fi
}

# scaffold_opencode_json — génère opencode.json avec MCP interactifs
scaffold_opencode_json() {
  local dest="./opencode.json"
  if [ -f "$dest" ]; then
    if grep -q '"albert"' "$dest" 2>/dev/null; then
      warn "%s existe déjà — conservé (non écrasé)" "$dest"
    else
      # T8.2 (generalise T1.6/T7.7) : tenter le merge du provider albert
      if command -v jq >/dev/null 2>&1; then
        warn "%s existe déjà sans provider Albert — proposition de merge." "$dest"
        info "Le provider Albert (et model/small_model) peuvent etre ajoutes sans ecraser"
        info "tes MCP, permissions ou autres providers (ex. Scaleway)."
        if confirm "Ajouter le provider Albert dans opencode.json ?"; then
          local _bak="${dest}.bak"
          apply_cp "sauvegarder ${dest} vers ${_bak}" "$dest" "$_bak"
          if [ "$DRY_RUN" -eq 1 ]; then
            info "[dry-run] merge du provider albert dans ${dest}"
          # jq : ajoute provider.albert + model + small_model, preserve le reste.
          # Le message de succes n'est affiche que si le merge a reellement abouti.
          elif jq '.provider.albert = {
              "npm": "@ai-sdk/openai-compatible",
              "name": "Albert API (État)",
              "options": {"baseURL": "https://albert.api.etalab.gouv.fr/v1", "apiKey": "{env:ALBERT_API_KEY}"},
              "models": {
                "mistralai/Mistral-Medium-3.5-128B": {"name": "Mistral Medium 3.5 (Albert)", "limit": {"context": 131072, "output": 65536}},
                "deepseek-ai/DeepSeek-V4-Flash": {"name": "DeepSeek V4 Flash (Albert)", "limit": {"context": 393216, "output": 65536}},
                "Qwen/Qwen3.6-27B": {"name": "Qwen 3.6 27B (Albert)", "limit": {"context": 262144, "output": 65536}}
              }
            } | .model = "albert/mistralai/Mistral-Medium-3.5-128B" | .small_model = "albert/deepseek-ai/DeepSeek-V4-Flash"' "$dest" > "${dest}.tmp" 2>/dev/null && mv "${dest}.tmp" "$dest"; then
            ok "Provider Albert ajoute dans ${dest}. Sauvegarde dans ${_bak}"
          else
            warn "Echec du merge jq (JSON invalide ? ex. commentaires) - fichier restaure, Albert non cable."
            mv "$_bak" "$dest" 2>/dev/null || true
            info "Ajoute le bloc provider \"albert\" manuellement (voir README)."
          fi
        else
          info "Provider Albert non ajoute. Utilise albert-code setup plus tard ou ajoute-le manuellement."
        fi
      else
        # Fallback T7.7 : jq absent, simple avertissement
        warn "%s existe déjà mais ne déclare pas le provider Albert — conservé (non écrasé)." "$dest"
        info "Albert ne sera pas câblé dans ce projet. Ajoute le bloc provider \"albert\" (voir README), ou renomme/supprime ce fichier puis relance albert-code setup."
        info "Astuce : installe jq pour que albert-code puisse merger automatiquement."
      fi
    fi
    return 0
  fi

  info "Choix des connecteurs MCP — chaque brique est optionnelle."
  echo

  local mcp_data_gouv="false" mcp_ctx7="false" mcp_playwright="false" mcp_chrome="false"

  info "MCP qui permet à l'agent d'interroger les données publiques de"
  info "data.gouv.fr (catalogue, datasets, API tabulaire), en lecture."
  if confirm "Installer le connecteur data.gouv ?"; then
    mcp_data_gouv="true"
  fi
  echo
  info "MCP qui donne à l'agent la documentation à jour des librairies"
  info "et frameworks pendant qu'il code. Clé gratuite (https://context7.com/plans),"
  info "demandée juste après si tu acceptes."
  if confirm "Installer le connecteur Context7 ?"; then
    mcp_ctx7="true"
  fi
  echo
  info "MCP qui permet à l'agent de piloter un navigateur headless dans"
  info "la VM (ouvrir une page, cliquer, tester une UI)."
  if confirm "Installer le connecteur Playwright ?"; then
    mcp_playwright="true"
  fi
  echo
  info "MCP de debug navigateur : DOM, console, requêtes réseau, performance."
  if confirm "Installer le connecteur Chrome DevTools ?"; then
    mcp_chrome="true"
  fi

  local content='{'
  content=$content'"$schema":"https://opencode.ai/config.json",'
  content=$content'"provider":{"albert":{"npm":"@ai-sdk/openai-compatible","name":"Albert API (État)","options":{"baseURL":"https://albert.api.etalab.gouv.fr/v1","apiKey":"{env:ALBERT_API_KEY}"},"models":{"mistralai/Mistral-Medium-3.5-128B":{"name":"Mistral Medium 3.5 (Albert)","limit":{"context":131072,"output":65536}},"deepseek-ai/DeepSeek-V4-Flash":{"name":"DeepSeek V4 Flash (Albert)","limit":{"context":393216,"output":65536}},"Qwen/Qwen3.6-27B":{"name":"Qwen 3.6 27B (Albert)","limit":{"context":262144,"output":65536}}}}},'
  content=$content'"model":"albert/mistralai/Mistral-Medium-3.5-128B",'
  content=$content'"small_model":"albert/deepseek-ai/DeepSeek-V4-Flash",'
  content=$content'"mcp":{'

  local first=true
  if [ "$mcp_data_gouv" = "true" ]; then
    [ "$first" = false ] && content=$content','
    first=false
    content=$content'"data-gouv":{"type":"remote","url":"https://mcp.data.gouv.fr/mcp","enabled":true}'
  fi
  if [ "$mcp_ctx7" = "true" ]; then
    [ "$first" = false ] && content=$content','
    first=false
    content=$content'"context7":{"type":"remote","url":"https://mcp.context7.com/mcp","enabled":true,"headers":{"Authorization":"Bearer {env:CONTEXT7_API_KEY}"}}'
    if [ -z "${CONTEXT7_API_KEY:-}" ] && ! file_contains "$ZSHENV" "CONTEXT7_API_KEY"; then
      local _ctx7_key
      _ctx7_key="$(prompt_secret "Colle ta clé API Context7 (https://context7.com/plans) — Entrée pour passer")"
      if [ -n "$_ctx7_key" ]; then
        persist_zshenv "CONTEXT7_API_KEY" "$_ctx7_key"
      else
        warn "Pas de clé Context7 — le MCP context7 s'affichera en erreur sans clé."
      fi
    fi
  fi
  if [ "$mcp_playwright" = "true" ]; then
    [ "$first" = false ] && content=$content','
    first=false
    content=$content'"playwright":{"type":"local","command":["npx","-y","@playwright/mcp@latest"],"enabled":true}'
  fi
  if [ "$mcp_chrome" = "true" ]; then
    [ "$first" = false ] && content=$content','
    first=false
    content=$content'"chrome-devtools":{"type":"local","command":["npx","-y","chrome-devtools-mcp@latest","--headless=true","--isolated=true"],"enabled":true}'
  fi

  content=$content'},'
  content=$content'"permission":{"edit":"allow","bash":{".*":"allow","git push.*(--force|-f | --force-with-lease)":"deny","sudo .*":"deny"},"webfetch":"allow","websearch":"allow","skill":"allow","task":"allow"}'
  content=$content'}'

  apply_write "générer opencode.json (provider Albert + MCP sélectionnés)" "$dest" "$content"
  ok "%s posé" "$dest"

  # Exposer la liste des MCP actives pour le récap
  local _mcp_list=""
  local selected_mcp=0
  if [ "$mcp_data_gouv" = "true" ]; then
    _mcp_list="${_mcp_list:+$_mcp_list, }data.gouv"
    selected_mcp=$((selected_mcp + 1))
  fi
  if [ "$mcp_ctx7" = "true" ]; then
    _mcp_list="${_mcp_list:+$_mcp_list, }context7"
    selected_mcp=$((selected_mcp + 1))
  fi
  if [ "$mcp_playwright" = "true" ]; then
    _mcp_list="${_mcp_list:+$_mcp_list, }playwright"
    selected_mcp=$((selected_mcp + 1))
  fi
  if [ "$mcp_chrome" = "true" ]; then
    _mcp_list="${_mcp_list:+$_mcp_list, }chrome-devtools"
    selected_mcp=$((selected_mcp + 1))
  fi
  AC_SELECTED_MCP="$_mcp_list"

  echo
  ok "%d MCP sélectionnés" "$selected_mcp"
}

# extract_skill_description <path/SKILL.md> : extrait la description YAML d'un SKILL.md.
# Gère inline : `description: texte`, `description: "texte"`,
# et block scalar : `description: >-`/`>/`|-`/`|` avec lignes indentées suivantes.
# Tronque à ~200 caractères + « … ». Bash 3.2, pas de jq/yq.
extract_skill_description() {
  local file="$1" line="" after="" val=""
  local -a lines=()
  while IFS= read -r line; do
    lines[${#lines[@]}]="$line"
  done < "$file"

  local idx=0 len="${#lines[@]}"
  while [ "$idx" -lt "$len" ]; do
    line="${lines[$idx]}"
    case "$line" in
      description:*)
        after="${line#description:}"
        case "$after" in ' '*) after="${after# }" ;; esac
        case "$after" in
          '"'*)
            val="${after#\"}"
            val="${val%\"}"
            ;;
          '>'*)
            val=""
            idx=$((idx + 1))
            while [ "$idx" -lt "$len" ]; do
              line="${lines[$idx]}"
              case "$line" in
                '---'|'') break ;;
                '#'*) break ;;
                [a-zA-Z_]*:*) break ;;
                ' '*|$'\t'*) val="${val} ${line}" ;;
                *) break ;;
              esac
              idx=$((idx + 1))
            done
            val="$(printf '%s' "$val" | sed 's/^ *//;s/ *$//' | tr -s ' ')"
            ;;
          '|'*)
            val=""
            idx=$((idx + 1))
            while [ "$idx" -lt "$len" ]; do
              line="${lines[$idx]}"
              case "$line" in
                '---'|'') break ;;
                '#'*) break ;;
                [a-zA-Z_]*:*) break ;;
                ' '*|$'\t'*) val="${val} ${line}" ;;
                *) break ;;
              esac
              idx=$((idx + 1))
            done
            val="$(printf '%s' "$val" | sed 's/^ *//;s/ *$//' | tr -s ' ')"
            ;;
          *)
            val="$after"
            case "$val" in
              '"'*) val="${val#\"}"; val="${val%\"}" ;;
            esac
            ;;
        esac
        break
        ;;
    esac
    idx=$((idx + 1))
  done

  [ -z "${val:-}" ] && { printf ''; return 0; }

  if [ "${#val}" -gt 200 ]; then
    val="$(printf '%s' "$val" | head -c 197)…"
  fi
  printf '%s' "$val"
}

# scaffold_skills_selection — choix interactif des skills
scaffold_skills_selection() {
  local skills_dir="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/.albert-skills-cache"
  local manifest_dir="./.albert-code"

  # Rafraîchir le cache
  if [ -d "$skills_dir/.git" ]; then
    with_spinner "Mise à jour du cache skills" git -C "$skills_dir" pull --ff-only --quiet || true
  else
    apply_mkdir "créer $skills_dir" "$skills_dir"
    with_spinner "Clonage du cache skills" git clone --depth 1 --quiet "https://github.com/etalab-ia/skills.git" "$skills_dir" 2>/dev/null || true
  fi

  apply_mkdir "créer $manifest_dir" "$manifest_dir"

  local selected=""
  local count=0
  local _skill_list=""

  if [ -d "$skills_dir/skills" ]; then
    for _skill_dir in "$skills_dir/skills"/*/; do
      [ -d "$_skill_dir" ] || continue
      local name="$(basename "$_skill_dir")"
      case "$name" in .*|.experimental|.git) continue ;; esac

      local desc=""
      if [ -f "$_skill_dir/SKILL.md" ]; then
        desc="$(extract_skill_description "$_skill_dir/SKILL.md")"
      fi
      [ -z "$desc" ] && desc="(aucune description)"

      if confirm "Installer la skill « ${name} » (${desc}) ?"; then
        selected="${selected}${name}"$'\n'
        _skill_list="${_skill_list:+$_skill_list, }${name}"
        count=$((count + 1))
      fi
    done
  fi

  # Exposer la liste des skills pour le récap
  AC_SELECTED_SKILLS="$_skill_list"

  if [ "$DRY_RUN" -eq 0 ] || [ -n "$selected" ]; then
    apply_write "écrire .albert-code/skills.txt" "$manifest_dir/skills.txt" "$selected"
  fi

  [ "$DRY_RUN" -eq 0 ] && ok "%d skills sélectionnées" "$count" || true
}

# print_setup_summary — panneau récap en fin de setup
print_setup_summary() {
  local _proj
  _proj="$(basename "$PWD")"

  local _mcp_display="${AC_SELECTED_MCP:-}"
  [ -z "$_mcp_display" ] && _mcp_display="aucun (mode souverain)"

  local _skills_display="${AC_SELECTED_SKILLS:-}"
  [ -z "$_skills_display" ] && _skills_display="aucune"

  local _gh_display=""
  if [ -n "${GH_TOKEN:-}" ] || file_contains "$ZSHENV" "GH_TOKEN"; then
    _gh_display="push + PR activés"
  else
    _gh_display="non configuré"
  fi

  echo "  -------------------------------------------------------"
  echo "   Récapitulatif du projet"
  echo "  -------------------------------------------------------"
  echo "   Projet   : $_proj"
  echo "   MCP      : $_mcp_display"
  echo "   Skills   : $_skills_display"
  echo "   GitHub   : $_gh_display"
  echo "  -------------------------------------------------------"
  echo
}

# print_next_steps — affiche les prochaines étapes
print_next_steps() {
  title "Prochaines étapes"
  info "Lancer Albert Code : albert-code run"
  printf '  NB : Les skills sélectionnées se synchronisent automatiquement au démarrage\n'
}

#!/usr/bin/env bash
# Albert Code — fonctions bash partagées (UI, couleurs, vérifications).
# Source ce fichier : `source "$(dirname "$0")/lib/ui.sh"`.
# Compatible bash 3.2 (macOS). Ne pas exécuter directement.

# --- Couleurs (désactivées si pas de TTY) -------------------------------------
if [ -t 1 ]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_CYAN=$'\033[36m'
  C_GREY=$'\033[90m'
else
  C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""; C_GREY=""
fi

# --- Dry-run + sandbox ---------------------------------------------------------
# DRY_RUN=1          : chaque mutation est loggée [dry-run] mais PAS exécutée.
# OPENCODE_CONFIG_DIR : override ~/.config/opencode (sandbox test).
# HOME               : override → redirige ~/.zshenv etc. vers un dossier jetable.
# SHIM_BIN_DIR       : override → dossier du shim agent-vm (install_shim), au lieu
#                       de sonder /opt/homebrew/bin, /usr/local/bin puis $PATH.
DRY_RUN="${DRY_RUN:-0}"
OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"

# Marqueur unique pour les blocs Albert Code dans les fichiers de l'utilisateur.
# Utilisé à l'écriture (install.sh) ET aux tests (install.sh idempotence, uninstall.sh retrait).
# Début et FIN pour ne supprimer QUE le bloc, jamais les lignes hors plage.
AC_MARKER="# --- albert-code : clés VM ---"
AC_MARKER_END="# --- /albert-code ---"

# _dry_gate <description> : LE point d'entrée unique pour toute mutation.
# Retourne 0 si l'action doit s'exécuter, 1 si dry-run l'a skip (déjà loggé).
# Règle : AUCUNE écriture (fichier, clone, install, append) ne peut contourner _dry_gate.
_dry_gate() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s[dry-run] %s%s\n' "${C_GREY}" "$1" "${C_RESET}"
    return 1
  fi
  return 0
}

# apply <desc> <cmd...>          — exécute une commande (git clone, brew, chmod…).
apply()        { local desc="$1"; shift; _dry_gate "$desc" || return 0; "$@"; }
# apply_append <desc> <file> <line> — ajoute une ligne à un fichier.
apply_append() { local desc="$1" file="$2" line="$3"; _dry_gate "$desc" || return 0; printf '%s\n' "$line" >> "$file"; }
# apply_write <desc> <file> <content> — écrit (écrase) un fichier.
apply_write()  { local desc="$1" file="$2" content="$3"; _dry_gate "$desc" || return 0; printf '%s' "$content" > "$file"; }
# apply_cp <desc> <src> <dest>  — copie un fichier.
apply_cp()     { local desc="$1" src="$2" dest="$3"; _dry_gate "$desc" || return 0; cp "$src" "$dest"; }
# apply_mkdir <desc> <dir>      — crée un dossier (-p).
apply_mkdir()  { local desc="$1" dir="$2"; _dry_gate "$desc" || return 0; mkdir -p "$dir"; }
# apply_touch <desc> <file>     — touch un fichier.
apply_touch()  { local desc="$1" file="$2"; _dry_gate "$desc" || return 0; touch "$file" 2>/dev/null || true; }
# apply_chmod <desc> <mode> <file> — change les permissions d'un fichier.
apply_chmod()  { local desc="$1" mode="$2" file="$3"; _dry_gate "$desc" || return 0; chmod "$mode" "$file" 2>/dev/null || true; }
# apply_symlink <desc> <target> <link> — crée un lien symbolique (ne remplace pas un fichier/répertoire existant).
apply_symlink() { local desc="$1" target="$2" link="$3"; _dry_gate "$desc" || return 0; ln -sf "$target" "$link" 2>/dev/null || true; }

# install_shim <name> <source_script> : crée un shim exécutable sur le PATH
# pour une commande qui est en réalité une fonction shell définie par source.
# Cherche un dossier writable dans $PATH dans cet ordre :
#   /opt/homebrew/bin (Apple Silicon), /usr/local/bin, ~/.local/bin
# Si seulement ~/.local/bin est trouvé, l'ajoute à ~/.zshenv si absent.
# Retourne 0 si le shim est posé, 1 si aucun dossier writable trouvé (avertit).
# Variables lues : DRY_RUN (pour _dry_gate), SHIM_BIN_DIR (override test/CI :
#   si défini et non vide, utilisé directement comme dossier du shim,
#   sans sonder /opt/homebrew/bin, /usr/local/bin ni $PATH — cf. HOME,
#   OPENCODE_CONFIG_DIR pour le même usage de sandboxing).
SHIM_PATH_ADDED="${SHIM_PATH_ADDED:-0}"
install_shim() {
  local name="$1" source_script="$2"
  local shim_dir="" _dir="" _old_ifs=""

  if [ -n "${SHIM_BIN_DIR:-}" ]; then
    # Override explicite (tests/CI) : court-circuite la sonde PATH.
    shim_dir="$SHIM_BIN_DIR"
    if [ ! -d "$shim_dir" ]; then
      apply_mkdir "créer $shim_dir" "$shim_dir"
    fi
  else
    # 1. Trouver le premier dossier dans $PATH qui est writable
    _old_ifs="$IFS"
    IFS=':'
    for _dir in /opt/homebrew/bin /usr/local/bin $PATH; do
      [ -z "$_dir" ] && continue
      if [ -d "$_dir" ] && [ -w "$_dir" ]; then
        shim_dir="$_dir"
        break
      fi
    done
    IFS="$_old_ifs"

    # 2. Si rien trouvé, utiliser ~/.local/bin
    if [ -z "$shim_dir" ]; then
      shim_dir="$HOME/.local/bin"
      if [ ! -d "$shim_dir" ]; then
        apply_mkdir "créer $shim_dir" "$shim_dir"
      fi
      # Ajouter au PATH via ~/.zshenv si pas déjà
      if ! file_contains "$HOME/.zshenv" "\.local/bin"; then
        apply_append "ajouter ~/.local/bin au PATH dans ~/.zshenv" "$HOME/.zshenv" \
          "export PATH=\"\$HOME/.local/bin:\$PATH\""
        SHIM_PATH_ADDED=1
      fi
    fi
  fi

  shim_path="$shim_dir/$name"

  # -- Mode : fonction shell (source) ou script exécutable (exec) ------------
  local shim_content=""
  if [ -x "$source_script" ] && head -1 "$source_script" 2>/dev/null | grep -q '^#!'; then
    # Script exécutable autonome : simple exec, préserve stdin/stdout/stderr
    local abs_source="$source_script"
    case "$abs_source" in
      /*) ;; # déjà absolu
      *) abs_source="$(cd "$(dirname "$source_script")" && pwd)/$(basename "$source_script")" ;;
    esac
    shim_content="#!/usr/bin/env bash
# Shim pour $name (script exécutable, généré par Albert Code)
exec \"${abs_source}\" \"\$@\""
  else
    # Fonction shell définie par source
    shim_content="#!/usr/bin/env bash
# Shim pour $name (généré par Albert Code)
source \"$source_script\" 2>/dev/null || true
$name \"\$@\""
  fi

  if [ -f "$shim_path" ]; then
    local _existing
    _existing="$(head -3 "$shim_path" 2>/dev/null || true)"
    if [ "$_existing" = "$(printf '%s' "$shim_content" | head -3)" ]; then
      ok "shim $name déjà présent et à jour dans $shim_path"
      return 0
    fi
  fi
  apply_write "créer le shim $name dans $shim_path" "$shim_path" "$shim_content"
  apply_chmod "chmod +x 755 $shim_path" 755 "$shim_path"
  [ "$DRY_RUN" -eq 0 ] && ok "shim $name installé dans $shim_path"
  return 0
}

# remove_shim <name> : supprime un shim du PATH.
remove_shim() {
  local name="$1" _dir="" _old_ifs=""
  _old_ifs="$IFS"
  IFS=':'
  for _dir in $PATH; do
    [ -z "$_dir" ] && continue
    local shim_path="$_dir/$name"
    if [ -f "$shim_path" ] && [ -x "$shim_path" ]; then
      # Vérifie que c'est bien notre shim (contient la signature)
      if head -3 "$shim_path" 2>/dev/null | grep -q "Shim pour $name"; then
        rm -f "$shim_path"
        IFS="$_old_ifs"
        ok "shim $name retiré de $shim_path"
        return 0
      fi
    fi
  done
  IFS="$_old_ifs"
  warn "aucun shim $name trouvé sur le PATH"
  return 1
}

# --- Skills État (cache + symlinks) -------------------------------------------
# SKILLS_CACHE : dépôt git cloné de etalab-ia/skills (vrai .git, updatable).
# Les skills sont symlinkées dans OPENCODE_CONFIG_DIR/skills/<nom> → cache/skills/<nom>.
# Collisions : un dossier perso existant dans skills/ n'est jamais écrasé.
SKILLS_REPO="https://github.com/etalab-ia/skills.git"
SKILLS_CACHE="$OPENCODE_CONFIG_DIR/.albert-skills-cache"
SKILLS_TARGET="$OPENCODE_CONFIG_DIR/skills"

# sync_skills_cached : canonical implementation — used by install.sh AND documented
# for runtime/agent-vm.runtime.sh.
sync_skills_cached() {
  info "Synchronisation des skills État…"

  # 1. Clone ou pull le cache
  if [ -d "$SKILLS_CACHE/.git" ]; then
    apply "maj cache skills (git pull)" git -C "$SKILLS_CACHE" pull --ff-only --quiet 2>/dev/null || true
    [ "$DRY_RUN" -eq 0 ] && ok "cache skills à jour" || true
  else
    apply_mkdir "créer $SKILLS_CACHE" "$(dirname "$SKILLS_CACHE")"
    apply "cloner skills État dans $SKILLS_CACHE" git clone --depth 1 --quiet "$SKILLS_REPO" "$SKILLS_CACHE" 2>/dev/null
    if [ "$DRY_RUN" -eq 0 ] && [ -d "$SKILLS_CACHE/.git" ]; then
      ok "cache skills cloné dans $SKILLS_CACHE"
    fi
  fi

  # 2. Symlink chaque skill du cache vers le dossier skills (sans collision)
  apply_mkdir "créer $SKILLS_TARGET" "$SKILLS_TARGET"
  if [ -d "$SKILLS_CACHE/skills" ]; then
    local linked=0 skipped=0
    for _skill_entry in "$SKILLS_CACHE/skills"/*/; do
      [ -d "$_skill_entry" ] || continue
      local name
      name="$(basename "$_skill_entry")"
      # Ignorer les dossiers cachés/expérimentaux
      case "$name" in .*|.experimental|.git) continue ;; esac
      local link_path="$SKILLS_TARGET/$name"
      if [ -e "$link_path" ] && [ ! -L "$link_path" ]; then
        # Collision : fichier/répertoire perso existe déjà — skip
        [ "$DRY_RUN" -eq 0 ] && warn "skill « %s » déjà présente (perso) — conservée" "$name" || true
        skipped=$((skipped + 1))
      else
        apply_symlink "symlink $name" "$_skill_entry" "$link_path"
        linked=$((linked + 1))
      fi
    done
    [ "$DRY_RUN" -eq 0 ] && ok "%d skills liées, %d ignorées (existantes)" "$linked" "$skipped" || true
  fi
}

# --- Messages ------------------------------------------------------------------
# Une action = un retour. Tutoiement, français.
# Acceptent le formatage printf : ok "%s fait" "$x"  OU  ok "message simple".
_fmt() { if [ "$#" -gt 1 ]; then printf "$@"; else printf '%s' "$1"; fi; }
info()  { printf '%s→ %s%s\n'  "${C_BLUE}"   "$(_fmt "$@")" "${C_RESET}"; }
ok()    { printf '%s✓ %s%s\n'  "${C_GREEN}"  "$(_fmt "$@")" "${C_RESET}"; }
warn()  { printf '%s! %s%s\n'  "${C_YELLOW}" "$(_fmt "$@")" "${C_RESET}"; }
err()   { printf '%s✗ %s%s\n'  "${C_RED}"    "$(_fmt "$@")" "${C_RESET}" >&2; }
title() { printf '%s%s%s\n'    "${C_BOLD}"   "$(_fmt "$@")" "${C_RESET}"; }

# --- Bannière ------------------------------------------------------------------
banner() {
  cat <<'BANNER'
    _    _ _               _      ____          _
   / \  | | |__   ___ _ __| |_   / ___|___   __| | ___
  / _ \ | | '_ \ / _ \ '__| __| | |   / _ \ / _` |/ _ \
 / ___ \| | |_) |  __/ |  | |_  | |__| (_) | (_| |  __/
/_/   \_\_|_.__/ \___|_|   \__|  \____\___/ \__,_|\___|
BANNER
  printf '%s%s%s\n\n' "${C_CYAN}" "Coder avec l'IA souveraine de l'État, dans une bulle isolée." "${C_RESET}"
}

# --- Vérifications -------------------------------------------------------------
# check_cmd <nom> : 0 si présent, 1 sinon (affiche un avertissement).
check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd présent ($(command -v "$cmd"))"
    return 0
  else
    warn "$cmd absent du PATH"
    return 1
  fi
}

# require_cmd <nom> : stoppe le script si absent.
require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "Dépendance requise manquante : « $cmd ». Installe-la puis relance."
    return 1
  fi
}

# --- Prompts -------------------------------------------------------------------
# prompt_choice <question> <choix...> : affiche un menu numéroté, renvoie le choix.
# ATTENTION : TOUT l'affichage humain (menu, ✓, erreurs) va sur STDERR (>2).
# Seule la VALEUR finale va sur STDOUT — compatible $(...) capture.
# Ex : prompt_choice "Quel contexte ?" "beta.gouv" "La Suite" "IAE" "Autre"
prompt_choice() {
  local question="$1"; shift
  local choices=("$@")
  local n choice
  if [ "$DRY_RUN" -eq 1 ]; then
    choice="${choices[0]}"
    printf '%s[dry-run] prompt: %s → %s%s\n' "${C_GREY}" "$question" "$choice" "${C_RESET}" >&2
    printf '%s' "$choice"
    return 0
  fi
  while true; do
    title "$question" >&2
    for i in "${!choices[@]}"; do
      printf '  %s%d)%s %s\n' "${C_CYAN}" "$((i+1))" "${C_RESET}" "${choices[$i]}" >&2
    done
    printf '%s→ %s' "${C_BOLD}" "${C_RESET}" >&2
    if [ -t 0 ]; then
      read -r n </dev/tty
    else
      read -r n
    fi
    if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#choices[@]}" ]; then
      choice="${choices[$((n-1))]}"
      printf '%s✓ %s choisi%s\n' "${C_GREEN}" "$choice" "${C_RESET}" >&2
      printf '%s' "$choice"
      return 0
    fi
    warn "Choix invalide, réessaie." >&2
  done
}

# prompt_secret <question> : lit une valeur masquée, renvoie via stdout.
prompt_secret() {
  local question="$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s[dry-run] prompt: %s (ignoré)\n' "${C_GREY}" "$question" "${C_RESET}" >&2
    printf ''
    return 0
  fi
  printf '%s%s%s : ' "${C_BOLD}" "$question" "${C_RESET}" >&2
  stty -echo 2>/dev/null || true
  local val
  if [ -t 0 ]; then
    read -r val </dev/tty
  else
    read -r val
  fi
  stty echo 2>/dev/null || true
  printf '\n' >&2
  printf '%s' "$val"
}

# prompt_input <question> [défaut] : lit une valeur en clair, renvoie via stdout.
prompt_input() {
  local question="$1"
  local default="${2:-}"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s[dry-run] prompt: %s → %s%s\n' "${C_GREY}" "$question" "${default:-<vide>}" "${C_RESET}" >&2
    printf '%s' "$default"
    return 0
  fi
  if [ -n "$default" ]; then
    printf '%s%s%s [%s] : ' "${C_BOLD}" "$question" "${C_RESET}" "$default" >&2
  else
    printf '%s%s%s : ' "${C_BOLD}" "$question" "${C_RESET}" >&2
  fi
  local val
  if [ -t 0 ]; then
    read -r val </dev/tty
  else
    read -r val
  fi
  printf '%s' "${val:-$default}"
}

# confirm <question> : 0 si oui, 1 si non. Écrit le prompt sur >&2.
confirm() {
  local question="$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s[dry-run] confirm: %s → non%s\n' "${C_GREY}" "$question" "${C_RESET}" >&2
    return 1
  fi
  local answer
  printf '%s%s%s [o/N] : ' "${C_BOLD}" "$question" "${C_RESET}" >&2
  if [ -t 0 ]; then
    read -r answer </dev/tty
  else
    read -r answer
  fi
  [[ "$answer" =~ ^[oOyY] ]]
}

# file_contains <fichier> <pattern> : 0 si le pattern est présent.
file_contains() {
  grep -q -- "$2" "$1" 2>/dev/null
}

# --- Usage / help --------------------------------------------------------------
# usage_install : texte d'aide pour install.sh (rétrocompat).
usage_install() {
  cat <<'USAGE'
Albert Code — installation (version legacy)

Usage: ./install.sh [--dry-run] [--help]

Ce script amorce ton poste (Phase A) puis pose le shim « albert-code ».
Après installation, utilise :

  albert-code setup     → configurer un projet (Phase B)
  albert-code run       → lancer la bulle agent-vm

Options :
  --dry-run   Affiche chaque action sans l'exécuter. Aucun fichier n'est écrit.
  --help      Affiche cette aide.

Variables d'environnement (sandbox) :
  HOME                   Redirige ~/.zshenv, ~/.config/opencode, etc.
  OPENCODE_CONFIG_DIR     Dossier de config OpenCode (défaut: ~/.config/opencode).
  AGENT_VM_DIR            Dossier d'installation d'agent-vm (défaut: \${XDG_DATA_HOME:-~/.local/share}/agent-vm).
  SHIM_BIN_DIR            Dossier du shim agent-vm (défaut: sonde /opt/homebrew/bin,
                          /usr/local/bin puis \$PATH, sinon ~/.local/bin).

Ressources VM (surchargeables) :
  AC_VM_CPUS              CPU alloués à la VM (défaut: 4).
  AC_VM_MEMORY             RAM en GiB allouée à la VM (défaut: 8).
  AC_VM_DISK               Disque en GiB de la VM, fixé au 1er `agent-vm setup`,
                          ne peut que grandir ensuite (défaut: 32).
                          Garde-fou : CPU/RAM effectifs jamais > ~moitié des
                          ressources hôte détectées (sysctl/nproc, lecture seule).
USAGE
}

usage_albert_code() {
  cat <<'USAGE'
Albert Code — assistant de code IA souverain

Usage :
  albert-code install   → 1ʳᵉ fois : bootstrap ton poste (Lima, agent-vm, clés)
  albert-code setup     → configure un projet (AGENTS.md + opencode.json + skills)
  albert-code run       → lance la bulle isolée agent-vm
  albert-code --help    → cette aide

Options :
  --dry-run   Simule les actions sans les exécuter (valable pour tous les verbes).

Environnement (sandbox) :
  HOME                   Redirige ~/.zshenv, ~/.config/opencode, etc.
  OPENCODE_CONFIG_DIR     Dossier de config OpenCode (défaut: ~/.config/opencode).
  SHIM_BIN_DIR            Dossier du shim (défaut: sonde PATH).
  AC_VM_CPUS/AC_VM_MEMORY/AC_VM_DISK   Ressources VM (voir README).

Exemple complet :
  albert-code install          # 1ʳᵉ fois
  cd ~/mon-projet
  albert-code setup            # configure le projet
  albert-code run              # démarre
USAGE
}

# usage_runtime : texte d'aide pour runtime/agent-vm.runtime.sh.
usage_runtime() {
  cat <<'USAGE'
Albert Code — runtime VM (agent-vm)

Usage: ./.agent-vm.runtime.sh [--dry-run] [--help]

Options:
  --dry-run   Affiche chaque action sans l'exécuter (test sur VM déjà configurée).
  --help      Affiche cette aide.

Variables d'environnement (sandbox) :
  HOME                   Redirige ~/.zshenv, ~/.config/opencode dans la VM.
  OPENCODE_CONFIG_DIR     Dossier de config OpenCode (défaut: ~/.config/opencode).
USAGE
}

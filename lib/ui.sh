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
   ___  _         _         ___         _
  / _ \| |__  ___| |_   _  / __|___ _ _(_)_ __  ___
 | |_| | '_ \/ -_) | || | | (__/ _ \ '_| \ \/ / _ \
  \___/|_.__/\___|_|\_, |  \___\___/_| |_/__/\___/
                    |__/
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
# Ex : prompt_choice "Quel contexte ?" "beta.gouv" "La Suite" "IAE" "Autre"
prompt_choice() {
  local question="$1"; shift
  local choices=("$@")
  local n choice
  while true; do
    title "$question"
    for i in "${!choices[@]}"; do
      printf '  %s%d)%s %s\n' "${C_CYAN}" "$((i+1))" "${C_RESET}" "${choices[$i]}"
    done
    printf '%s→ %s' "${C_BOLD}" "${C_RESET}"
    read -r n </dev/tty
    if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#choices[@]}" ]; then
      choice="${choices[$((n-1))]}"
      printf '%s✓ %s choisi%s\n' "${C_GREEN}" "$choice" "${C_RESET}"
      printf '%s' "$choice"
      return 0
    fi
    warn "Choix invalide, réessaie."
  done
}

# prompt_secret <question> : lit une valeur masquée, renvoie via stdout.
prompt_secret() {
  local question="$1"
  printf '%s%s%s : ' "${C_BOLD}" "$question" "${C_RESET}"
  stty -echo 2>/dev/null || true
  read -r val </dev/tty
  stty echo 2>/dev/null || true
  printf '\n'
  printf '%s' "$val"
}

# prompt_input <question> [défaut] : lit une valeur en clair, renvoie via stdout.
prompt_input() {
  local question="$1"
  local default="${2:-}"
  if [ -n "$default" ]; then
    printf '%s%s%s [%s] : ' "${C_BOLD}" "$question" "${C_RESET}" "$default"
  else
    printf '%s%s%s : ' "${C_BOLD}" "$question" "${C_RESET}"
  fi
  read -r val </dev/tty
  printf '%s' "${val:-$default}"
}

# confirm <question> : 0 si oui, 1 si non.
confirm() {
  local question="$1"
  local answer
  printf '%s%s%s [o/N] : ' "${C_BOLD}" "$question" "${C_RESET}"
  read -r answer </dev/tty
  [[ "$answer" =~ ^[oOyY] ]]
}

# file_contains <fichier> <pattern> : 0 si le pattern est présent.
file_contains() {
  grep -q -- "$2" "$1" 2>/dev/null
}

#!/usr/bin/env bash
# =============================================================================
# Albert Code — accès au moteur de VM (agent-vm).
# -----------------------------------------------------------------------------
# Albert Code n'embarque plus agent-vm : il appelle la commande `agent-vm`
# installée sur le poste. Conséquences assumées :
#   - on ne suppose jamais sa version : on la demande (`agent-vm version`) ;
#   - on n'interroge jamais ses fichiers internes : on passe par son interface
#     publique (`agent-vm info`, `agent-vm env`).
#
# Nécessite lib/ui.sh (info/ok/warn/err, confirm, apply_*).
# Compatible bash 3.2.
# =============================================================================

# Version minimale du moteur, opposée de façon BLOQUANTE à l'installation.
# Ne la lever QUE si Albert Code ne peut vraiment pas fonctionner en dessous :
# un plancher trop haut casse la promesse « ça marche avec le moteur déjà
# installé ». À 0.1.0 c'est le cas — c'est la version qui apporte `agent-vm
# info` (détection d'état), `agent-vm env` (secrets) et l'exécutable sur le PATH.
#
# Corollaire : `mcp-chrome` et le lancement par shell de connexion sont arrivés
# dans cette même version, donc le plancher les garantit aussi. C'est la seule
# supposition de version que le code s'autorise (verrouillée par S70 §7).
AC_AGENT_VM_MIN="${AC_AGENT_VM_MIN:-0.1.0}"

AGENT_VM_REPO_URL="${AGENT_VM_REPO_URL:-https://github.com/sylvinus/agent-vm.git}"
# Emplacement d'installation quand le moteur est absent (défaut de sa doc).
AGENT_VM_HOME="${AGENT_VM_HOME:-$HOME/agent-vm}"

# -----------------------------------------------------------------------------
# _vm — appelle le moteur. Usage : _vm setup --preinstall=…
#
# `agent-vm` est un exécutable sur le PATH, pas une fonction sourcée : on
# l'appelle donc comme n'importe quelle commande, et son `set -e` interne ne
# peut pas tuer Albert Code. Rien à neutraliser, rien à sourcer.
# -----------------------------------------------------------------------------
_vm() {
  # Garde-fou : sans lui, un appelant qui n'a pas vérifié la présence du moteur
  # (ex. `albert-code update`, qui n'a pas de phase d'installation) reçoit un
  # « agent-vm: command not found » brut, avec un numéro de ligne de lib/vm.sh
  # et aucune indication de quoi faire.
  if ! ac_vm_present; then
    err "Moteur de VM introuvable : « agent-vm » n'est pas sur ton PATH."
    info "Lance « albert-code install » pour l'installer ou le rattacher."
    return 127
  fi
  command agent-vm "$@"
}

# ac_vm_present — la commande est-elle disponible ?
ac_vm_present() {
  command -v agent-vm >/dev/null 2>&1
}

# ac_vm_version — version du moteur, ou vide s'il est antérieur au verbe.
ac_vm_version() {
  ac_vm_present || return 1
  command agent-vm version 2>/dev/null || true
}

# _ac_ver_num "1.2.3" -> 1002003. Tolère "1", "1.2" et un suffixe "-rc1".
_ac_ver_num() {
  local v="${1%%-*}.0.0" a b c
  a="${v%%.*}"; v="${v#*.}"
  b="${v%%.*}"; v="${v#*.}"
  c="${v%%.*}"
  a="${a//[!0-9]/}"; b="${b//[!0-9]/}"; c="${c//[!0-9]/}"
  printf '%d' "$(( ${a:-0} * 1000000 + ${b:-0} * 1000 + ${c:-0} ))"
}

# -----------------------------------------------------------------------------
# _ac_vm_legacy_path — chemin d'un agent-vm installé « à l'ancienne », c'est-à-
# dire seulement sourcé dans un rc, sans commande sur le PATH.
#
# Sert UNIQUEMENT à la migration : une fonction shell n'est pas héritée par un
# processus fils, donc un agent-vm sourcé est invisible depuis Albert Code. On
# retrouve son chemin pour pouvoir proposer à l'utilisateur de lancer son
# installeur — pas pour l'utiliser directement.
#
# À supprimer quand le parc aura migré.
# -----------------------------------------------------------------------------
_ac_vm_legacy_path() {
  local rc line path
  for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" \
            "$HOME/.profile" "$HOME/.zshenv"; do
    [ -f "$rc" ] || continue
    while IFS= read -r line; do
      case "$line" in
        \#*) continue ;;
        *agent-vm.sh*) ;;
        *) continue ;;
      esac
      path="$(printf '%s\n' "$line" | tr ' \t' '\n\n' | grep 'agent-vm\.sh' | tail -1 | tr -d '"'"'")"
      case "$path" in
        '~/'*)       path="$HOME/${path#\~/}" ;;
        '$HOME/'*)   path="$HOME/${path#\$HOME/}" ;;
        '${HOME}/'*) path="$HOME/${path#\$\{HOME\}/}" ;;
      esac
      if [ -f "$path" ]; then
        printf '%s\n' "$path"
        return 0
      fi
    done < "$rc"
  done
  return 1
}

# -----------------------------------------------------------------------------
# ac_vm_check_version — le moteur est-il assez récent ?
# 0 = oui · 1 = trop ancien. L'appelant traite 1 comme BLOQUANT : sous le
# plancher, `agent-vm info` n'existe pas et toute la détection d'état est
# cassée — autant le dire ici, où c'est actionnable.
#
# Un moteur qui ne sait pas dire sa version est antérieur au verbe `version`,
# donc antérieur au plancher : trop ancien, sans autre sondage.
#
# On ne met PAS à jour à la place de l'utilisateur : le moteur est un dépôt qui
# ne nous appartient pas et qui peut porter du travail en cours. On affiche la
# commande, il décide.
# -----------------------------------------------------------------------------
ac_vm_check_version() {
  # Plancher désactivé explicitement : on n'exige rien, pas même le verbe
  # `version`. Sinon l'échappatoire annoncée ne marcherait pas sur le cas
  # qu'elle vise — un moteur sans version.
  if [ "$(_ac_ver_num "$AC_AGENT_VM_MIN")" -eq 0 ]; then
    warn "Plancher de version du moteur désactivé (AC_AGENT_VM_MIN=%s)." "$AC_AGENT_VM_MIN"
    return 0
  fi

  local v
  v="$(ac_vm_version)"
  if [ -n "$v" ] && [ "$(_ac_ver_num "$v")" -ge "$(_ac_ver_num "$AC_AGENT_VM_MIN")" ]; then
    ok "Moteur de VM %s (minimum requis : %s)" "$v" "$AC_AGENT_VM_MIN"
    return 0
  fi

  if [ -z "$v" ]; then
    warn "Ton moteur de VM est antérieur à la version %s (il ne sait pas dire la sienne)." "$AC_AGENT_VM_MIN"
  else
    warn "Moteur de VM %s : Albert Code demande au moins %s." "$v" "$AC_AGENT_VM_MIN"
  fi
  info "Mets-le à jour :"
  info "  cd \"\$(dirname \"\$(command -v agent-vm)\")\" && git pull && ./install.sh"
  info "Si tu sais que ton moteur porte déjà ce qu'il faut :"
  info "  AC_AGENT_VM_MIN=0 albert-code install"
  return 1
}

# -----------------------------------------------------------------------------
# ac_vm_ensure_installed — la commande `agent-vm` est-elle utilisable ?
# Sortie non nulle si, à la fin, elle ne l'est pas.
# -----------------------------------------------------------------------------
ac_vm_ensure_installed() {
  if ac_vm_present; then
    ok "Moteur de VM détecté : %s" "$(command -v agent-vm)"
    ac_vm_check_version || return 1
    return 0
  fi

  echo
  title "Moteur d'isolation"

  # Migration : agent-vm installé « à l'ancienne » (sourcé dans un rc). La
  # fonction shell existe dans TON terminal mais pas dans un processus fils,
  # donc Albert Code ne peut pas l'appeler. Son installeur pose le lien.
  local legacy
  if legacy="$(_ac_vm_legacy_path)"; then
    warn "agent-vm est chargé dans ton shell, mais ce n'est qu'une fonction :"
    warn "elle n'existe pas dans les processus qu'Albert Code lance."
    info "Son installeur pose une commande sur ton PATH, sans rien casser :"
    info "  cd %s && git pull && ./install.sh" "$(dirname "$legacy")"
    if confirm "Le lancer maintenant ?"; then
      if apply "installer la commande agent-vm" "$(dirname "$legacy")/install.sh" \
        && ac_vm_present; then
        ok "Commande agent-vm disponible (%s)" "$(command -v agent-vm)"
        ac_vm_check_version || return 1
        return 0
      fi
      err "L'installeur d'agent-vm n'a pas posé de commande utilisable."
      return 1
    fi
    err "Sans commande agent-vm, Albert Code ne peut pas piloter la bulle isolée."
    return 1
  fi

  info "Albert Code s'appuie sur agent-vm, qui n'est pas installé sur ce poste."
  info "C'est un projet séparé (MIT) : %s" "$AGENT_VM_REPO_URL"
  info "Il restera utilisable indépendamment d'Albert Code."
  if ! confirm "L'installer dans $AGENT_VM_HOME ?"; then
    err "Sans moteur de VM, Albert Code ne peut pas ouvrir de bulle isolée."
    info "Installe-le à la main puis relance :"
    info "  git clone %s %s && %s/install.sh" \
      "$AGENT_VM_REPO_URL" "$AGENT_VM_HOME" "$AGENT_VM_HOME"
    return 1
  fi

  if [ -e "$AGENT_VM_HOME" ]; then
    err "%s existe déjà — je n'écrase rien." "$AGENT_VM_HOME"
    info "Lance son installeur toi-même : %s/install.sh" "$AGENT_VM_HOME"
    return 1
  fi

  if ! apply "cloner le moteur de VM dans $AGENT_VM_HOME" \
       git clone --quiet "$AGENT_VM_REPO_URL" "$AGENT_VM_HOME"; then
    err "Clonage impossible (réseau ?)."
    return 1
  fi
  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    info "[dry-run] moteur non cloné — suite de la vérification ignorée."
    return 0
  fi

  apply "installer la commande agent-vm" "$AGENT_VM_HOME/install.sh" || true
  if ! ac_vm_present; then
    err "Moteur cloné, mais « agent-vm » n'est pas sur ton PATH."
    info "Ouvre un nouveau terminal, ou lance : %s/install.sh" "$AGENT_VM_HOME"
    return 1
  fi
  ok "Moteur de VM installé (%s)" "$(command -v agent-vm)"
  ac_vm_check_version || return 1
  return 0
}

# -----------------------------------------------------------------------------
# ac_vm_info — lit `agent-vm info` UNE fois pour le dossier donné et publie le
# résultat dans AC_VM_INFO_<clé>. Remplace la lecture des fichiers internes du
# moteur (nom de VM dérivé, nom du template, marqueurs de version d'état).
# Clés : version template state_dir dir vm_name base_exists vm_exists vm_running
#        vm_stale — booléens 1/0, ou « unknown » quand c'est indéterminable.
# -----------------------------------------------------------------------------
ac_vm_info() {
  local dir="${1:-$PWD}" line key value out
  ac_vm_present || return 1
  AC_VM_INFO_version=""; AC_VM_INFO_template=""; AC_VM_INFO_state_dir=""
  AC_VM_INFO_dir=""; AC_VM_INFO_vm_name=""; AC_VM_INFO_base_exists="unknown"
  AC_VM_INFO_vm_exists="unknown"; AC_VM_INFO_vm_running="unknown"
  AC_VM_INFO_vm_stale="unknown"
  out="$(command agent-vm info "$dir" 2>/dev/null)" || return 1
  [ -n "$out" ] || return 1
  while IFS= read -r line; do
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      version|template|state_dir|dir|vm_name|base_exists|vm_exists|vm_running|vm_stale)
        eval "AC_VM_INFO_${key}=\$value" ;;
    esac
  done <<EOF
$out
EOF
  return 0
}

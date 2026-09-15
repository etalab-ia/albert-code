#!/usr/bin/env bash
# tests/s70_vm_resolution.sh — S70 : dé-vendoring d'agent-vm.
#
# Couvre les trois mécaniques de l'EPIC 13 :
#   1. Albert Code appelle la COMMANDE `agent-vm` du PATH (plus de vendor/vm/,
#      plus de fichier à sourcer) ;
#   2. le plancher de version, opposé de façon bloquante ;
#   3. les secrets, délégués à `agent-vm env` — Albert Code n'écrit plus
#      lui-même dans ~/.agent-vm/env.
#
# Hermétique : HOME et PATH détournés vers un bac jetable, moteur remplacé par
# un stub exécutable. Aucune VM, aucun réseau, aucune écriture hors du bac.
# bash 3.2.
set -uo pipefail

# CDPATH= : joué en « bash tests/x.sh », dirname rend « tests », un relatif nu
# que cd chercherait dans CDPATH avant le dossier courant.
SELF_DIR="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)"
LIB_DIR="$SELF_DIR/lib"
REAL_HOME="$HOME"
FAIL=0

pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; }
check() {
  if [ "$2" = "$3" ]; then pass "$1"
  else fail "$1"; printf '      attendu : %s\n      obtenu  : %s\n' "$3" "$2"; fi
}

# Empreintes du vrai HOME : preuve de non-pollution.
REAL_ZSHENV="$REAL_HOME/.zshenv"
REAL_BEFORE=""
[ -e "$REAL_ZSHENV" ] && REAL_BEFORE="$(cksum "$REAL_ZSHENV" 2>/dev/null || true)"
REAL_ENV_BEFORE=""
[ -e "$REAL_HOME/.agent-vm/env" ] && REAL_ENV_BEFORE="$(cksum "$REAL_HOME/.agent-vm/env" 2>/dev/null || true)"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
export HOME="$SB/home"
mkdir -p "$HOME" "$SB/bin"
ORIG_PATH="$PATH"
export PATH="$SB/bin:$PATH"

echo "S70 — moteur de VM appelé comme commande, secrets délégués (bac : $SB)"
echo

# --- stub du moteur, EXÉCUTABLE sur le PATH -----------------------------------
# Reproduit la surface publique dont Albert Code dépend, et journalise les
# appels `env` pour prouver la délégation.
make_engine() {
  local version="${1:-0.1.0}"
  cat > "$SB/bin/agent-vm" <<STUB
#!/usr/bin/env bash
echo "\$*" >> "$SB/calls.log"
case "\${1:-}" in
  version|--version) echo "$version" ;;
  info)
    echo "version=$version"
    echo "template=agent-vm-base"
    echo "state_dir=\$HOME/.agent-vm"
    echo "dir=\${2:-\$PWD}"
    echo "vm_name=agent-vm-stub-0000"
    echo "base_exists=\${STUB_BASE_EXISTS:-1}"
    echo "vm_exists=\${STUB_VM_EXISTS:-1}"
    echo "vm_running=0"
    echo "vm_stale=\${STUB_VM_STALE:-0}"
    ;;
  env)
    case "\${2:-}" in
      set) mkdir -p "\$HOME/.agent-vm"
           printf '%s=%s\n' "\$3" "\$4" >> "\$HOME/.agent-vm/env" ;;
      has) grep -q "^\$3=" "\$HOME/.agent-vm/env" 2>/dev/null ;;
    esac ;;
  *) : ;;
esac
STUB
  chmod +x "$SB/bin/agent-vm"
  _forget_command_cache
}
# Le shell mémorise l'emplacement des exécutables : sans purge, `command -v`
# continue de répondre pour un binaire supprimé, et le test se ment à lui-même.
_forget_command_cache() { hash -r 2>/dev/null || true; }
remove_engine() { rm -f "$SB/bin/agent-vm"; _forget_command_cache; }

export DRY_RUN=0
export ZSHENV="$HOME/.zshenv"
# shellcheck source=../lib/ui.sh
source "$LIB_DIR/ui.sh"
# shellcheck source=../lib/vm.sh
source "$LIB_DIR/vm.sh"
# shellcheck source=../lib/phases.sh
source "$LIB_DIR/phases.sh"

# =============================================================================
echo "1. Le dépôt ne vendorise plus le moteur"
# =============================================================================
if [ -d "$SELF_DIR/vendor" ]; then
  fail "vendor/ existe encore dans le dépôt"
else
  pass "plus de vendor/ dans le dépôt"
fi
if grep -rqE '(^|[^/])vendor/vm' "$LIB_DIR" "$SELF_DIR/bin" "$SELF_DIR/install.sh" \
     "$SELF_DIR/uninstall.sh" 2>/dev/null; then
  fail "du code référence encore vendor/vm"
else
  pass "plus aucune référence à vendor/vm dans le code"
fi
# Le moteur n'est plus sourcé : Albert Code ne doit plus jamais faire `source`
# dessus, sinon on réintroduit la dépendance à un chemin de fichier.
if grep -rn 'source .*agent-vm\.sh' "$LIB_DIR" 2>/dev/null | grep -v '^\s*#' | grep -q .; then
  fail "du code source encore agent-vm.sh au lieu d'appeler la commande"
else
  pass "le moteur est appelé comme commande, jamais sourcé"
fi

# =============================================================================
echo
echo "2. Résolution : la commande du PATH"
# =============================================================================
remove_engine
if ac_vm_present; then fail "agent-vm absent devrait être absent"; else pass "aucune commande → absent"; fi
make_engine 0.1.0
if ac_vm_present; then pass "commande sur le PATH → présente"; else fail "agent-vm présent non détecté"; fi
check "version lue via le verbe public" "$(ac_vm_version)" "0.1.0"
if [ "$(_ac_ver_num "$(ac_vm_version)")" -ge "$(_ac_ver_num "$AC_AGENT_VM_MIN")" ]; then
  pass "la version du moteur satisfait AC_AGENT_VM_MIN ($AC_AGENT_VM_MIN)"
else
  fail "AC_AGENT_VM_MIN ($AC_AGENT_VM_MIN) est au-dessus de la version du moteur"
fi

# =============================================================================
echo
echo "3. Migration : une install « à l'ancienne » (sourcée) est reconnue"
# =============================================================================
# Une fonction shell n'est pas héritée par un processus fils : agent-vm sourcé
# est invisible depuis Albert Code. On doit savoir le DIRE, donc le retrouver.
mkdir -p "$SB/ancien"
touch "$SB/ancien/agent-vm.sh"
printf 'source "%s/ancien/agent-vm.sh"\n' "$SB" > "$HOME/.zshrc"
check "chemin retrouvé dans un rc" "$(_ac_vm_legacy_path)" "$SB/ancien/agent-vm.sh"
printf '# source "%s/ancien/agent-vm.sh"\n' "$SB" > "$HOME/.zshrc"
if _ac_vm_legacy_path >/dev/null 2>&1; then fail "ligne commentée prise en compte"; else pass "ligne commentée ignorée"; fi
mkdir -p "$HOME/agent-vm"; touch "$HOME/agent-vm/agent-vm.sh"
printf 'source ~/agent-vm/agent-vm.sh\n' > "$HOME/.zshrc"
check "~ développé" "$(_ac_vm_legacy_path)" "$HOME/agent-vm/agent-vm.sh"
printf 'source "$HOME/agent-vm/agent-vm.sh"\n' > "$HOME/.zshrc"
check "\$HOME développé" "$(_ac_vm_legacy_path)" "$HOME/agent-vm/agent-vm.sh"
printf 'source "%s/disparu/agent-vm.sh"\n' "$SB" > "$HOME/.zshrc"
if _ac_vm_legacy_path >/dev/null 2>&1; then fail "chemin inexistant retenu"; else pass "chemin inexistant ignoré"; fi
rm -f "$HOME/.zshrc"

# =============================================================================
echo
echo "4. Surface publique : agent-vm info"
# =============================================================================
if ac_vm_info "/tmp/projet"; then
  check "info → vm_name"     "$AC_VM_INFO_vm_name"     "agent-vm-stub-0000"
  check "info → template"    "$AC_VM_INFO_template"    "agent-vm-base"
  check "info → base_exists" "$AC_VM_INFO_base_exists" "1"
  check "info → dir"         "$AC_VM_INFO_dir"         "/tmp/projet"
else
  fail "ac_vm_info a échoué"
fi
STUB_VM_STALE=unknown; export STUB_VM_STALE
ac_vm_info "/tmp/projet" >/dev/null
check "vm_stale « unknown » conservé, jamais converti" "$AC_VM_INFO_vm_stale" "unknown"
unset STUB_VM_STALE
STUB_BASE_EXISTS=0; export STUB_BASE_EXISTS
ac_vm_info "$PWD" >/dev/null
check "base_exists suit le moteur (0)" "$AC_VM_INFO_base_exists" "0"
STUB_BASE_EXISTS=1
ac_vm_info "$PWD" >/dev/null
check "base_exists suit le moteur (1)" "$AC_VM_INFO_base_exists" "1"
unset STUB_BASE_EXISTS
remove_engine
if ac_vm_info "$PWD"; then fail "info sans moteur devrait échouer"; else pass "info sans moteur → échec franc"; fi
make_engine 0.1.0

# =============================================================================
echo
echo "5. Comparaison de versions"
# =============================================================================
check "1.0.0"       "$(_ac_ver_num 1.0.0)"     "1000000"
check "0.1.0"       "$(_ac_ver_num 0.1.0)"     "1000"
check "1.2.3"       "$(_ac_ver_num 1.2.3)"     "1002003"
check "1 → 1.0.0"   "$(_ac_ver_num 1)"         "1000000"
check "1.2 → 1.2.0" "$(_ac_ver_num 1.2)"       "1002000"
check "suffixe rc ignoré" "$(_ac_ver_num 2.0.0-rc1)" "2000000"
if [ "$(_ac_ver_num 0.0.9)" -lt "$(_ac_ver_num 0.1.0)" ]; then pass "0.0.9 < 0.1.0"; else fail "0.0.9 devrait être < 0.1.0"; fi
if [ "$(_ac_ver_num 1.10.0)" -gt "$(_ac_ver_num 1.9.0)" ]; then pass "1.10.0 > 1.9.0 (numérique, pas lexical)"; else fail "1.10.0 devrait être > 1.9.0"; fi

# =============================================================================
echo
echo "6. Secrets : délégués au moteur, jamais écrits par Albert Code"
# =============================================================================
# Le fichier est SOURCÉ par le shell de la VM : un échappement raté y coûte tous
# les secrets d'un coup. C'est le moteur qui porte ce quoting (et qui le teste
# sur bash 3.2). Ici on vérifie seulement la délégation.
: > "$SB/calls.log"
_ac_env_set ALBERT_API_KEY "cle-1"
if grep -q '^env set ALBERT_API_KEY cle-1$' "$SB/calls.log"; then
  pass "_ac_env_set délègue à « agent-vm env set »"
else
  fail "_ac_env_set n'a pas appelé le moteur"
  sed 's/^/      /' "$SB/calls.log"
fi
if grep -rn '_ac_env_set' "$LIB_DIR/phases.sh" | grep -q 'mktemp'; then
  fail "Albert Code réécrit encore le fichier de secrets lui-même"
else
  pass "plus d'écriture directe du fichier de secrets"
fi
# Abstention : une valeur vide ne doit produire AUCUN appel (sinon on écraserait
# une valeur posée à la main dans la VM).
: > "$SB/calls.log"
_ac_env_set ALBERT_API_KEY ""
check "valeur vide → aucun appel au moteur" "$(wc -l < "$SB/calls.log" | tr -d ' ')" "0"
# La question « ce secret est-il enregistré ? » doit interroger le FICHIER.
# GH_TOKEN est explicitement vidé : la machine qui joue ce test peut l'avoir
# dans son environnement (une VM agent-vm, typiquement), et le court-circuit
# « déjà dans l'env » masquerait alors l'appel qu'on veut observer.
: > "$SB/calls.log"
( unset GH_TOKEN; _ac_agent_secret_set GH_TOKEN ) >/dev/null 2>&1 || true
if grep -q '^env has GH_TOKEN$' "$SB/calls.log"; then
  pass "_ac_agent_secret_set interroge « agent-vm env has »"
else
  fail "_ac_agent_secret_set n'interroge pas le moteur"
fi

# =============================================================================
echo
echo "6bis. Sans moteur : message actionnable, et aucun succès affiché à tort"
# =============================================================================
# `albert-code update` n'a pas de phase d'installation : il peut tourner sans
# moteur. Il doit le dire, pas laisser fuiter « agent-vm: command not found »
# avec un numéro de ligne de lib/vm.sh, ni conclure « secrets réécrits ».
remove_engine
out="$( _vm env set K v 2>&1 )" || true
case "$out" in
  *"command not found"*) fail "un « command not found » brut fuit depuis _vm" ;;
  *"n'est pas sur ton PATH"*) pass "_vm explique l'absence du moteur" ;;
  *) fail "message inattendu de _vm : $out" ;;
esac
if ensure_vm_secrets >/dev/null 2>&1; then
  fail "ensure_vm_secrets devrait échouer sans moteur"
else
  pass "ensure_vm_secrets échoue sans moteur au lieu d'annoncer un succès"
fi
case "$(ensure_vm_secrets 2>&1)" in
  *"configurés"*) fail "ensure_vm_secrets annonce « configurés » sans moteur" ;;
  *) pass "aucun « configurés » annoncé sans moteur" ;;
esac
make_engine 0.1.0

# =============================================================================
echo
echo "7. La VM de base est créée aux bonnes ressources"
# =============================================================================
# `limactl create` grave les ressources dans la VM de base, et chaque VM projet
# en est un clone qui en hérite. Oublier --cpus/--memory ici fait construire la
# base aux défauts du moteur (1 CPU / 3 GiB) : c'est sur cette machine que
# tournent apt-get, Node, Docker, Chromium et OpenCode.
make_engine 0.1.0
: > "$SB/calls.log"
AC_VM_CPUS=4 AC_VM_MEMORY=8 AC_VM_DISK=32
EFF_CPUS=4; EFF_MEM=8
create_base_vm >/dev/null 2>&1
setup_call="$(grep '^setup ' "$SB/calls.log" | head -1)"
case "$setup_call" in
  *--cpus\ 4*)   pass "setup reçoit --cpus" ;;
  *) fail "setup ne reçoit pas --cpus : $setup_call" ;;
esac
case "$setup_call" in
  *--memory\ 8*) pass "setup reçoit --memory" ;;
  *) fail "setup ne reçoit pas --memory : $setup_call" ;;
esac
case "$setup_call" in
  *--disk\ 32*)  pass "setup reçoit --disk" ;;
  *) fail "setup ne reçoit pas --disk : $setup_call" ;;
esac

# Et il doit savoir se débrouiller si le plafond hôte n'a pas encore été calculé.
: > "$SB/calls.log"
unset EFF_CPUS EFF_MEM
create_base_vm >/dev/null 2>&1
case "$(grep '^setup ' "$SB/calls.log" | head -1)" in
  *--cpus\ *--memory\ *) pass "sans calcul préalable, les ressources sont quand même passées" ;;
  *) fail "create_base_vm ne calcule pas les ressources manquantes" ;;
esac

# =============================================================================
echo
echo "8. Migration de l'ancien bloc marqué"
# =============================================================================
RUNTIME_VM_FILE="$HOME/.agent-vm/runtime.sh"
mkdir -p "$HOME/.agent-vm"

# Bloc sans marqueur de fin : frontière indéterminable → ne rien toucher.
# On répond « oui » exprès : le fichier doit rester intact parce que la fonction
# refuse d'agir, pas parce que l'utilisateur a dit non. Sans ce garde-fou, le
# `sed` de plage supprimerait du marqueur jusqu'à la fin du fichier.
{
  printf 'export PERSO=1\n'
  printf '%s\n' "$AC_MARKER"
  printf "export ALBERT_API_KEY='x'\n"
} > "$RUNTIME_VM_FILE"
before="$(cksum "$RUNTIME_VM_FILE")"
printf 'o\n' | migrate_vm_runtime_block >/dev/null 2>&1
check "bloc sans marqueur de fin : intact malgré un oui" "$(cksum "$RUNTIME_VM_FILE")" "$before"

# Bloc complet : la plage marquée part, tout le reste est préservé.
{
  printf 'export PERSO=1\n'
  printf '%s\n' "$AC_MARKER"
  printf "export ALBERT_API_KEY='x'\n"
  printf '%s\n' "$AC_MARKER_END"
  printf 'export APRES=2\n'
} > "$RUNTIME_VM_FILE"
printf 'o\n' | migrate_vm_runtime_block >/dev/null 2>&1
check "bloc marqué retiré"       "$(grep -c "$AC_MARKER" "$RUNTIME_VM_FILE")" "0"
check "ligne perso avant gardée" "$(grep -c '^export PERSO=1$' "$RUNTIME_VM_FILE")" "1"
check "ligne perso après gardée" "$(grep -c '^export APRES=2$' "$RUNTIME_VM_FILE")" "1"

# Refus explicite : on conserve.
{
  printf '%s\n' "$AC_MARKER"
  printf "export ALBERT_API_KEY='x'\n"
  printf '%s\n' "$AC_MARKER_END"
} > "$RUNTIME_VM_FILE"
printf 'n\n' | migrate_vm_runtime_block >/dev/null 2>&1
check "refus → bloc conservé" "$(grep -c "$AC_MARKER" "$RUNTIME_VM_FILE")" "1"

# =============================================================================
echo
echo "9. Le plancher de version est bloquant"
# =============================================================================
# `mcp-chrome`, `agent-vm info` et `agent-vm env` sont arrivés dans la même
# version : exiger le plancher est ce qui autorise à en dépendre. Si le plancher
# redevenait un avertissement, cette dépendance deviendrait fausse en silence.
make_engine 0.0.1
if ac_vm_ensure_installed </dev/null >/dev/null 2>&1; then
  fail "un moteur 0.0.1 devrait être refusé (plancher $AC_AGENT_VM_MIN)"
else
  pass "moteur sous le plancher → refusé"
fi

# Moteur sans verbe `version` : le vrai vieux moteur écrit sur STDERR et sort en
# erreur, donc `ac_vm_version` ne récupère rien. Un stub qui répondrait sur
# stdout donnerait une version non vide qui se réduit à 0 au parsing, et
# l'assertion de l'échappatoire passerait sans rien prouver.
cat > "$SB/bin/agent-vm" <<'OLD'
#!/usr/bin/env bash
echo "Unknown command: $1" >&2
exit 1
OLD
chmod +x "$SB/bin/agent-vm"
if ac_vm_ensure_installed </dev/null >/dev/null 2>&1; then
  fail "un moteur sans verbe version devrait être refusé"
else
  pass "moteur sans verbe version → refusé"
fi

AC_AGENT_VM_MIN=0
if ac_vm_ensure_installed </dev/null >/dev/null 2>&1; then
  pass "AC_AGENT_VM_MIN=0 désactive réellement le plancher"
else
  fail "AC_AGENT_VM_MIN=0 devrait laisser passer un moteur sans version"
fi
AC_AGENT_VM_MIN=0.1.0

make_engine 0.1.0
if ac_vm_ensure_installed </dev/null >/dev/null 2>&1; then
  pass "moteur au niveau du plancher → accepté"
else
  fail "moteur 0.1.0 devrait être accepté"
fi

# =============================================================================
echo
echo "10. Une entrée épuisée ne fait pas sortir en silence"
# =============================================================================
# Une question dont l'entrée est épuisée doit valoir « non », pas tuer le script.
#
# Testé sur le comportement, pas par grep : `confirm` et `prompt_*` ont aussi un
# `read` nu mais sont TOUJOURS appelés en contexte de condition, où `set -e` est
# suspendu dans tout le corps de la fonction. `_github_auth` est appelé nu, d'où
# la sortie silencieuse en 1 au milieu de l'installation.
# Le sous-shell est lancé HORS condition puis son code est relu : placé dans un
# `if`, `set -e` y serait neutralisé et le test passerait quoi qu'il arrive.
( set -e
  source "$LIB_DIR/ui.sh"; source "$LIB_DIR/vm.sh"; source "$LIB_DIR/phases.sh"
  _github_auth ) </dev/null >/dev/null 2>&1
eof_rc=$?
if [ "$eof_rc" -eq 0 ]; then
  pass "une question à entrée épuisée vaut « non » au lieu de tuer le script"
else
  fail "_github_auth sort en $eof_rc sur une entrée épuisée (EOF non traité)"
fi

echo
[ "$FAIL" -eq 0 ] && echo "S70 OK" || echo "S70 ÉCHEC"

# --- non-pollution du vrai HOME -----------------------------------------------
export PATH="$ORIG_PATH"
REAL_AFTER=""
[ -e "$REAL_ZSHENV" ] && REAL_AFTER="$(cksum "$REAL_ZSHENV" 2>/dev/null || true)"
REAL_ENV_AFTER=""
[ -e "$REAL_HOME/.agent-vm/env" ] && REAL_ENV_AFTER="$(cksum "$REAL_HOME/.agent-vm/env" 2>/dev/null || true)"
if [ "$REAL_BEFORE" != "$REAL_AFTER" ] || [ "$REAL_ENV_BEFORE" != "$REAL_ENV_AFTER" ]; then
  printf '  \033[31m✗\033[0m le vrai HOME a été modifié par le test\n'
  FAIL=1
fi

exit "$FAIL"

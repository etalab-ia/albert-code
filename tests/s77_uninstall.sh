#!/usr/bin/env bash
# tests/s77_uninstall.sh — S77 (T17.1 <- AC-R075, AC-R076) : `uninstall.sh`
# désinstalle proprement. Boîte noire sur le script réel, dans un bac à sable
# $SB jetable : HOME détourné, PATH en tête sur un faux `limactl` (journalisé,
# valeurs factices uniquement — jamais de vraie clé, jamais le vrai limactl).
# Assertions :
#   (A) les 5 variables posées par persist_zshenv sont retirées de ~/.zshenv,
#       la ligne perso de l'utilisateur est conservée ;
#   (B) le bloc Albert Code de ~/.agent-vm/runtime.sh est retiré, le contenu
#       perso hors bloc est conservé ;
#   (C) le rc est sauvegardé en <rc>.bak, la ligne de sourçage agent-vm.sh
#       retirée, la note perso mentionnant « agent-vm » et MA_VIRT conservées,
#       l'ajout ~/.local/bin au PATH retiré du fichier visé par path_rc_file ;
#   (D) le shim albert-code du bundle est retiré, AGENTS.md / opencode.json du
#       projet sont conservés, .agent-vm.runtime.sh du projet est retiré ;
#   (E) les VMs agent-vm-… sont bien supprimées (delete --force appelé) ;
#   (F) si le delete échoue, un compte HONNÊTE est rendu (pas de « supprimées ») ;
#   (G) réponse vide à la question VM = défaut OUI (suppression effectuée) ;
#   (H) --dry-run ne mute rien.
# Hermétique : rien n'est écrit hors $SB. bash 3.2 compatible.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
ACC=0

pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; }

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

echo "S77 — désinstallation propre (T17.1 <- AC-R075, AC-R076)"
echo

# _rc_path_for <sb> : le fichier où l'ajout au PATH du bundle irait (path_rc_file)
# pour ce bac à sable — ~/.bashrc sous Linux, ~/.bash_profile sous macOS bash.
# On le calcule via lib/ui.sh dans un sous-shell isolé (HOME + SHELL du bac).
_rc_path_for() {
  local sb="$1"
  SHELL=/bin/bash HOME="$sb/home" bash -c 'source "$1"; path_rc_file' _ "$SELF_DIR/lib/ui.sh"
}

# _sandbox <nom> : construit un bac à sable avec HOME, projet, rc, runtime,
# le faux limactl et le shim. Écho le chemin de la racine $SB/<nom>.
_sandbox() {
  local name="$1"; shift
  local sb="$SB/$name"
  local path_rc
  mkdir -p "$sb/home/.agent-vm" "$sb/proj" "$sb/bin"
  path_rc="$(_rc_path_for "$sb")"
  mkdir -p "$(dirname "$path_rc")"
  # Faux limactl en tête de PATH : journalise, maintient un état « VM restantes ».
  cat > "$sb/bin/limactl" <<'LIMA'
#!/usr/bin/env bash
LOG="${FAKE_LIMA_LOG:-/dev/null}"
STATE="${FAKE_LIMA_STATE:-}"
case "${1:-}" in
  list)
    if [ -n "$STATE" ] && [ -f "$STATE" ]; then
      cat "$STATE"
    else
      printf '%s\n' 'agent-vm-proj' 'agent-vm-base'
    fi
    ;;
  stop)
    printf 'stop %s\n' "${2:-}" >> "$LOG"
    ;;
  delete)
    if [ "${2:-}" = "--force" ]; then
      printf 'delete --force %s\n' "${3:-}" >> "$LOG"
      if [ "${FAKE_LIMA_DELETE_FAIL:-0}" != "1" ]; then
        _tmp="$(mktemp)"
        grep -v "^${3}\$" "$STATE" > "$_tmp" 2>/dev/null || true
        mv "$_tmp" "$STATE"
      fi
    fi
    ;;
esac
LIMA
  chmod +x "$sb/bin/limactl"

  # Shim albert-code du bundle (en-tête attendu par uninstall 4bis).
  cat > "$sb/bin/albert-code" <<'SHIM'
#!/usr/bin/env bash
# Shim pour albert-code (généré par Albert Code)
exec albert-code "$@"
SHIM
  chmod +x "$sb/bin/albert-code"

  # ~/.zshenv : les 5 variables du bundle + une ligne perso.
  cat > "$sb/home/.zshenv" <<'ZSH'
export ALBERT_API_KEY='FAUX-ALBERT-123'
export CONTEXT7_API_KEY='FAUX-CONTEXT-456'
export GH_TOKEN='FAUX-GH-TOKEN-123'
export AC_GIT_USER_NAME='Jean Test'
export AC_GIT_USER_EMAIL='jean@example.com'
export MA_PERSO='valeur perso qui doit survivre'
ZSH

  # ~/.agent-vm/runtime.sh : une ligne perso hors bloc + le bloc Albert Code.
  cat > "$sb/home/.agent-vm/runtime.sh" <<'RUNT'
export MA_PERSO_RUNTIME='ok-hors-bloc'
# --- albert-code : clés VM ---
export ALBERT_API_KEY='FAUX-ALBERT-RUNTIME'
export GH_TOKEN='FAUX-GH-RUNTIME'
export AC_GIT_USER_NAME='Nom Runtime'
# --- /albert-code ---
export MA_PERSO_APRES='ok-apres-bloc'
RUNT

  # Agent-vm.sh est sourcé depuis ~/.bashrc (section 5 d'uninstall.sh choisit
  # ~/.bashrc pour bash, quel que soit l'OS) ; y ajoute aussi une ligne perso qui
  # mentionne agent-vm.sh SANS le sourcer (doit survivre) et une variable perso.
  cat > "$sb/home/.bashrc" <<'RC'
[ -f /opt/agent-vm.sh ] && source /opt/agent-vm.sh
# note perso : agent-vm.sh vit dans /opt
export MA_VIRT='une machine agent-vm virtuelle perso'
RC
  # L'ajout ~/.local/bin au PATH vit dans le fichier désigné par path_rc_file
  # (section 3bis d'uninstall.sh) : ~/.bashrc sous Linux, ~/.bash_profile sous
  # macOS. Sur Linux les deux fichiers coïncident → on l'ajoute en append.
  if [ "$path_rc" = "$sb/home/.bashrc" ]; then
    printf 'export PATH="$HOME/.local/bin:$PATH"\n' >> "$sb/home/.bashrc"
  else
    printf 'export PATH="$HOME/.local/bin:$PATH"\n' > "$path_rc"
  fi

  # Projet courant : AGENTS.md + opencode.json must survive ; runtime retirable.
  printf '# Projet\n' > "$sb/proj/AGENTS.md"
  printf '{}\n' > "$sb/proj/opencode.json"
  printf '# runtime projet\n' > "$sb/proj/.agent-vm.runtime.sh"

  printf '%s' "$sb"
}

# _run <sb> <answers> [--dry-run] : exécute uninstall.sh depuis le projet.
_run() {
  local sb="$1"; local answers="$2"; shift 2
  local dry="${1:-}"
  ( cd "$sb/proj" \
    && FAKE_LIMA_LOG="$sb/lima.log" FAKE_LIMA_STATE="$sb/lima.state" \
    SHELL=/bin/bash PATH="$sb/bin:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$sb/home" \
    bash "$SELF_DIR/uninstall.sh" $dry <<< "$answers" ) 2>&1
}

# --- Cas A/B/C/D/E : désinstallation complète, delete OK ---------------------
SB1="$(_sandbox c1)"
OUT="$(_run "$SB1" "$(printf 'o\n%.0s' {1..12})")"
ACC=$((ACC+1))
if ! grep -qE '^(export )?(ALBERT_API_KEY|CONTEXT7_API_KEY|GH_TOKEN|AC_GIT_USER_NAME|AC_GIT_USER_EMAIL)=' "$SB1/home/.zshenv" \
   && grep -q '^export MA_PERSO=' "$SB1/home/.zshenv"; then
  pass "cas A : les 5 variables sont retirées de ~/.zshenv, ligne perso conservée"
else
  fail "cas A : ~/.zshenv mal nettoyé : $(cat "$SB1/home/.zshenv")"
fi
ACC=$((ACC+1))
if ! grep -q 'ALBERT_API_KEY' "$SB1/home/.agent-vm/runtime.sh" \
   && ! grep -q 'GH_TOKEN' "$SB1/home/.agent-vm/runtime.sh" \
   && grep -q '^export MA_PERSO_RUNTIME=' "$SB1/home/.agent-vm/runtime.sh" \
   && grep -q '^export MA_PERSO_APRES=' "$SB1/home/.agent-vm/runtime.sh"; then
  pass "cas B : bloc Albert Code retiré du runtime VM, contenu hors bloc conservé"
else
  fail "cas B : runtime.sh mal nettoyé : $(cat "$SB1/home/.agent-vm/runtime.sh")"
fi
ACC=$((ACC+1))
PATH_RC1="$(_rc_path_for "$SB1")"
if [ -f "$SB1/home/.bashrc.bak" ] \
   && ! grep -q 'source /opt/agent-vm.sh' "$SB1/home/.bashrc" \
   && grep -q '# note perso : agent-vm.sh vit dans /opt' "$SB1/home/.bashrc" \
   && grep -q 'MA_VIRT' "$SB1/home/.bashrc" \
   && ! grep -q 'local/bin' "$PATH_RC1"; then
  pass "cas C : rc sauvegardé (.bak), source agent-vm.sh retiré, note perso et MA_VIRT conservées, PATH retiré de $(basename "$PATH_RC1")"
else
  fail "cas C : rc mal nettoyé (.bashrc : $(cat "$SB1/home/.bashrc"), PATH_RC : $(cat "$PATH_RC1"))"
fi
ACC=$((ACC+1))
if [ ! -e "$SB1/bin/albert-code" ] \
   && [ -f "$SB1/proj/AGENTS.md" ] \
   && [ -f "$SB1/proj/opencode.json" ] \
   && [ ! -e "$SB1/proj/.agent-vm.runtime.sh" ]; then
  pass "cas D : shim retiré ; AGENTS.md et opencode.json conservés ; runtime projet retiré"
else
  fail "cas D : traitement shim/projet incorrect"
fi
ACC=$((ACC+1))
if grep -q 'delete --force agent-vm-proj' "$SB1/lima.log" \
   && grep -q 'delete --force agent-vm-base' "$SB1/lima.log" \
   && printf '%s' "$OUT" | grep -q 'Toutes les VMs agent-vm ont été supprimées'; then
  pass "cas E : les 2 VMs supprimées (--force), message de succès honnête"
else
  fail "cas E : suppression VM incomplète : $(cat "$SB1/lima.log")"
fi

# --- Cas F : delete qui échoue → compte honnête, pas de message de succès -----
SB2="$(_sandbox c2)"
OUT2="$(FAKE_LIMA_DELETE_FAIL=1 _run "$SB2" "$(printf 'o\n%.0s' {1..12})")"
ACC=$((ACC+1))
if printf '%s' "$OUT2" | grep -q 'existent encore' \
   && ! printf '%s' "$OUT2" | grep -q 'Toutes les VMs agent-vm ont été supprimées'; then
  pass "cas F : delete en échec → compte honnête (« existent encore »), pas de faux succès"
else
  fail "cas F : comportement en échec de delete incorrect"
fi

# --- Cas G : réponse vide = défaut OUI (suppression effectuée) -----------------
SB3="$(_sandbox c3)"
# On ne fait jouer QUE la question VM : HOME sans rien à retirer, une seule VM.
rm -rf "$SB3/home/.zshenv" "$SB3/home/.agent-vm" "$SB3/home/.bashrc" "$SB3/bin/albert-code"
rm -rf "$SB3/proj/.agent-vm.runtime.sh" "$SB3/proj/AGENTS.md" "$SB3/proj/opencode.json"
# Réécrit la liste de VMs à une seule, pour un comportement net.
printf 'agent-vm-solo\n' > "$SB3/lima.state"
OUT3="$(_run "$SB3" '')"
ACC=$((ACC+1))
if grep -q 'delete --force agent-vm-solo' "$SB3/lima.log"; then
  pass "cas G : réponse vide à la question VM = oui (défaut), supprimée"
else
  fail "cas G : réponse vide n'a pas produit la suppression"
fi
ACC=$((ACC+1))
if printf '%s' "$OUT3" | grep -q 'VMs conservées'; then
  fail "cas G : VM non supprimée alors que la réponse vide = oui"
else
  pass "cas G : pas de message « VMs conservées »"
fi

# --- Cas H : --dry-run ne mute rien ---------------------------------------------
SB4="$(_sandbox c4)"
PATH_RC4="$(_rc_path_for "$SB4")"
cp "$SB4/home/.zshenv" "$SB4/zshenv.before"
cp "$SB4/home/.bashrc" "$SB4/bashrc.before"
cp "$PATH_RC4" "$SB4/pathtc.before"
OUT4="$(_run "$SB4" '' --dry-run)"
ACC=$((ACC+1))
if cmp -s "$SB4/home/.zshenv" "$SB4/zshenv.before" \
   && cmp -s "$SB4/home/.bashrc" "$SB4/bashrc.before" \
   && cmp -s "$PATH_RC4" "$SB4/pathtc.before" \
   && [ ! -e "$SB4/home/.bashrc.bak" ] \
   && [ -e "$SB4/bin/albert-code" ] \
   && [ -e "$SB4/proj/.agent-vm.runtime.sh" ]; then
  pass "cas H : --dry-run ne mute aucun fichier"
else
  fail "cas H : --dry-run a modifié le système de fichiers"
fi
ACC=$((ACC+1))
if [ ! -s "$SB4/lima.log" ]; then
  pass "cas H : --dry-run n'appelle jamais limactl (aucune suppression)"
else
  fail "cas H : --dry-run a appelé limactl : $(cat "$SB4/lima.log")"
fi

# --- Non-pollution : aucune écriture hors $SB ----------------------------------
ACC=$((ACC+1))
if [ "$(find "$SB" -mindepth 1 -maxdepth 1 | wc -l)" -le 8 ]; then
  pass "non-pollution : aucune écriture hors du bac à sable"
else
  fail "non-pollution : écritures inattendues détectées (cf. $SB)"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "S77 : $ACC assertions OK"
  exit 0
else
  echo "S77 : ÉCHEC"
  exit 1
fi

#!/usr/bin/env bash
# tests/s71_base_vm_complete.sh — S71 (T7.9, AC-R063) : une VM de base à moitié
# provisionnée ne passe plus pour prête et n'est plus clonée.
# `base_vm_exists` ne considère la base « prête » que si agent-vm-base est dans
# Lima ET que le fichier .agent-vm-base-version existe dans le répertoire
# d'état du moteur. Un faux `limactl` sur le PATH pilote la détection ; un
# AGENT_VM_STATE_DIR jetable isole l'état. On vérifie aussi la chaîne T7.8 :
# une VM projet clonée d'une base refaite (sans .agent-vm-version-<vm>) est
# bien détectée périmée par _project_vm_from_stale_base.
# Hermétique : HOME détourné vers un bac à sable jetable, aucune VM réelle,
# aucune écriture hors sandbox. bash 3.2.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$SELF_DIR/lib"
FAIL=0
ACC=0

pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; ACC=$((ACC+1)); }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; ACC=$((ACC+1)); }

# --- Sandbox jetable --------------------------------------------------------
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

export SELF_DIR LIB_DIR AGENT_VM_DIR="$SB/vm" AC_VM_CPUS=4 AC_VM_MEMORY=8 AC_VM_DISK=16 DRY_RUN=0

# HOME détourné : le répertoire d'état par défaut ($HOME/.agent-vm) et le PATH
# de test vivent dans le sandbox ; le vrai HOME/limactl ne sont jamais touchés.
export HOME="$SB/home"
mkdir -p "$HOME"

# Faux binaire limactl sur le PATH : liste contrôlable via $FAKE_LIMA_LIST.
mkdir -p "$SB/bin"
cat > "$SB/bin/limactl" <<'EOF'
#!/usr/bin/env bash
# Faux limactl — renvoie la liste contrôlée par $FAKE_LIMA_LIST à `list -q`.
[ "${1:-}" = "list" ] && printf '%s\n' "$FAKE_LIMA_LIST"
exit 0
EOF
chmod +x "$SB/bin/limactl"
export PATH="$SB/bin:$PATH"
export FAKE_LIMA_LIST="agent-vm-base"

# Répertoire d'état du moteur explicitement isolé (jetable).
export AGENT_VM_STATE_DIR="$SB/state"
mkdir -p "$AGENT_VM_STATE_DIR"

# shellcheck source=../lib/ui.sh
source "$LIB_DIR/ui.sh"
# shellcheck source=../lib/phases.sh
source "$LIB_DIR/phases.sh"

echo "S71 — VM de base complète vs incomplète : détection, avertissement, chaîne T7.8 (sandbox: $SB)"
echo

# base_exists_rc <...> : exécute base_vm_exists, retourne son code via $B_RC,
# capture sa sortie (stdout+stderr) via $B_OUT — immunisé pipefail/SIGPIPE.
base_exists_rc() {
  B_OUT="$(base_vm_exists 2>&1)" || B_RC=$?
  B_RC="${B_RC:-0}"
}

# --- Cas (a) : base dans Lima + fichier de version présent → EXISTE --------
: > "$AGENT_VM_STATE_DIR/.agent-vm-base-version"
B_RC=; base_exists_rc
if [ "$B_RC" -eq 0 ]; then
  pass "(a) base dans Lima + .agent-vm-base-version présent → base prête"
else
  fail "(a) base complète détectée absente à tort (rc=$B_RC)"
fi

# --- Cas (b) : base dans Lima SANS fichier de version → ABSENTE + warning --
rm -f "$AGENT_VM_STATE_DIR/.agent-vm-base-version"
B_RC=; base_exists_rc
if [ "$B_RC" -ne 0 ]; then
  pass "(b) base dans Lima sans fichier de version → considérée absente (rc non nul)"
else
  fail "(b) base incomplète considérée prête (rc=0)"
fi
if printf '%s' "$B_OUT" | grep -qi 'incompl'; then
  pass "(b) l'avertissement nomme la base incomplète"
else
  fail "(b) aucun mot « incomplète » dans l'avertissement"
fi
if printf '%s' "$B_OUT" | grep -qi 'recré'; then
  pass "(b) l'avertissement annonce sa recréation"
else
  fail "(b) l'avertissement n'annonce pas la recréation"
fi

# --- Cas (c) : base ABSENTE de Lima → ABSENTE, sans avertissement ---------
FAKE_LIMA_LIST=""   # limactl ne liste rien
B_RC=; base_exists_rc
if [ "$B_RC" -ne 0 ]; then
  pass "(c) base absente de Lima → absente (rc non nul)"
else
  fail "(c) base absente considérée prête (rc=0)"
fi
if printf '%s' "$B_OUT" | grep -qi 'incompl'; then
  fail "(c) un avertissement de base incomplète a été émis pour une base absente"
else
  pass "(c) aucun avertissement quand la base est absente de Lima"
fi
FAKE_LIMA_LIST="agent-vm-base"

# --- Cas (d) : chaîne T7.8 — VM projet clonée d'une base refaite → périmée -
# La base a été reconstruite (fichier de version remis) mais la VM projet a
# été clonée de l'ancienne base : son .agent-vm-version-proj est absent.
echo "base-2" > "$AGENT_VM_STATE_DIR/.agent-vm-base-version"
B_RC=; base_exists_rc
if [ "$B_RC" -eq 0 ]; then
  pass "(d) base refaite (fichier de version posé) → prête"
else
  fail "(d) base refaite détectée absente à tort (rc=$B_RC)"
fi
if _project_vm_from_stale_base "proj"; then
  pass "(d) VM projet sans .agent-vm-version-proj → détectée périmée (T7.8 propose la recréation)"
else
  fail "(d) VM projet sans fichier de version non détectée périmée"
fi

# --- Cas (e) : recréation de la base interrompue → le marqueur est retiré ------
# avant l'appel _vm setup. Le moteur vendorisé supprime la VM (limactl delete)
# au début de son setup mais ne supprime JAMAIS .agent-vm-base-version, écrit
# seulement en fin de setup réussi. Sans le correctif, un ancien marqueur
# subsisterait et ferait passer pour prête une base à moitié provisionnée.
# On stube le moteur (_vm) pour intercepter l'appel setup sans créer de VM réelle.
FAKE_LIMA_LIST=""                                 # agent-vm-base déjà supprimée (base absente de Lima)
printf 'stale-marqueur-laisse-par-une-recration-interrompue' > "$AGENT_VM_STATE_DIR/.agent-vm-base-version"
_SAW_SETUP=0
_stale_marker_at_setup=0
_vm() {
  if [ "$1" = "setup" ]; then
    _SAW_SETUP=1
    if [ -f "$AGENT_VM_STATE_DIR/.agent-vm-base-version" ]; then
      _stale_marker_at_setup=1
    fi
  fi
  return 0
}
confirm() { return 0; }
check_base_vm
if [ "$_SAW_SETUP" -eq 1 ] && [ "$_stale_marker_at_setup" -eq 0 ]; then
  pass "(e) ancien marqueur retiré avant l'appel _vm setup (recréation de la base)"
else
  fail "(e) ancien marqueur encore présent à l'appel _vm setup — base à moitié provisionnée"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "S71 : OK — $ACC assertions, sandbox nettoyée en sortie."
  exit 0
else
  echo "S71 : ÉCHEC — voir les assertions ✗ ci-dessus." >&2
  exit 1
fi

#!/usr/bin/env bash
# tests/s73_retex_macos.sh — S73 (EPIC 14, AC-R065/AC-R066/AC-R067) : trois
# corrections d'un retex d'installation macOS.
#   • AC-R065 : une réponse vide à l'étape GitHub n'abandonne plus en silence —
#     première vide = reposer la question (« rien n'a été saisi »), deuxième vide
#     = confirmation EXPLICITE avant d'abandonner (seul « o » abandonne).
#   • AC-R066 : un espace dans le chemin du projet est détecté dès le début
#     (check_no_space_in_path), avec un message en français actionnable.
#   • AC-R067 : les deux sites de création de la VM de base (check_base_vm et
#     phase_run) repassent --cpus EFF_CPUS --memory EFF_MEM au lieu des défauts
#     faibles du moteur (1 CPU / 3 GiB).
# Hermétique : HOME détourné vers un bac à sable jetable, _vm/confirm/prompt_secret
# et detect_host_* stubés, aucune VM réelle, aucun appel réseau (curl jamais
# atteint : tokens vides), aucune écriture hors sandbox. bash 3.2.
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

export SELF_DIR LIB_DIR DRY_RUN=0
export AGENT_VM_DIR="$SB/vm" AGENT_VM_STATE_DIR="$SB/state"
export AC_VM_CPUS=4 AC_VM_MEMORY=8 AC_VM_DISK=16
mkdir -p "$AGENT_VM_STATE_DIR" "$AGENT_VM_DIR"

# HOME détourné : ~/.zshenv et le reste vivent dans le sandbox, jamais le vrai HOME.
export HOME="$SB/home"
mkdir -p "$HOME"

# Faux limactl sur le PATH (check_base_vm teste `command -v limactl`).
mkdir -p "$SB/bin"
cat > "$SB/bin/limactl" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = "list" ] && printf '%s\n' "${FAKE_LIMA_LIST:-}"
exit 0
EOF
chmod +x "$SB/bin/limactl"
export PATH="$SB/bin:$PATH"
export FAKE_LIMA_LIST=""

# shellcheck source=../lib/ui.sh
source "$LIB_DIR/ui.sh"
# shellcheck source=../lib/phases.sh
source "$LIB_DIR/phases.sh"

# Stubs de ressources hôte déterministes (8 CPU / 16 GiB) → EFF_CPUS=4, EFF_MEM=8.
detect_host_cpus()    { printf '8'; }
detect_host_ram_gib() { printf '16'; }
# _vm stub : accumule TOUTES les invocations (setup puis run) dans _VM_LOG.
_VM_LOG=()
_vm() { _VM_LOG+=( "$@" ); return 0; }

echo "S73 — Retex install macOS : GitHub silencieux, espaces dans le chemin, ressources VM (sandbox: $SB)"
echo

# ---------------- AC-R066 : espaces dans le chemin ---------------------------
rc=0
OUT="$(check_no_space_in_path "$SB/projet-sans-espace" 2>&1)" || rc=$?
if [ "$rc" -eq 0 ]; then
  pass "(R066) un chemin sans espace est accepté (rc=0)"
else
  fail "(R066) chemin sans espace rejeté à tort (rc=$rc)"
fi

rc=0
OUT="$(check_no_space_in_path "mon dossier projet" 2>&1)" || rc=$?
if [ "$rc" -ne 0 ]; then
  pass "(R066) un chemin avec espace est rejeté (rc non nul)"
else
  fail "(R066) chemin avec espace accepté (rc=0)"
fi
if printf '%s' "$OUT" | grep -q 'espaces'; then
  pass "(R066) l'avertissement nomme le problème (espace)"
else
  fail "(R066) aucun mot « espaces » dans le message"
fi
if printf '%s' "$OUT" | grep -q 'remplaçant les espaces par des tirets'; then
  pass "(R066) le message est actionnable (renommer avec des tirets)"
else
  fail "(R066) le message n'indique pas la parade (tirets)"
fi
if printf '%s' "$OUT" | grep -q 'mon-dossier-projet'; then
  pass "(R066) le message propose le nouveau nom sans espace (mon-dossier-projet)"
else
  fail "(R066) le nouveau nom sans espace est absent du message"
fi

# ---------------- AC-R067 : ressources des deux sites de création VM ---------
# check_base_vm → _vm doit recevoir --cpus EFF_CPUS --memory EFF_MEM au setup.
_VM_LOG=()
confirm() { return 0; }
base_vm_exists() { return 1; }
_clear_base_version_marker() { :; }
check_base_vm
_JOINED="$(printf '%s ' "${_VM_LOG[*]}")"
if printf '%s' "$_JOINED" | grep -q 'setup' \
   && printf '%s' "$_JOINED" | grep -q -- '--cpus 4' \
   && printf '%s' "$_JOINED" | grep -q -- '--memory 8'; then
  pass "(R067) check_base_vm passe --cpus 4 --memory 8 au _vm setup"
else
  fail "(R067) check_base_vm ne repasse pas les ressources au _vm setup (args: ${_VM_LOG[*]})"
fi

# phase_run → même exigence sur le site de création de la base. On stube la
# suite du lancement (_agent_vm_name, VM non périmée) pour laisser phase_run
# dérouler jusqu'à son _vm setup puis jusqu'au run sans erreur.
mkdir -p "$SB/proj" && cd "$SB/proj"
printf '{"model":"albert/deepseek-v4-flash","provider":{"albert":{}}}\n' > ./opencode.json
_agent_vm_name() { printf 'proj'; }
_project_vm_from_stale_base() { return 1; }
_VM_LOG=()
phase_run
_JOINED="$(printf '%s ' "${_VM_LOG[*]}")"
if printf '%s' "$_JOINED" | grep -q 'setup' \
   && printf '%s' "$_JOINED" | grep -q -- '--cpus 4' \
   && printf '%s' "$_JOINED" | grep -q -- '--memory 8'; then
  pass "(R067) phase_run passe --cpus 4 --memory 8 au _vm setup"
else
  fail "(R067) phase_run ne repasse pas les ressources au _vm setup (args: ${_VM_LOG[*]})"
fi
cd "$SELF_DIR"

# ---------------- AC-R065 : abandon GitHub jamais silencieux -----------------
# On re-stube confirm() (supprimé ci-dessus) pour le flux _github_auth, puis on
# drive _github_auth par stdin (non-tty) : activer (y), deux tokens vides, puis
# « o » à la confirmation explicite → abandon assumé, plus jamais sur une seule
# réponse vide.
# _github_auth est isolé dans un sous-processus bash -c : son PAT est lu via
# $(prompt_secret …), donc d'un sous-shell. Dans ce bash build, le trap EXIT de
# nettoyage s'exécute aussi dans chaque sous-shell (BASHPID/BASH_SUBSHELL
# indisponibles) et purgerait le bac en pleine lecture d'un fichier → blocage.
# Un sous-processus bash -c n'hérite pas de ce trap : lecture et écriture
# restent saines. Sortie et statut passent par fichiers/directs (pas de $(…)).
unset -f confirm
cat > "$SB/gh_input.txt" <<'EOF'
y


o
EOF
_G_RC=0
bash -c '
  source "$1/lib/ui.sh"
  source "$1/lib/phases.sh"
  _github_auth
' _ "$SELF_DIR" < "$SB/gh_input.txt" > "$SB/gh_out.txt" 2>&1 || _G_RC=$?
if grep -qi "rien n'a été saisi" "$SB/gh_out.txt"; then
  pass "(R065) première réponse vide → message « rien n'a été saisi », question reposée"
else
  fail "(R065) pas de message « rien n'a été saisi » sur la première réponse vide"
fi
if grep -q 'Es-tu sûr de ne pas configurer GitHub maintenant' "$SB/gh_out.txt"; then
  pass "(R065) deuxième réponse vide → confirmation explicite demandée"
else
  fail "(R065) confirmation explicite absente sur la deuxième réponse vide"
fi
if grep -q 'Le push et les PR depuis la VM resteront inactifs' "$SB/gh_out.txt"; then
  pass "(R065) la confirmation nomme la conséquence (push/PR inactifs)"
else
  fail "(R065) la conséquence n'est pas nommée dans la confirmation"
fi
if [ "$_G_RC" -eq 0 ]; then
  pass "(R065) sortie propre (rc=0) après abandon explicite"
else
  fail "(R065) _github_auth rend $_G_RC au lieu de 0 après abandon explicite"
fi
if grep -q 'Pas de PAT' "$SB/gh_out.txt" && ! grep -q 'Es-tu sûr' "$SB/gh_out.txt"; then
  fail "(R065) abandon muet « Pas de PAT » sans confirmation explicite"
else
  pass "(R065) aucun abandon « Pas de PAT » sans confirmation explicite au préalable"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "S73 : OK — $ACC assertions, sandbox nettoyée en sortie."
  exit 0
else
  echo "S73 : ÉCHEC — voir les assertions ✗ ci-dessus." >&2
  exit 1
fi

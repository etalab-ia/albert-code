#!/usr/bin/env bash
# tests/s65_opencode_bash_path.sh — S65 (AC-R047).
# Depuis Lima >= 2.2.0 (PR lima-vm/lima#5194) `limactl shell` n'utilise plus le
# shell de connexion du guest mais /bin/bash par défaut : ~/.zshenv n'est pas
# lu, donc ~/.opencode/bin n'est pas dans le PATH → « opencode: command not
# found ». Le correctif : lancer explicitement OpenCode via `zsh -l`.
# Compatible bash 3.2. Sandbox HOME, aucune écriture hors bac.
set -euo pipefail

# CDPATH= : joué en « bash tests/x.sh », dirname rend « tests », un relatif nu
# que cd chercherait dans CDPATH avant le dossier courant.
SELF_DIR="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)"
FAIL=0

pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; }

echo "S65 — OpenCode visible via zsh -l (sans symlink bash, Lima >= 2.2.0)"
echo

# --- 1. OpenCode est lancé par un shell de CONNEXION --------------------------
# L'invariant n'a pas changé (sans `zsh -l`, ~/.zshenv n'est pas lu : ni le PATH
# d'OpenCode ni les secrets) — c'est QUI le garantit qui a changé.
# Avant : albert-code contournait lui-même en `run --tty zsh -l -c "opencode --auto"`,
# parce que le moteur vendored appelait le binaire nu.
# Depuis agent-vm 0.1.0, le verbe `opencode` du moteur passe par
# `_agent_vm_lima_run`, qui force `zsh -l -c`. albert-code délègue donc, et la
# garantie repose sur le plancher de version — pas sur une chaîne recopiée ici.
phases="$SELF_DIR/lib/phases.sh"
vmlib="$SELF_DIR/lib/vm.sh"

# L'appel est écrit sur deux lignes (continuation) : on aplatit avant de chercher.
launch="$(tr '\n' ' ' < "$phases" | tr -s ' ')"
case "$launch" in
  *'apply "lancer la VM isolée" _vm '*' opencode'*)
    pass "phase_run délègue au verbe opencode du moteur" ;;
  *)
    fail "phase_run doit déléguer au verbe opencode du moteur" ;;
esac

# Plus aucun appel limactl : tout passe par l'interface publique du moteur.
# Les commentaires qui le mentionnent sont ignorés — c'est du code qu'on traque.
if grep -vE '^\s*#' "$phases" | grep -q 'limactl'; then
  fail "lib/phases.sh appelle encore limactl directement (le moteur s'en charge)"
else
  pass "plus d'appel limactl direct dans lib/phases.sh"
fi

# Le plancher de version est ce qui rend la délégation sûre : sans lui, un
# moteur antérieur relancerait le bug du PATH bash vide en silence.
if grep -qE '^AC_AGENT_VM_MIN="\$\{AC_AGENT_VM_MIN:-[0-9]' "$vmlib"; then
  pass "un plancher de version du moteur est déclaré (AC_AGENT_VM_MIN)"
else
  fail "lib/vm.sh doit déclarer AC_AGENT_VM_MIN (garantie du lancement zsh -l)"
fi

# Et il doit être réellement opposé au moteur, pas seulement déclaré.
if grep -q 'ac_vm_check_version' "$vmlib" && grep -q 'AC_AGENT_VM_MIN' "$phases"; then
  pass "le plancher est vérifié à l'install et opposé au run"
else
  fail "AC_AGENT_VM_MIN déclaré mais jamais opposé au moteur"
fi

# --- 2. lib/phases.sh (ensure_vm_runtime) ne pose plus de symlink opencode -----
# Le filet symlink a été retiré : rendre opencode atteignable depuis bash le
# ferait démarrer sans clé Albert (panne plus opaque qu'un command not found).
if grep -n 'apply_append' "$phases" | grep -q 'local/bin/opencode'; then
  fail "lib/phases.sh génère encore un symlink opencode ~/.local/bin (apply_append)"
else
  pass "lib/phases.sh ne génère plus de symlink opencode (ensure_vm_runtime)"
fi

# --- 3. check_opencode ne pose AUCUN symlink (ni ~/.local/bin ni ailleurs) -----
SB="$(mktemp -d)"
export HOME="$SB/home"
mkdir -p "$HOME/.local/bin"
trap 'rm -rf "$SB"' EXIT

# Extraire les fonctions du runtime, sans le bloc d'exécution final.
awk 'BEGIN{p=1} /^_info "Runtime Albert Code/{p=0} p' \
  "$SELF_DIR/runtime/agent-vm.runtime.sh" > "$SB/runtime-lib.sh"

# Le runtime utilise DRY_RUN ; forcer réel dans le bac.
DRY_RUN=0
export DRY_RUN
# shellcheck disable=SC1090
source "$SB/runtime-lib.sh"

# Prépositionner ~/.local/bin/opencode comme un VRAI exécutable (non symlink),
# pour vérifier que check_opencode n'écrase rien et n'en pose pas.
mkdir -p "$HOME/.opencode/bin"
printf '#!/bin/sh\necho fake-opencode\n' > "$HOME/.opencode/bin/opencode"
chmod +x "$HOME/.opencode/bin/opencode"
printf '#!/bin/sh\necho preexisting\n' > "$HOME/.local/bin/opencode"
chmod +x "$HOME/.local/bin/opencode"

# PATH bash Lima : ~/.local/bin + système, SANS ~/.opencode/bin.
PATH="$HOME/.local/bin:/usr/bin:/bin"
export PATH

if command -v opencode >/dev/null 2>&1; then
  pass "précondition : opencode présent via le binaire ~/.local/bin du bac"
else
  fail "précondition : opencode introuvable (exécutable factice attendu sur PATH)"
fi

check_opencode >/dev/null

# check_opencode ne doit pas avoir recréé de symlink vers ~/.opencode/bin.
if [ -L "$HOME/.local/bin/opencode" ]; then
  fail "check_opencode ne doit PAS symlinker opencode (ni ~/.local/bin ni ailleurs)"
else
  pass "aucun symlink opencode posé par check_opencode (~/.local/bin/opencode réel conservé)"
fi

if [ -L "$HOME/.opencode/bin/opencode" ]; then
  fail "aucun symlink opencode dans ~/.opencode/bin"
else
  pass "aucun symlink opencode posé dans ~/.opencode/bin"
fi

# Idempotence : 2e run ne pose toujours rien.
check_opencode >/dev/null
if [ -L "$HOME/.local/bin/opencode" ] || [ -L "$HOME/.opencode/bin/opencode" ]; then
  fail "2e run de check_opencode a posé un symlink"
else
  pass "check_opencode idempotent : toujours aucun symlink (2e run)"
fi

# --- 4. Pas de contournement hors-VM (AC-R009) ni de filet bash ----------------
if grep -q 'npm i -g opencode-ai' "$SELF_DIR/runtime/agent-vm.runtime.sh"; then
  fail "check_opencode ne doit plus suggérer npm i -g opencode-ai"
else
  pass "plus de suggestion npm i -g opencode-ai"
fi

if grep -rn 'local/bin/opencode' "$SELF_DIR/lib/" "$SELF_DIR/runtime/" >/dev/null; then
  fail "référence résiduelle à ~/.local/bin/opencode dans lib/ ou runtime/"
else
  pass "aucun filet symlink ~/.local/bin/opencode dans lib/ ni runtime/"
fi

echo
if [ "$FAIL" -ne 0 ]; then
  echo "S65 ÉCHEC"
  exit 1
fi
echo "S65 OK"
exit 0

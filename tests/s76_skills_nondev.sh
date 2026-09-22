#!/usr/bin/env bash
# tests/s76_skills_nondev.sh — S76 (EPIC 16, AC-R074) : le setup ne propose que
# les skills dev, pas usage-ia-agents-etat (cadre d'usage IA sans rapport avec
# le dev). Construit un faux cache de skills, répond oui à tout, et vérifie que
# .albert-code/skills.txt contient rgaa mais pas usage-ia-agents-etat.
# Hermétique : HOME et OPENCODE_CONFIG_DIR détournés dans un bac à sable, aucune
# écriture hors sandbox, with_spinner stubé (aucun réseau), confirm → oui. bash 3.2.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$SELF_DIR/lib"
FAIL=0
ACC=0

pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; ACC=$((ACC+1)); }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; ACC=$((ACC+1)); }

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

export DRY_RUN=0
export HOME="$SB/home"
export AGENT_VM_DIR="$SB/vm" AGENT_VM_STATE_DIR="$SB/state"
export AC_VM_CPUS=4 AC_VM_MEMORY=8 AC_VM_DISK=16
mkdir -p "$HOME" "$AGENT_VM_DIR" "$AGENT_VM_STATE_DIR"

# Cache skills factice : seules ces deux skills existent.
SKILLS_CACHE="$SB/cfg/.albert-skills-cache/skills"
mkdir -p "$SKILLS_CACHE/rgaa" "$SKILLS_CACHE/usage-ia-agents-etat"
printf '%s\n' "---" "description: Accessibilité RGAA" > "$SKILLS_CACHE/rgaa/SKILL.md"
printf '%s\n' "---" "description: Cadre d'usage de l'IA pour les agents" > "$SKILLS_CACHE/usage-ia-agents-etat/SKILL.md"

export OPENCODE_CONFIG_DIR="$SB/cfg"

# shellcheck source=../lib/ui.sh
source "$LIB_DIR/ui.sh"
# shellcheck source=../lib/phases.sh
source "$LIB_DIR/phases.sh"

# Stubs (après source) : pas de réseau, on répond oui à tout.
with_spinner() { return 0; }
confirm() { return 0; }

mkdir -p "$SB/proj" && cd "$SB/proj"
echo "S76 — Skills non-dev exclues du setup (sandbox: $SB)"
echo

scaffold_skills_selection

if [ -f .albert-code/skills.txt ]; then
  if grep -q '^rgaa$' .albert-code/skills.txt; then
    pass "(R074) rgaa presente dans skills.txt"
  else
    fail "(R074) rgaa absente de skills.txt"
  fi
  if ! grep -q '^usage-ia-agents-etat$' .albert-code/skills.txt; then
    pass "(R074) usage-ia-agents-etat absente de skills.txt"
  else
    fail "(R074) usage-ia-agents-etat encore dans skills.txt"
  fi
else
  fail "(R074) .albert-code/skills.txt non cree"
fi
cd "$SELF_DIR"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "S76 : OK — $ACC assertions, sandbox nettoyee en sortie."
  exit 0
else
  echo "S76 : ECHEC — voir les assertions ✗ ci-dessus." >&2
  exit 1
fi

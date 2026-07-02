#!/usr/bin/env bash
# tests/check_no_personal_paths.sh — garde-fou CI (T4.5 <- AC-R008).
# Empêche qu'un chemin home absolu personnel (/Users/<user>, /home/<user>) ou un
# username ne soit committé dans ce dépôt PUBLIC (code, docs, notes de validation).
# Scanne les fichiers SUIVIS par git (git ls-files), exclut *.lock.
# Compatible bash 3.2. Lecture seule — ne modifie rien.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SELF_DIR"

# Motif : un vrai username après /Users/<x> ou /home/<x> ; `<` et `[` ne sont pas dans la
# classe → ne matche jamais les placeholders `<...>` (ni cette définition elle-même).
PATTERN='/Users/[A-Za-z0-9._-]+|/home/[A-Za-z0-9._-]+'

# Placeholders/exemples génériques documentés, tolérés explicitement.
is_allowed() {
  case "$1" in
    /Users/username|/Users/user|/home/user) return 0 ;;
    *) return 1 ;;
  esac
}

FAIL=0

while IFS= read -r file; do
  case "$file" in
    *.lock) continue ;;
  esac
  [ -f "$file" ] || continue

  while IFS=: read -r lineno hit; do
    [ -z "$lineno" ] && continue
    if is_allowed "$hit"; then
      continue
    fi
    printf '%s:%s: %s\n' "$file" "$lineno" "$hit"
    FAIL=1
  done < <(grep -nIoE "$PATTERN" -- "$file" 2>/dev/null || true)
done < <(git ls-files)

if [ "$FAIL" -eq 1 ]; then
  echo >&2
  echo "✗ Chemin(s) personnel(s) détecté(s) ci-dessus — anonymise avant de committer." >&2
  echo "  Placeholders tolérés : <chemin-du-dépôt>, \$SELF_DIR, \$HOME, ~/..." >&2
  exit 1
fi

echo "✓ Aucun chemin personnel / username détecté dans les fichiers suivis."
exit 0

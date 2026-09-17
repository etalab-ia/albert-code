#!/usr/bin/env bash
# tests/s75_node_et_bruit_brew.sh — S75 (EPIC 14, AC-R068/AC-R069) : retrait de
# l'avertissement Node hôte et coupe du bruit Homebrew du wizard d'installation.
#   • AC-R068 : l'avertissement « Node.js absent — requis pour npx (MCP).
#     Installe-le. » a disparu de lib/phases.sh, remplacé par un commentaire ; le
#     message « rien à installer sur ton poste » est préservé (non supprimé par
#     erreur).
#   • AC-R069 (part locale) : l'appel `brew install lima` porte les trois
#     variables HOMEBREW_NO_* en préfixe via `env` (pas de portée globale) ; aucun
#     `export` global de ces variables dans lib/ ni install.sh.
# Hermétique : lecture seule sur le dépôt (grep sur les fichiers), aucun sandbox,
# aucun sous-processus, aucune écriture, aucune variable exportée. bash 3.2.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
ACC=0

pass() { printf '  [OK] %s\n' "$1"; ACC=$((ACC+1)); }
fail() { printf '  [KO] %s\n' "$1"; FAIL=$((FAIL+1)); ACC=$((ACC+1)); }

echo "S75 — retrait avertissement Node hôte + bruit Homebrew (AC-R068/AC-R069, lecture seule)"
echo

# --- AC-R068 : l'avertissement Node a disparu ---------------------------------
if grep -rq 'Node.js absent' "$SELF_DIR/lib" 2>/dev/null; then
  fail "(R068) un avertissement « Node.js absent » subsiste encore dans lib/"
else
  pass "(R068) plus aucun avertissement « Node.js absent » dans lib/"
fi

# --- AC-R068 : le message « rien à installer sur ton poste » est préservé -----
if grep -rq 'rien à installer sur ton poste' "$SELF_DIR/lib" 2>/dev/null; then
  pass "(R068) le message « rien à installer sur ton poste » est toujours présent"
else
  fail "(R068) le message « rien à installer sur ton poste » a été supprimé par erreur"
fi

# --- AC-R069 : l'appel brew porte les trois variables via env ------------------
BREW_LINE="$(grep -n 'brew install lima' "$SELF_DIR/lib/phases.sh" 2>/dev/null | head -1 || true)"
if [ -z "$BREW_LINE" ]; then
  fail "(R069) introuvable : aucune ligne 'brew install lima' dans lib/phases.sh"
else
  for var in HOMEBREW_NO_AUTO_UPDATE HOMEBREW_NO_ENV_HINTS HOMEBREW_NO_INSTALL_CLEANUP; do
    if printf '%s' "$BREW_LINE" | grep -q "env .*$var=1"; then
      pass "(R069) $var=1 présent sur la ligne brew (via env)"
    else
      fail "(R069) $var=1 absent de la ligne brew install lima"
    fi
  done
  if printf '%s' "$BREW_LINE" | grep -q 'brew install lima'; then
    pass "(R069) la commande 'brew install lima' est toujours présente"
  else
    fail "(R069) 'brew install lima' absent de la ligne brew"
  fi
fi

# --- AC-R069 : aucun export global des HOMEBREW_NO_* dans lib/ ni install.sh ---
if grep -rEq '^\s*export\s+(HOMEBREW_NO_AUTO_UPDATE|HOMEBREW_NO_ENV_HINTS|HOMEBREW_NO_INSTALL_CLEANUP)' \
     "$SELF_DIR/lib" "$SELF_DIR/install.sh" 2>/dev/null; then
  fail "(R069) un export global d'une variable HOMEBREW_NO_* existe dans lib/ ou install.sh"
else
  pass "(R069) aucun export global HOMEBREW_NO_* dans lib/ ni install.sh"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "S75 : OK — $ACC assertions, lecture seule."
  exit 0
else
  echo "S75 : ÉCHEC — $FAIL assertion(s) cassée(s)." >&2
  exit 1
fi

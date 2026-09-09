#!/usr/bin/env bash
# tests/s67_shim_path_rc.sh — S67 (T5.4, AC-R045) : ensure_path_rc_line écrit
# l'ajout au PATH dans le fichier rc du shell détecté (path_rc_file), pas
# seulement ~/.zshenv.
# Hermétique et sans effet de bord : on cible ensure_path_rc_line directement
# (aucun shim créé, aucun dossier système touchable via la sonde) ; HOME est
# détourné vers un bac à sable jetable et un snapshot avant/après de
# /opt/homebrew/bin/albert-code et /usr/local/bin/albert-code prouve la
# non-pollution. Même résultat sur un poste de dev et un runner CI. bash 3.2.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_HOME="$HOME"
FAIL=0
ACC=0

# Les quatre fichiers candidats que ensure_path_rc_line sonde pour l'anti-doublon.
CAND=(.zshenv .bashrc .bash_profile .profile)

pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; }

# has_line <home> <relfile> : 0 si le fichier contient la ligne d'ajout exacte.
has_line() {
  local f="$1/$2"
  [ -f "$f" ] && grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$f" 2>/dev/null
}

# --- Snapshot AVANT (non-pollution de la machine hôte) --------------------------
# Le test ne crée plus de shim, mais ce filet doit exister : c'est précisément son
# absence qui a permis à l'ancienne version d'écrire un shim orphelin.
REAL_ZSHENV="$REAL_HOME/.zshenv"
REAL_BEFORE=""
[ -e "$REAL_ZSHENV" ] && REAL_BEFORE="$(cksum "$REAL_ZSHENV" 2>/dev/null || true)"
HOMEBREW_STUB="/opt/homebrew/bin/albert-code"
USRLOCAL_STUB="/usr/local/bin/albert-code"
HB_BEFORE=""
[ -e "$HOMEBREW_STUB" ] && HB_BEFORE="$(ls -li "$HOMEBREW_STUB" 2>/dev/null && cksum "$HOMEBREW_STUB" 2>/dev/null || true)"
UL_BEFORE=""
[ -e "$USRLOCAL_STUB" ] && UL_BEFORE="$(ls -li "$USRLOCAL_STUB" 2>/dev/null && cksum "$USRLOCAL_STUB" 2>/dev/null || true)"

# --- Sandbox jetable -------------------------------------------------------------
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

# shellcheck source=../lib/ui.sh
source "$SELF_DIR/lib/ui.sh"

OS="$(uname -s)"
case "$OS" in
  Darwin) EXP_BC=".bash_profile";;
  *)      EXP_BC=".bashrc";;
esac
echo "S67 — ensure_path_rc_line écrit le PATH dans le fichier rc du shell détecté (sandbox: $SB, OS=$OS)"
echo

# --- Cas 1 : SHELL=/bin/bash → fichier attendu selon l'OS, PAS ~/.zshenv --------
H1="$SB/c1"; mkdir -p "$H1"
HOME="$H1" SHELL=/bin/bash SHIM_PATH_ADDED=0 ensure_path_rc_line
ACC=$((ACC+1))
if has_line "$H1" "$EXP_BC"; then
  pass "cas 1 : bash écrit dans ~/$EXP_BC (attendu pour $OS)"
else
  fail "cas 1 : la ligne est absente de ~/$EXP_BC (attendu pour $OS)"
fi
if has_line "$H1" ".zshenv"; then
  fail "cas 1 : ligne écrite par erreur dans ~/.zshenv"
else
  pass "cas 1 : ~/.zshenv non touché (ligne absente)"
fi

# --- Cas 2 : SHELL=/bin/zsh → toujours ~/.zshenv (non-régression) ---------------
H2="$SB/c2"; mkdir -p "$H2"
HOME="$H2" SHELL=/bin/zsh SHIM_PATH_ADDED=0 ensure_path_rc_line
ACC=$((ACC+1))
if has_line "$H2" ".zshenv"; then
  pass "cas 2 : zsh écrit toujours dans ~/.zshenv"
else
  fail "cas 2 : ~/.zshenv n'a pas reçu la ligne (non-régression)"
fi

# --- Cas 3 : ~/.bashrc contient déjà l'ajout → rien n'est ajouté nulle part -----
H3="$SB/c3"; mkdir -p "$H3"
printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' > "$H3/.bashrc"
HOME="$H3" SHELL=/bin/bash SHIM_PATH_ADDED=0 ensure_path_rc_line
ACC=$((ACC+1))
count=0
for rc in "${CAND[@]}"; do
  if has_line "$H3" "$rc"; then count=$((count+1)); fi
done
if [ "$count" -eq 1 ]; then
  pass "cas 3 : aucune ligne ajoutée (1 seul ajout préexistant dans ~/.bashrc, inchangé)"
else
  fail "cas 3 : doublon détecté ($count lignes au lieu de 1)"
fi

# --- Cas 4 : --dry-run → rien écrit dans aucun des quatre fichiers --------------
H4="$SB/c4"; mkdir -p "$H4"
HOME="$H4" SHELL=/bin/bash DRY_RUN=1 SHIM_PATH_ADDED=0 ensure_path_rc_line >/dev/null 2>&1
ACC=$((ACC+1))
empty=1
for rc in "${CAND[@]}"; do
  if has_line "$H4" "$rc"; then empty=0; fi
done
if [ "$empty" -eq 1 ]; then
  pass "cas 4 : --dry-run n'écrit dans aucun des quatre fichiers"
else
  fail "cas 4 : une ligne a été écrite malgré --dry-run"
fi

# --- Cas 5 : simple mention de .local/bin (commentaire) n'est PAS "déjà configuré"
H5="$SB/c5"; mkdir -p "$H5"
printf '%s\n' '# capture de .local/bin pour l''outil X' > "$H5/.bashrc"
HOME="$H5" SHELL=/bin/bash SHIM_PATH_ADDED=0 ensure_path_rc_line
ACC=$((ACC+1))
if has_line "$H5" "$EXP_BC"; then
  pass "cas 5 : une mention en commentaire n'est pas un ajout → ligne écrite dans ~/$EXP_BC"
else
  fail "cas 5 : une mention seule a été prise pour un ajout (faux positif anti-doublon)"
fi

# --- Non-pollution : aucun fichier de la machine hôte n'a bougé -------------------
REAL_AFTER=""
[ -e "$REAL_ZSHENV" ] && REAL_AFTER="$(cksum "$REAL_ZSHENV" 2>/dev/null || true)"
if [ "$REAL_BEFORE" = "$REAL_AFTER" ]; then
  pass "le vrai ~/.zshenv ($REAL_HOME) n'a pas été modifié"
else
  fail "pollution détectée : $REAL_ZSHENV a changé"
fi
if [ -e "$HOMEBREW_STUB" ]; then
  [ -n "$HB_BEFORE" ] && current="$(ls -li "$HOMEBREW_STUB" 2>/dev/null && cksum "$HOMEBREW_STUB" 2>/dev/null || true)"
else
  current=""
fi
if [ "$HB_BEFORE" = "$current" ]; then
  pass "$HOMEBREW_STUB inchangé (ou absent, comme avant)"
else
  fail "pollution détectée : $HOMEBREW_STUB a changé"
fi
if [ -e "$USRLOCAL_STUB" ]; then
  [ -n "$UL_BEFORE" ] && current="$(ls -li "$USRLOCAL_STUB" 2>/dev/null && cksum "$USRLOCAL_STUB" 2>/dev/null || true)"
else
  current=""
fi
if [ "$UL_BEFORE" = "$current" ]; then
  pass "$USRLOCAL_STUB inchangé (ou absent, comme avant)"
else
  fail "pollution détectée : $USRLOCAL_STUB a changé"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "S67 : OK — $ACC cas, sandbox nettoyée en sortie."
  exit 0
else
  echo "S67 : ÉCHEC — voir les assertions ✗ ci-dessus." >&2
  exit 1
fi

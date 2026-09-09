#!/usr/bin/env bash
# tests/s69_agents_zone.sh — S69 (T8.5) : `sync_agents_md` propage les
# évolutions du bundle vers la zone gérée de ./AGENTS.md — réécrit la zone
# délimitée par les marqueurs HTML, préserve bit-à-bit tout le hors-zone (dont
# `## Expected Behavior` personnalisé par le projet), insère la zone
# silencieusement (sans question) sur un projet legacy, laisse intact un
# marqueur orphelin, ne réécrit rien en --dry-run.
# Hermétique et sans effet de bord : HOME détourné vers un bac à sable jetable,
# les fonctions de la zone gérée sont sourcées (aucun shim / dossier système
# touchable), et un snapshot avant/après du vrai HOME + des stub binaires prouve
# la non-pollution. Même résultat sur un poste de dev et un runner CI. bash 3.2.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$SELF_DIR/lib"
REAL_HOME="$HOME"
FAIL=0
ACC=0

pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; }

# --- Snapshot AVANT (non-pollution de la machine hôte) --------------------------
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

export SELF_DIR LIB_DIR AGENT_VM_DIR="$SB/vm" AC_VM_CPUS=4 AC_VM_MEMORY=8 DRY_RUN=0

# shellcheck source=../lib/ui.sh
source "$LIB_DIR/ui.sh"
# shellcheck source=../lib/phases.sh
source "$LIB_DIR/phases.sh"

START="$AC_MARKER_AGENTS"
END="$AC_MARKER_AGENTS_END"

echo "S69 — zone gérée AGENTS.md : frontière, migration silencieuse, orphelin, dry-run (sandbox: $SB)"
echo

# zone_sign <file> : empreinte de la zone gérée (entre marqueurs inclus).
zone_sign() {
  sed -n "\|^$START$|,\|^$END$|p" "$1" | cksum
}

# outside_sign <file> : empreinte du hors-zone (avant le marqueur ouvrant +
# après le ferneur), bandeau hôte retiré — l'empreinte du "projet" à préserver.
outside_sign() {
  {
    sed "\|^$START$|q" "$1" | sed '$d'
    sed -n "\|^$END$|,\$p" "$1" | sed '1d'
  } | cksum
}

# --- Cas 1 : fichier absent → pose le template courant, frontière correcte ------
H1="$SB/c1"; mkdir -p "$H1"
( cd "$H1" && sync_agents_md )
ACC=$((ACC+1))
if diff -q "$H1/AGENTS.md" "$SELF_DIR/templates/AGENTS.default.md" >/dev/null 2>&1; then
  pass "cas 1 : fichier absent → AGENTS.md identique au template courant"
else
  fail "cas 1 : le fichier posé diffère du template courant"
fi
ACC=$((ACC+1))
if grep -q '^<!-- albert-code:agents:start -->$' "$H1/AGENTS.md" \
   && grep -q '^<!-- albert-code:agents:end -->$' "$H1/AGENTS.md"; then
  pass "cas 1 : la zone gérée est bornée par les deux marqueurs HTML"
else
  fail "cas 1 : marqueurs HTML absents du fichier posé"
fi
ACC=$((ACC+1))
if ! sed -n '1p' "$H1/AGENTS.md" | grep -q '^<!--'; then
  pass "cas 1 : le fichier s'ouvre sur l'en-tête # AGENTS.md, pas sur un marqueur (pas de faux titre H1)"
else
  fail "cas 1 : le fichier s'ouvre sur un marqueur (faux titre H1 au rendu)"
fi
ACC=$((ACC+1))
# --- changement : Expected Behavior hors zone = présent mais hors des marqueurs --
zone="$(sed -n "\|^$START$|,\|^$END$|p" "$H1/AGENTS.md")"
if printf '%s' "$zone" | grep -q 'Expected Behavior'; then
  fail "cas 1 : ## Expected Behavior est dans la zone gérée (doit rester hors zone)"
elif grep -q 'Expected Behavior' "$H1/AGENTS.md"; then
  pass "cas 1 : ## Expected Behavior présent mais hors de la zone gérée"
else
  fail "cas 1 : ## Expected Behavior absent du fichier"
fi

# --- Cas 2 (DoD) : contenu personnel dans ## Expected Behavior bit-à-bit intact --
H2="$SB/c2"; mkdir -p "$H2"
( cd "$H2" && cat > AGENTS.md <<MD
# Head perso du projet
intro propre au projet
$START
## Sécurité (non négociable)

- ancienne version du bundle sans les règles récentes
$END
## Expected Behavior

### Code Quality

- point personnalisé du projet ajouté ici
- autre règle maison
### Bug Fixing

- réglé sur mesure
# Tail perso
fin du fichier du projet
MD
)
OUT_BEFORE="$(outside_sign "$H2/AGENTS.md")"
( cd "$H2" && sync_agents_md )
ACC=$((ACC+1))
if grep -q 'Co-Authored-By' "$H2/AGENTS.md" && grep -q 'Nommer ce qu.on détruit' "$H2/AGENTS.md"; then
  pass "cas 2 : la zone gérée a été rafraîchie avec les règles récentes du bundle"
else
  fail "cas 2 : les règles récentes du bundle manquent dans la zone réécrite"
fi
ACC=$((ACC+1))
if [ "$(outside_sign "$H2/AGENTS.md")" = "$OUT_BEFORE" ]; then
  pass "cas 2 : le hors-zone (dont ## Expected Behavior personnalisé) est bit-à-bit identique"
else
  fail "cas 2 : le hors-zone a été modifié — DoD violée"
fi

# --- Cas 3 : second passage idempotent (no-op) -----------------------------------
( cd "$H2" && sync_agents_md )
ACC=$((ACC+1))
if [ "$(zone_sign "$H2/AGENTS.md")" = "$(zone_sign "$H1/AGENTS.md")" ] \
   && grep -q 'Expected Behavior' "$H2/AGENTS.md"; then
  pass "cas 3 : idempotence — la zone réécrite est stable entre deux passages"
else
  fail "cas 3 : la zone a changé entre deux update identiques (non idempotent)"
fi

# --- Cas 4 : projet legacy sans marqueurs → insertion silencieuse, sans question -
H4="$SB/c4"; mkdir -p "$H4"
LEGACY="mon AGENTS perso sans marqueur
regle custom du projet
autre regle super importante"
printf '%s\n' "$LEGACY" > "$H4/AGENTS.md"
OUT4="$(cksum "$H4/AGENTS.md")"
( cd "$H4" && sync_agents_md )
ACC=$((ACC+1))
if grep -q '^<!-- albert-code:agents:start -->$' "$H4/AGENTS.md"; then
  pass "cas 4 : la zone gérée a été insérée sur un projet legacy"
else
  fail "cas 4 : la zone gérée n'a pas été insérée sur le projet legacy"
fi
ACC=$((ACC+1))
# La zone insérée est posée en tête ; le contenu legacy doit suivre intact après
# le marqueur fermant (une seule occurrence, jamais écrasé ni dupliqué).
if [ "$(grep -c 'regle custom du projet' "$H4/AGENTS.md" || true)" -eq 1 ] \
   && sed -n "/^$END$/,\$p" "$H4/AGENTS.md" | grep -q 'regle custom du projet' \
   && sed -n "/^$END$/,\$p" "$H4/AGENTS.md" | grep -q 'mon AGENTS perso sans marqueur'; then
  pass "cas 4 : le contenu legacy est conservé intégralement après la zone insérée"
else
  fail "cas 4 : le contenu legacy a été perdu ou dupliqué lors de l'insertion"
fi
ACC=$((ACC+1))
if ! grep -q '\[o/N\]' "$H4/AGENTS.md"; then
  pass "cas 4 : aucune question [o/N] posée (insertion silencieuse, contrat non interactif)"
else
  fail "cas 4 : une question de confirmation a été posée"
fi

# --- Cas 5 : marqueur orphelin → aucune écriture + avertissement ----------------
H5="$SB/c5"; mkdir -p "$H5"
printf '# head\nx\n'"$START"'\n# sans fermant\n' > "$H5/AGENTS.md"
OUT5="$(cksum "$H5/AGENTS.md")"
( cd "$H5" && sync_agents_md 2>/dev/null )
ACC=$((ACC+1))
if [ "$(cksum "$H5/AGENTS.md")" = "$OUT5" ]; then
  pass "cas 5 : marqueur orphelin → fichier laissé intact (aucune écriture)"
else
  fail "cas 5 : le fichier à marqueur orphelin a été modifié"
fi
ACC=$((ACC+1))
# L'avertissement est capturé (pas de pipe : grep -q ferme tôt le tube et,
# sous pipefail + set -e, un SIGPIPE ferait passer le `if` à faux).
out="$( cd "$H5" && sync_agents_md 2>&1 )" || true
if printf '%s' "$out" | grep -qi 'orphelin'; then
  pass "cas 5 : un avertissement nomme le marqueur orphelin"
else
  fail "cas 5 : aucun avertissement de marqueur orphelin"
fi

# --- Cas 6 : --dry-run → aucune écriture ----------------------------------------
H6="$SB/c6"; mkdir -p "$H6"
printf '%s\n' 'legacy a migrer' 'sans dry' > "$H6/AGENTS.md"
OUT6="$(cksum "$H6/AGENTS.md")"
( cd "$H6" && DRY_RUN=1 sync_agents_md )
ACC=$((ACC+1))
if [ "$(cksum "$H6/AGENTS.md")" = "$OUT6" ] && ! grep -q '^<!-- albert-code:agents:start -->$' "$H6/AGENTS.md"; then
  pass "cas 6 : --dry-run n'écrit pas (fichier inchangé, aucun marqueur posé)"
else
  fail "cas 6 : --dry-run a écrit dans le fichier"
fi

# --- Cas 7 : deux update successifs → un seul couple de marqueurs ---------------
H7="$SB/c7"; mkdir -p "$H7"
printf '%s\n' 'legacy' 'deux passages' > "$H7/AGENTS.md"
( cd "$H7" && sync_agents_md && sync_agents_md )
ACC=$((ACC+1))
n_start="$(grep -c '^<!-- albert-code:agents:start -->$' "$H7/AGENTS.md" || true)"
n_end="$(grep -c '^<!-- albert-code:agents:end -->$' "$H7/AGENTS.md" || true)"
if [ "$n_start" -eq 1 ] && [ "$n_end" -eq 1 ]; then
  pass "cas 7 : deux update → exactement un marqueur ouvrant et un fermant"
else
  fail "cas 7 : $n_start ouvrant(s) / $n_end fermant(s) au lieu d'un couple"
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
  echo "S69 : OK — $ACC assertions, sandbox nettoyée en sortie."
  exit 0
else
  echo "S69 : ÉCHEC — voir les assertions ✗ ci-dessus." >&2
  exit 1
fi

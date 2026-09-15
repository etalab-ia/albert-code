#!/usr/bin/env bash
# tests/s70_git_exclude.sh — S70 (T6.18 <- AC-R064) : `sync_git_exclude`
# masque les artefacts du bundle (opencode.json, .agent-vm.runtime.sh,
# .albert-code/) via .git/info/exclude — fichier par clone, jamais versionné —
# sans toucher à l'arbre de travail ni à AGENTS.md (versionnable). Assertions :
# (A) premier passage sur un exclude vierge → bloc marqueur + entrées en fin
# de fichier, lignes perso conservées, `git status` ne montre plus les
# artefacts mais montre toujours AGENTS.md ; (B) second passage idempotent
# (aucune écriture, message « déjà à jour ») ; (C) réécriture de la zone :
# contenu perso AVANT la zone et APRÈS la zone préservé bit-à-bit ; (D)
# marqueur orphelin → aucune écriture + warn ; (E) hors dépôt git → sortie
# silencieuse rc 0 ; (F) dry-run → aucune écriture ; (G) exclude absent
# (git >= 2.x ne le pose plus) → recréé avec le bloc.
# Hermétique : tout se joue dans un bac à sable $SB jetable (mktemp -d),
# aucune écriture hors $SB, HOME détourné. bash 3.2 compatible.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$SELF_DIR/lib"
REAL_HOME="$HOME"
FAIL=0
ACC=0

pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; }

# --- Sandbox jetable -------------------------------------------------------------
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

export HOME="$SB/home"
mkdir -p "$HOME"
export SELF_DIR LIB_DIR AGENT_VM_DIR="$SB/vm" AC_VM_CPUS=4 AC_VM_MEMORY=8 DRY_RUN=0

# shellcheck source=../lib/ui.sh
source "$LIB_DIR/ui.sh"
# shellcheck source=../lib/phases.sh
source "$LIB_DIR/phases.sh"

XSTART="$AC_EXCLUDE_MARKER"
XEND="$AC_EXCLUDE_MARKER_END"

echo "S70 — exclusions locales .git/info/exclude (T6.18 <- AC-R064) (sandbox: $SB)"
echo

# _gitproj <dir> : crée un dépôt git minimal committé dans <dir>.
_gitproj() {
  mkdir -p "$1"
  ( cd "$1" \
    && git init -q \
    && git -c user.email=test@local -c user.name=test commit -q --allow-empty -m init )
}

# --- Cas A+B : premier passage → bloc posé, git status propre, idempotence ------
H1="$SB/c1"; _gitproj "$H1"
printf 'ma-regle-perso\n' > "$H1/.git/info/exclude"
( cd "$H1" && sync_git_exclude )
ACC=$((ACC+1))
if grep -q '^ma-regle-perso$' "$H1/.git/info/exclude"; then
  pass "cas A : ligne perso de l'utilisateur conservée"
else
  fail "cas A : ligne perso perdue"
fi
ACC=$((ACC+1))
if grep -q "^${XSTART}$" "$H1/.git/info/exclude" && grep -q "^${XEND}$" "$H1/.git/info/exclude"; then
  pass "cas A : bloc marqueur complet posé (ouvrant + fermant)"
else
  fail "cas A : marqueurs absents ou incomplets"
fi
for entry in 'opencode.json' 'opencode.jsonc' 'opencode.json.bak*' '.agent-vm.runtime.sh' '.albert-code/'; do
  ACC=$((ACC+1))
  # `*` est un métacaractère BRE : on l'échappe pour matcher la ligne littérale.
  if grep -q "^${entry//\*/\\*}$" "$H1/.git/info/exclude"; then
    pass "cas A : entrée $entry présente"
  else
  fail "cas A : entrée $entry absente"
  fi
done
# git status : artefacts masqués, AGENTS.md visible.
( cd "$H1" \
  && touch opencode.json .agent-vm.runtime.sh AGENTS.md \
  && mkdir -p .albert-code && touch .albert-code/skills.txt )
_status="$( cd "$H1" && git status --short --untracked-files=all )"
ACC=$((ACC+1))
if printf '%s' "$_status" | grep -q 'AGENTS.md' \
   && ! printf '%s' "$_status" | grep -q 'opencode.json' \
   && ! printf '%s' "$_status" | grep -q 'agent-vm.runtime' \
   && ! printf '%s' "$_status" | grep -q 'albert-code/skills'; then
  pass "cas A : git status montre AGENTS.md mais aucun artefact du bundle"
else
  fail "cas A : git status inattendu : $_status"
fi
# Idempotence : second passage → aucune écriture (empreinte stable).
_before="$(cksum "$H1/.git/info/exclude")"
_out="$( cd "$H1" && sync_git_exclude )"
ACC=$((ACC+1))
if [ "$(cksum "$H1/.git/info/exclude")" = "$_before" ]; then
  pass "cas B : second passage idempotent (fichier inchangé)"
else
  fail "cas B : le fichier a été réécrit sans changement de contenu"
fi
ACC=$((ACC+1))
if printf '%s' "$_out" | grep -q 'déjà à jour'; then
  pass "cas B : message « déjà à jour » affiché"
else
  fail "cas B : message « déjà à jour » absent"
fi

# --- Cas C : réécriture de la zone, hors-zone préservé bit-à-bit ----------------
H2="$SB/c2"; _gitproj "$H2"
cat > "$H2/.git/info/exclude" <<EOF
avant-perso-1
avant-perso-2
$XSTART
ancienne-entree-périmée
$XEND
apres-perso-1
apres-perso-2
EOF
( cd "$H2" && sync_git_exclude )
ACC=$((ACC+1))
if grep -q '^avant-perso-1$' "$H2/.git/info/exclude" \
   && grep -q '^avant-perso-2$' "$H2/.git/info/exclude" \
   && grep -q '^apres-perso-1$' "$H2/.git/info/exclude" \
   && grep -q '^apres-perso-2$' "$H2/.git/info/exclude"; then
  pass "cas C : contenu perso avant ET après la zone préservé"
else
  fail "cas C : contenu perso hors zone perdu"
fi
ACC=$((ACC+1))
if grep -q 'ancienne-entree-périmée' "$H2/.git/info/exclude"; then
  fail "cas C : l'ancienne entrée de la zone n'a pas été remplacée"
else
  pass "cas C : zone réécrite (ancienne entrée remplacée par le bloc courant)"
fi
ACC=$((ACC+1))
if [ "$(grep -c "^${XSTART}$" "$H2/.git/info/exclude")" -eq 1 ] \
   && [ "$(grep -c "^${XEND}$" "$H2/.git/info/exclude")" -eq 1 ]; then
  pass "cas C : exactement un couple de marqueurs après réécriture"
else
  fail "cas C : marqueurs dupliqués"
fi

# --- Cas D : marqueur orphelin → aucune écriture + warn -------------------------
H3="$SB/c3"; _gitproj "$H3"
printf '%s\nintact\n' "$XSTART" > "$H3/.git/info/exclude"
_before="$(cksum "$H3/.git/info/exclude")"
_out="$( cd "$H3" && sync_git_exclude )"
ACC=$((ACC+1))
if [ "$(cksum "$H3/.git/info/exclude")" = "$_before" ]; then
  pass "cas D : marqueur orphelin → fichier inchangé"
else
  fail "cas D : marqueur orphelin → fichier modifié"
fi
ACC=$((ACC+1))
if printf '%s' "$_out" | grep -q 'orphelin'; then
  pass "cas D : avertissement orphelin affiché"
else
  fail "cas D : avertissement orphelin absent"
fi

# --- Cas E : hors dépôt git → sortie silencieuse rc 0 ---------------------------
H4="$SB/c4"; mkdir -p "$H4"
_out="$( cd "$H4" && sync_git_exclude 2>&1 )"; _rc=$?
ACC=$((ACC+1))
if [ "$_rc" -eq 0 ] && [ -z "$_out" ]; then
  pass "cas E : hors dépôt git → rc 0, aucune sortie"
else
  fail "cas E : hors dépôt git → rc $_rc, sortie : $_out"
fi

# --- Cas F : dry-run → aucune écriture -------------------------------------------
H5="$SB/c5"; _gitproj "$H5"
rm -f "$H5/.git/info/exclude"
( cd "$H5" && DRY_RUN=1 sync_git_exclude >/dev/null )
ACC=$((ACC+1))
if [ ! -e "$H5/.git/info/exclude" ]; then
  pass "cas F : dry-run ne crée pas .git/info/exclude"
else
  fail "cas F : dry-run a créé .git/info/exclude"
fi

# --- Cas G : exclude absent (git >= 2.x) → recréé avec le bloc -------------------
H6="$SB/c6"; _gitproj "$H6"
rm -f "$H6/.git/info/exclude"
( cd "$H6" && sync_git_exclude )
ACC=$((ACC+1))
if grep -q "^${XSTART}$" "$H6/.git/info/exclude" && grep -q '^\.albert-code/$' "$H6/.git/info/exclude"; then
  pass "cas G : exclude absent → fichier recréé avec le bloc complet"
else
  fail "cas G : exclude absent → fichier non recréé ou bloc incomplet"
fi

# --- Non-pollution : aucun fichier écrit hors $SB --------------------------------
ACC=$((ACC+1))
if [ "$(find "$SB" -mindepth 1 -maxdepth 1 | wc -l)" -le 8 ]; then
  pass "non-pollution : aucune écriture hors du bac à sable"
else
  fail "non-pollution : écritures inattendues détectées"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "S70 : $ACC assertions OK"
  exit 0
else
  echo "S70 : ÉCHEC"
  exit 1
fi

#!/usr/bin/env bash
# =============================================================================
# Albert Code — script de conformité (footer légal, /accessibilite, secrets,
# URL de prod, données de fixtures).
# -----------------------------------------------------------------------------
# Vérifie qu'un projet respecte les standards de l'administration :
#   1. Présence d'un footer légal (mentions légales / DPIA).
#   2. Une page /accessibilite (déclaration d'accessibilité).
#   3. Aucun secret / clé API / token en clair dans le code.
#   4. Aucune URL de production en dur dans le code.
#   5. Pas de données réelles (emails, SIRET, IBAN) dans les fixtures.
#
# Usage : ./templates/scripts/conformity-check.sh [dossier]   (défaut : .)
# Sortie : 0 si conforme, 1 si anomalies trouvées.
# Compatible bash 3.2.
# =============================================================================
set -euo pipefail

ROOT="${1:-.}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd)"
STATUS=0

# --- Couleurs -----------------------------------------------------------------
if [ -t 1 ]; then
  G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; B=$'\033[34m'; X=$'\033[0m'
else
  G=""; Y=""; R=""; B=""; X=""
fi
ok()   { printf '%s✓ %s%s\n' "$G" "$*" "$X"; }
warn() { printf '%s! %s%s\n' "$Y" "$*" "$X"; }
fail() { printf '%s✗ %s%s\n' "$R" "$*" "$X"; STATUS=1; }
info() { printf '%s→ %s%s\n' "$B" "$*" "$X"; }

# Patterns de secrets (clés API/tokens courants). Faux positifs possibles.
SECRET_RE='(api[_-]?key|secret|token|password|passwd|bearer)\s*[:=]\s*["'\'']?[A-Za-z0-9_\-]{20,}'
# URLs de prod : on cherche des http(s) vers des domaines internes/prod connus.
PROD_URL_RE='https?://[a-z0-9.-]*(etalab|gouv\.fr|data\.gouv|incubateur)[a-z0-9./-]*'
# Données réelles dans les fixtures : SIRET (14 chiffres), IBAN, emails internes.
SIRET_RE='\b[0-9]{14}\b'
IBAN_RE='\bFR[0-9]{2}[0-9A-Z]{10,30}\b'
EMAIL_RE='\b[a-z0-9._-]+@(intradef|finances|interieur|culture|education|dgfip)\.gouv\.fr\b'

# On exclut les dossiers bruyants et les fichiers de lock.
EXCLUDE_DIRS='node_modules|.git|dist|build|.venv|venv|__pycache__|coverage|.next'
FIND_EXPR=$(printf -- '-name %s -prune -o ' $(printf "'%s' " $(echo "$EXCLUDE_DIRS" | tr '|' ' ')))

echo
info "Conformité du projet : $ROOT"
echo

# 1. Footer légal (mention légale / RGPD / DPIA)
info "1. Footer légal / mentions légales"
if grep -riEl 'mentions? l[ée]gales|RGPD|protectio[n] des donn[ée]es|DPIP|DPIA' "$ROOT" >/dev/null 2>&1; then
  ok "mention légale trouvée"
else
  fail "aucune mention légale / RGPD détectée (footer légal manquant ?)"
fi

# 2. Page /accessibilite
info "2. Page d'accessibilité (/accessibilite)"
if grep -riEl 'accessibilit[ée]|RGAA|sch[ée]ma pluriannuel' "$ROOT" >/dev/null 2>&1 \
  || find "$ROOT" -type f \( -iname '*accessibilite*' -o -path '*accessibilite*' \) 2>/dev/null | grep -q .; then
  ok "déclaration d'accessibilité détectée"
else
  fail "aucune page / déclaration d'accessibilité détectée"
fi

# 3. Secrets en clair
info "3. Secrets / clés API / tokens en clair"
secrets_file="$(mktemp)"
eval "find '$ROOT' -type d $FIND_EXPR -type f -not -path '*/.git/*' -not -name '*.lock' -print0" 2>/dev/null \
  | xargs -0 grep -rInE "$SECRET_RE" 2>/dev/null > "$secrets_file" || true
if [ -s "$secrets_file" ]; then
  fail "secrets potentiels détectés :"
  sed 's/^/    /' "$secrets_file" | head -20
else
  ok "aucun secret en clair détecté"
fi
rm -f "$secrets_file"

# 4. URL de production en dur
info "4. URL de production en dur"
prod_file="$(mktemp)"
eval "find '$ROOT' -type d $FIND_EXPR -type f -not -path '*/.git/*' -print0" 2>/dev/null \
  | xargs -0 grep -rInE "$PROD_URL_RE" 2>/dev/null > "$prod_file" || true
if [ -s "$prod_file" ]; then
  warn "URL(s) de prod en dur (à externaliser en variable d'env) :"
  sed 's/^/    /' "$prod_file" | head -20
else
  ok "aucune URL de prod en dur"
fi
rm -f "$prod_file"

# 5. Données réelles dans les fixtures
info "5. Données réelles (SIRET/IBAN/emails internes) dans les fixtures"
fixtures_file="$(mktemp)"
eval "find '$ROOT' -type d $FIND_EXPR -type f \( -path '*fixture*' -o -path '*test*' -o -path '*seed*' -o -name '*.json' \) -print0" 2>/dev/null \
  | xargs -0 grep -rInE "$SIRET_RE|$IBAN_RE|$EMAIL_RE" 2>/dev/null > "$fixtures_file" || true
if [ -s "$fixtures_file" ]; then
  fail "données réelles potentielles dans les fixtures/tests :"
  sed 's/^/    /' "$fixtures_file" | head -20
else
  ok "aucune donnée réelle détectée dans les fixtures"
fi
rm -f "$fixtures_file"

echo
if [ "$STATUS" -eq 0 ]; then
  ok "Conformité : OK"
else
  fail "Conformité : anomalies détectées (voir ci-dessus)"
fi
exit "$STATUS"

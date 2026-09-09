#!/usr/bin/env bash
# tests/s68_albert_base_url.sh : S68 (T1.9, AC-R051).
# AC_ALBERT_BASE_URL est-elle honorée là où le provider est câblé, écrite en
# clair, et conservée par un update ? Bac à sable jetable, confirm et curl
# stubés, donc ni question ni réseau. bash 3.2.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$SELF_DIR/lib"
REAL_HOME="$HOME"
DEFAULT_URL="https://albert.api.etalab.gouv.fr/v1"
CUSTOM_URL="https://proxy.interne.test/v1"
FAIL=0

pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; }

# --- Snapshot AVANT (non-pollution de la machine hôte) --------------------------
REAL_ZSHENV="$REAL_HOME/.zshenv"
REAL_BEFORE=""
[ -e "$REAL_ZSHENV" ] && REAL_BEFORE="$(cksum "$REAL_ZSHENV" 2>/dev/null || true)"

command -v jq >/dev/null 2>&1 || { echo "S68 : jq absent, test ignoré (le merge et le catalogue en dépendent)."; exit 0; }

# --- Sandbox jetable -------------------------------------------------------------
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

echo "S68 : AC_ALBERT_BASE_URL surchargeable (sandbox: $SB)"
echo

# --- 1. Défaut inchangé quand la variable est absente ---------------------------
got="$(env -u AC_ALBERT_BASE_URL bash -c 'source "$1/ui.sh"; printf "%s" "$AC_ALBERT_BASE_URL"' _ "$LIB_DIR")"
[ "$got" = "$DEFAULT_URL" ] \
  && pass "défaut sans variable : $DEFAULT_URL" \
  || fail "défaut sans variable : attendu $DEFAULT_URL, obtenu $got"

# --- 2. Surcharge honorée, slash final normalisé --------------------------------
got="$(AC_ALBERT_BASE_URL="$CUSTOM_URL/" bash -c 'source "$1/ui.sh"; printf "%s" "$AC_ALBERT_BASE_URL"' _ "$LIB_DIR")"
[ "$got" = "$CUSTOM_URL" ] \
  && pass "surcharge honorée, slash final retiré" \
  || fail "surcharge : attendu $CUSTOM_URL, obtenu $got"

# --- Environnement commun aux cas suivants ---------------------------------------
export HOME="$SB/home"
mkdir -p "$HOME"
export SELF_DIR LIB_DIR AGENT_VM_DIR="$SB/vm" AC_VM_CPUS=4 AC_VM_MEMORY=8 AC_VM_DISK=32 DRY_RUN=0
export AC_ALBERT_BASE_URL="$CUSTOM_URL"
export ZSHENV="$HOME/.zshenv"
export ALBERT_API_KEY="cle-de-test-non-reelle"

# shellcheck source=../lib/ui.sh
source "$LIB_DIR/ui.sh"
# shellcheck source=../lib/phases.sh
source "$LIB_DIR/phases.sh"

# Une fonction shell prime sur le binaire du PATH, curl compris.
CURL_URL_LOG="$SB/curl.url"
ANSWER=1
confirm() { return "$ANSWER"; }
curl() {
  local a
  for a in "$@"; do
    case "$a" in http*) printf '%s\n' "$a" >> "$CURL_URL_LOG" ;;
    esac
  done
  printf '%s' '{"data":[{"id":"deepseek-v4-flash"}]}'
}

# baseurl_of <fichier> : baseURL déclaré du provider albert.
baseurl_of() { jq -r '.provider.albert.options.baseURL' "$1"; }

# --- 3. Scaffold frais (repli par concaténation) ---------------------------------
mkdir -p "$SB/projet-neuf"
cd "$SB/projet-neuf"
ANSWER=1  # tous les MCP refusés
scaffold_opencode_json >/dev/null 2>&1
got="$(baseurl_of opencode.json)"
[ "$got" = "$CUSTOM_URL" ] \
  && pass "scaffold frais : baseURL surchargée dans opencode.json" \
  || fail "scaffold frais : attendu $CUSTOM_URL, obtenu $got"
if grep -q '{env:AC_ALBERT_BASE_URL}' opencode.json; then
  fail "scaffold frais : URL laissée en {env:...}, elle n'atteindrait pas la VM"
else
  pass "scaffold frais : valeur écrite en clair, pas de {env:...}"
fi

# --- 4. Merge jq dans un opencode.json existant sans provider Albert -------------
mkdir -p "$SB/projet-existant"
cd "$SB/projet-existant"
cat > opencode.json <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {"scaleway": {"npm": "@ai-sdk/openai-compatible"}},
  "mcp": {"data-gouv": {"type": "remote", "url": "https://mcp.data.gouv.fr/mcp", "enabled": true}}
}
JSON
ANSWER=0  # merge accepté
scaffold_opencode_json >/dev/null 2>&1
got="$(baseurl_of opencode.json)"
[ "$got" = "$CUSTOM_URL" ] \
  && pass "merge jq : baseURL surchargée" \
  || fail "merge jq : attendu $CUSTOM_URL, obtenu $got"
[ "$(jq -r '.provider.scaleway.npm' opencode.json)" = "@ai-sdk/openai-compatible" ] \
  && [ "$(jq -r '.mcp["data-gouv"].enabled' opencode.json)" = "true" ] \
  && pass "merge jq : provider tiers et MCP existants préservés" \
  || fail "merge jq : le merge a écrasé le provider tiers ou les MCP"

# --- 5. Non-régression `albert-code update` --------------------------------------
# Variable remise au défaut : seul le fichier porte l'URL, comme un update nu.
jq '.provider.albert.models["albert-large"] = {"name": "périmé"}' opencode.json > tmp.json && mv tmp.json opencode.json
AC_CATALOG_IDS="deepseek-v4-flash"
ANSWER=0  # réparation acceptée
AC_ALBERT_BASE_URL="$DEFAULT_URL"
repair_stale_provider_albert "./opencode.json" >/dev/null 2>&1
got="$(baseurl_of opencode.json)"
[ "$got" = "$CUSTOM_URL" ] \
  && pass "update/réparation : baseURL personnalisée conservée" \
  || fail "update/réparation : baseURL rétablie au défaut ($got)"
[ "$(jq -r '.provider.albert.models | has("albert-large")' opencode.json)" = "false" ] \
  && pass "update/réparation : identifiant périmé retiré, la réparation a bien eu lieu" \
  || fail "update/réparation : identifiant périmé non retiré, le cas n'a pas été exercé"

# --- 6. Le catalogue suit le baseURL du projet ------------------------------------
# Toujours sans la variable : c'est le fichier du projet qui décide.
: > "$CURL_URL_LOG"
fetch_albert_catalog >/dev/null 2>&1
got="$(cat "$CURL_URL_LOG" 2>/dev/null || true)"
[ "$got" = "$CUSTOM_URL/models" ] \
  && pass "catalogue : le baseURL du projet prime sur la variable" \
  || fail "catalogue : attendu $CUSTOM_URL/models, obtenu ${got:-aucun appel}"

# --- 7. Sans opencode.json, le catalogue suit la variable -------------------------
mkdir -p "$SB/hors-projet"
cd "$SB/hors-projet"
AC_ALBERT_BASE_URL="https://autre.test/v1"
: > "$CURL_URL_LOG"
fetch_albert_catalog >/dev/null 2>&1
got="$(cat "$CURL_URL_LOG" 2>/dev/null || true)"
[ "$got" = "https://autre.test/v1/models" ] \
  && pass "catalogue hors projet : la variable est utilisée" \
  || fail "catalogue hors projet : attendu https://autre.test/v1/models, obtenu ${got:-aucun appel}"

# --- Snapshot APRÈS (non-pollution) ----------------------------------------------
cd "$SELF_DIR"
HOME="$REAL_HOME"
REAL_AFTER=""
[ -e "$REAL_ZSHENV" ] && REAL_AFTER="$(cksum "$REAL_ZSHENV" 2>/dev/null || true)"
[ "$REAL_BEFORE" = "$REAL_AFTER" ] \
  && pass "non-pollution : le ~/.zshenv de la machine est inchangé" \
  || fail "non-pollution : le ~/.zshenv de la machine a été modifié"

echo
if [ "$FAIL" -eq 0 ]; then
  printf '\033[32mS68 OK\033[0m\n'
else
  printf '\033[31mS68 ÉCHEC\033[0m\n'
fi
exit "$FAIL"

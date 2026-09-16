#!/usr/bin/env bash
# tests/check_registry_consistency.sh — garde-fou cohérence registre + validité workflows (T14.4).
# Empêche deux familles d'erreurs déjà croisées en 24 h sur ce dépôt :
#   - collisions d'identifiants : AC-R### cité (BACKLOG.md / TESTS.md) sans ligne dans le tableau
#     de FEEDBACK.md, AC-R### en double, ou ligne « | AC-R### | » hors du tableau du « ## Registre » ;
#     S## cité dans BACKLOG.md sans titre « ## S## » dans TESTS.md, ou titre en double.
#   - workflow invalide : .github/workflows/*.yml non-YAML valide, ou étape pointant vers un
#     fichier tests/ inexistant (le « deux-points non quoté dans un name: » qui a produit un run
#     en échec avec zéro job n'est pas attrapé par GitHub : on le vérifie ici).
# Lecture seule — ne modifie rien. Compatible bash 3.2.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SELF_DIR"

FAIL=0

fail() {
  printf '✗ %b\n' "$1"
  FAIL=1
}

# ---------------------------------------------------------------------------
# 1) Identifiants AC-R### dans FEEDBACK.md (tableau qui suit « ## Registre »)
# ---------------------------------------------------------------------------
# Rows « | AC-R### | » présentes dans FEEDBACK.md, dans l'ordre, avec le numéro.
# On conserve l'ordre d'apparition pour détecter aussi les doubles (lignes 2+).

FB="FEEDBACK.md"

grep_outside() {
  # sort sur les lignes « | AC-R### | » situées STRICTEMENT avant le titre « ## Registre ».
  awk '
    /^## Registre$/ { in_reg=1 }
    !in_reg && /^\| AC-R[0-9][0-9][0-9] \|/ { print $0 }
  ' "$FB"
}
if grep_outside | grep -qE 'AC-R[0-9]{3}'; then
  fail "Ligne(s) « | AC-R### | » présentes HORS du tableau qui suit « ## Registre » dans $FB :"
  grep_outside | sed 's/^/    /' >&2
fi

# Chaque id du tableau, dans l'ordre strict d'apparition (double => deux entrées adjacentes).
ids_in_order="$(awk '
  /^## Registre$/ { in_reg=1; next }
  in_reg && /^\| AC-R[0-9][0-9][0-9] \|/ {
    if (match($0, /AC-R[0-9][0-9][0-9]/)) print substr($0, RSTART, RLENGTH)
  }
' "$FB")"

prev=""
while IFS= read -r id; do
  [ -z "$id" ] && continue
  if [ "$id" = "$prev" ]; then
    fail "AC-R### en double dans le tableau de $FB : $id"
  fi
  prev="$id"
done <<< "$ids_in_order"

# ---------------------------------------------------------------------------
# 2) AC-R### cités dans BACKLOG.md / TESTS.md doivent exister dans le tableau
# ---------------------------------------------------------------------------
# Ensemble des ids du tableau.
table_ids="$(printf '%s\n' "$ids_in_order" | sort -u)"

check_acr_cited() {
  local file="$1"
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    if ! grep -q "$id" <<< "$table_ids"; then
      fail "$file cite $id mais aucune ligne « | $id | » dans le tableau de $FB (après « ## Registre »)."
    fi
  done < <(grep -oE 'AC-R[0-9]{3}' "$file" | sort -u)
}

check_acr_cited BACKLOG.md
check_acr_cited TESTS.md

# ---------------------------------------------------------------------------
# 3) Scénarios TESTS.md : titres uniques + références BACKLOG.md
# ---------------------------------------------------------------------------
# Un scénario se repère à son titre « ## <id> — … », l'id pouvant être numérique
# (« ## S41 — … ») ou non numérique (« ## S-ctx-2 — … », famille Context7).
scenario_title_ids="$(grep -E '^## (S[0-9]+|S-ctx-[0-9]+) ' TESTS.md \
  | sed -E 's/^## ((S-ctx-[0-9]+)|(S[0-9]+)) .*/\1/' | sort -u)"

# Titre S## / S-ctx-## en double dans TESTS.md (deux sections porteraient le même id).
prev=""
while IFS= read -r id; do
  [ -z "$id" ] && continue
  if [ "$id" = "$prev" ]; then
    fail "Titre « ## $id » en double dans TESTS.md."
  fi
  prev="$id"
done <<< "$(grep -E '^## (S[0-9]+|S-ctx-[0-9]+) ' TESTS.md \
  | sed -E 's/^## ((S-ctx-[0-9]+)|(S[0-9]+)) .*/\1/')"

# Références de scénarios dans BACKLOG.md.
# On ne contrôle QUE les références qui prétendent désigner un scénario EXISTANT,
# c'est-à-dire celles qui pointent explicitement un fichier TESTS.md. Une DoD qui
# annonce un scénario à créer (forme « → scénario TESTS.md à créer ») est un ticket
# ouvert, pas une incohérence : ces lignes sont ignorées sans liste d'exceptions.
# Les identifiants pris entre parenthèses sont des annotations (historique, ex.
# « ex-T1.6/S22 », ou consigne de nettoyage « (retirer S7, S6) »), pas des références
# de scénario : elles ne sont pas validées.
while IFS= read -r line; do
  case "$line" in
    *"à créer"*) continue ;;
  esac
  # Retire les groupes « ( … ) » avant d'extraire les références.
  stripped="$(printf '%s\n' "$line" | sed -E 's/\([^)]*\)//g')"
  for s in $(printf '%s' "$stripped" | grep -oE 'S-ctx-[0-9]+|S[0-9]{1,3}'); do
    if ! grep -qx "$s" <<< "$scenario_title_ids"; then
      fail "BACKLOG.md référence le scénario $s (via TESTS.md) mais aucun titre « ## $s » dans TESTS.md."
    fi
  done
done < <(grep -nE 'TESTS\.md' BACKLOG.md)

# ---------------------------------------------------------------------------
# 4) Workflows : YAML valide + étapes pointant vers un fichier tests/ existant
# ---------------------------------------------------------------------------
# Chaque *.yml de .github/workflows est parsé en YAML (python3 + PyYAML). Si python3 ou le
# module yaml est absent, on SAUTE ce contrôle avec un message explicite, comme S68 le fait
# pour jq, plutôt que d'échouer.
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  for wf in .github/workflows/*.yml; do
    [ -f "$wf" ] || continue
    if ! python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1]))' "$wf" 2>/tmp/ac_yaml_err; then
      fail "Workflow $wf n'est pas un YAML valide :\n    $(grep -m1 . /tmp/ac_yaml_err 2>/dev/null || echo 'erreur de parsing')"
      continue
    fi
    # Chaque étape qui reçoit `run: bash tests/...` doit viser un fichier existant.
    # On suit le pattern exact des étapes existantes (ex. « run: bash tests/check_no_personal_paths.sh »).
    while IFS= read -r target; do
      [ -z "$target" ] && continue
      if [ ! -f "$target" ]; then
        fail "Workflow $wf exécute « $target » mais ce fichier n'existe pas."
      fi
    done < <(python3 - "$wf" <<'PY'
import sys, yaml
with open(sys.argv[1]) as fh:
    data = yaml.safe_load(fh)
for job in (data.get('jobs') or {}).values():
    for step in (job.get('steps') or []):
        run = step.get('run') or ''
        if run.startswith('bash tests/'):
            print(run.split()[1])
PY
)
  done
else
  echo "  (python3 / module yaml absent — contrôle YAML des workflows sauté, YAML non vérifié.)"
fi

# ---------------------------------------------------------------------------
if [ "$FAIL" -eq 1 ]; then
  echo >&2
  echo "✗ Incohérences détectées ci-dessus." >&2
  echo "  Pour AC-R### hors tableau : déplace/insère la ligne dans le tableau qui suit « ## Registre » de FEEDBACK.md, à sa place dans l'ordre des identifiants." >&2
  echo "  Pour AC-R### cité sans ligne : ajoute une ligne « | AC-R### | … | » reconstituée depuis le ticket et les scénarios qui la citent (ne rien inventer)." >&2
  echo "  Pour AC-R### en double : fusionne les deux lignes, garde l'id unique." >&2
  echo "  Pour S## / S-ctx-## cité via TESTS.md sans titre : crée la section, ou fait pointer le ticket vers un scénario existant qui couvre le comportement." >&2
  echo "  Pour S## / S-ctx-## en double : renumérote le titre en doublon." >&2
  echo "  Pour workflow invalide / étape orpheline : corrige le YAML (quotes autour d'un deux-points dans un name:) ou le chemin d'étape." >&2
  exit 1
fi

echo "✓ Registre cohérent : AC-R### et S## uniques, cités et présents ; workflows YAML valides, étapes pointant vers des fichiers tests/ existants."
exit 0

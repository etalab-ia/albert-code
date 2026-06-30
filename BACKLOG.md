# BACKLOG — albert-code

> Tickets de construction du bundle, ordonnés. À dérouler avec OpenCode.
> Convention : chaque ticket a un **but**, une **définition de done (DoD)** et un renvoi aux scénarios de `TESTS.md`.
> 🔴 bloquant v1 · 🟠 important · 🟡 nice-to-have

---

## EPIC 0 — Spike technique (dé-risquer la chaîne)

### T0.1 🔴 Smoke test chaîne minimale ⏳ (agent-vm non installé)
**But :** prouver que agent-vm + OpenCode + Albert (`Mistral-Medium-3.5-128B`) fonctionnent ensemble.
**Tâches :**
- Installer agent-vm (Lima) ; `agent-vm setup`.
- Config OpenCode minimale avec provider Albert (`@ai-sdk/openai-compatible`, baseURL, `{env:ALBERT_API_KEY}`).
- Dans la VM : `opencode run "écris un hello world en python"` → vérifier réponse + écriture fichier.
**DoD :** un fichier est créé par l'agent dans la VM, via Albert, sans clé en clair. → `TESTS.md` S1.

### T0.2 🔴 Valider une skill + le small_model ⏳ (agent-vm non installé)
**But :** confirmer chargement skill local + bascule modèle.
**Tâches :** placer `react-dsfr` dans `~/.config/opencode/skills/` ; demander une page DSFR ; configurer `small_model = DeepSeek-V4-Flash` et vérifier qu'il est utilisé pour les tâches légères.
**DoD :** page DSFR générée conforme + small_model actif. → `TESTS.md` S2.

---

## EPIC 1 — Config & runtime de référence

### T1.1 🔴 `opencode.json` (provider + MCP + permissions) ✅ implémenté
**But :** config OpenCode canonique du bundle.
**Tâches :**
- `provider.albert` (`@ai-sdk/openai-compatible`, models `Mistral-Medium-3.5-128B` + `DeepSeek-V4-Flash`).
- `model` / `small_model`.
- `mcp` (réf ci-dessous).
- `permission` : `edit`/`bash` raisonnables (allow dans la VM isolée, `deny` sur `git push *` hors VM à débattre), `webfetch: allow`.
- **Portée projet (non-destructif)** : écrire ce fichier à la **racine du projet cible**, PAS dans `~/.config/opencode/`. Le global perso de l'utilisateur (possiblement avec d'autres providers, ex. Scaleway) ne doit jamais être touché. OpenCode fusionne global+projet, projet prioritaire.

Config MCP de référence :
```jsonc
"mcp": {
  "data-gouv": { "type": "remote", "url": "https://mcp.data.gouv.fr/mcp", "enabled": true },
  "context7":  { "type": "remote", "url": "https://mcp.context7.com/mcp", "headers": { "Authorization": "Bearer {env:CONTEXT7_API_KEY}" }, "enabled": true },  // CLÉ API REQUISE
  "playwright": { "type": "local", "command": ["npx", "-y", "@playwright/mcp@latest"], "enabled": true },  // paquet à confirmer
  "chrome-devtools": { "type": "local", "command": ["npx", "-y", "chrome-devtools-mcp@latest"], "enabled": true }  // paquet à confirmer
}
```
- **data.gouv** : confirmé → `https://mcp.data.gouv.fr/mcp` (remote HTTP, lecture publique).
- **context7** : **clé API requise** (https://context7.com/plans) → stockée comme `CONTEXT7_API_KEY` dans `~/.zshenv`. Rendre le MCP **optionnel/skippable** si pas de clé.
- **chrome-devtools** : debug navigateur (DOM, console, réseau, perf). Déjà préinstallé dans la VM agent-vm (mais câblé pour Claude Code) → à déclarer côté OpenCode. Complémentaire de playwright (auto/tests).
- playwright / chrome-devtools : paquets npx à valider au câblage.
**DoD :** `opencode` démarre sans erreur de schéma, les 3 MCP sont listés et connectés (au moins data.gouv répond), Albert répond. → `TESTS.md` S3.

### T1.2 🔴 `.agent-vm.runtime.sh` idempotent ✅ implémenté
**But :** bootstrap reproductible de l'environnement dans la VM.
**Tâches (idempotentes, tester l'état avant chaque action) :**
- Persister `ALBERT_API_KEY` (et baseURL) dans `~/.zshenv` (piège auth shells non-interactifs). Idem `CONTEXT7_API_KEY` si fournie (optionnelle).
- Cloner/`git pull` `etalab-ia/skills` dans `~/.config/opencode/skills/`.
- Installer les serveurs MCP requis (npx/binaire).
- Vérifier OpenCode présent, sinon installer.
- **Non-destructif** : détecter une config agent-vm/OpenCode déjà en place et ne rien écraser (écritures additives uniquement : clone skills, clés `~/.zshenv` si absentes).
**DoD :** 2 exécutions consécutives = la 2e est une suite de no-ops en quelques secondes ; skills à jour après `git pull` ; une config OpenCode perso préexistante (ex. provider Scaleway) reste intacte. → `TESTS.md` S4, S5, S12.

### T1.3 🟠 Synchro skills au boot ✅ implémenté
**But :** garantir des skills toujours fraîches (réponse au « pas de maj auto »).
**DoD :** ajouter une skill dans le repo distant → après reboot VM, elle apparaît dans OpenCode sans action manuelle. → `TESTS.md` S5.

---

## EPIC 2 — Profils & bootstrap (séparation des conventions)

### T2.1 🔴 Structure `profiles/` ✅ implémenté
**But :** isoler physiquement les conventions par contexte.
**Tâches :** créer `profiles/{beta.gouv,lasuite,iae}/AGENTS.md` (+ set de skills + bouts d'`opencode.json` spécifiques). Reprendre `etalab-ia/skills/templates/instructions/{beta.gouv,LaSuite}.md` ; créer le profil `iae` (house style OpenGateLLM). Plus un choix **`autre`** = **aucune convention imposée** (ne copie aucun `AGENTS.md` de profil ; l'utilisateur fournit le sien s'il veut).
**DoD :** 3 profils complets + option `autre` neutre, zéro convention partagée divergente entre eux (commits, package manager, design system). → `TESTS.md` S6.

### T2.2 🔴 `install.sh` / bootstrap qui DEMANDE le contexte ✅ implémenté
**But :** aucun profil par défaut, aucun merge.
**Tâches :** prompt « Quel contexte ? (1) beta.gouv (2) La Suite (3) IAE (4) Autre » → copie le bon `AGENTS.md` + installe le bon set de skills ; **(4) Autre = ne copie rien** (neutre). Refuser de continuer si rien n'est choisi.
**DoD :** choisir beta.gouv → le projet ne contient AUCUNE convention IAE (commits gitmoji/uv absents), et inversement ; choisir Autre → aucun `AGENTS.md` de profil n'est posé. → `TESTS.md` S6, S7.

### T2.3 🟠 Couche universelle commune ✅ implémenté
**But :** factoriser le socle (anglais code / FR UI, RGAA, ANSSI, RGPD, secrets, souveraineté) sans casser l'isolation.
**DoD :** le socle est présent dans les 3 profils, les divergences restent dures par profil. → `TESTS.md` S6.

---

## EPIC 4 — Standards & CI

### T4.1 🟠 Skill `conventions-iae` (dans etalab-ia/skills)
**But :** house style Python/Albert (uv, Ruff `line-length=150`/`py312`/ignores, pytest async unit+intég ≥80 %, Alembic upgrade+downgrade, Makefile/cli.py, PR DoD). PR sur `etalab-ia/skills`.
**DoD :** skill chargée par OpenCode, déclenchée sur projet Python. → `TESTS.md` S9.

### T4.2 🟠 Skill `delivery-standards-beta` (dans etalab-ia/skills)
**But :** scaffold projet conforme beta.gouv (linter + CI/CD + tests + Sentry + OpenAPI + README + /stats + DashLord + footer légal + /accessibilite) + checklist 28 standards.
**DoD :** la skill génère la structure conforme. → `TESTS.md` S9.

### T4.3 🟡 Templates CI `templates/` ✅ implémenté
**But :** reprendre la chaîne sécu OpenGateLLM.
**Tâches :** workflows réutilisables Semgrep + Trivy + CodeQL (HIGH=warn / CRITICAL=block) ; `PULL_REQUEST_TEMPLATE.md` (fusion DoD OpenGateLLM + checklist beta) ; script de conformité (footer légal + /accessibilite + scan secrets/URL prod + données fixtures).
**DoD :** workflows valides, script de conformité exécutable. → `TESTS.md` S10.

---

## EPIC 5 — Distribution

### T5.1 🔴 README copier-coller (non-techs) ✅ implémenté
**But :** guide d'install pas-à-pas. Réutiliser l'UX de `Produits/Albert Code/MVP/Open code + Ollama/spec.md`.
**DoD :** un non-tech installe et lance un premier projet sans aide. → `TESTS.md` S11.

### T5.2 🟠 Test sur machine vierge + early adopters
**But :** valider hors poste de Benoit.
**DoD :** install réussie par ≥1 early adopter (Thomas / Simon / Eric / Chaïb / Julien).

### T5.3 🟡 Publication `etalab-ia/albert-code`
**DoD :** repo public, LICENSE MIT, CI verte.

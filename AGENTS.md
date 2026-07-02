# AGENTS.md — albert-code

---

## 1. Le projet en bref

### Le problème
L'IA bouleverse le développement. Les agents publics (devs et aussi des non-devs) utilisent déjà des outils IA commerciaux (Claude Code, Cursor, Copilot) **sans cadre, sans souveraineté, sans sandbox** — du shadow IT généralisé. L'État n'a pas d'alternative à proposer.

### La vision
**Albert Code** = un **meta-bundle d'agentic coding souverain** : en une commande, un agent public obtient un assistant de code IA isolé, alimenté par le Socle Interministériel d'IA Générative et ses modèles souverains via AlbertAPI, avec les standards de l'administration (DSFR, accessibilité, sécurité) déjà embarqués.

Ce n'est **pas un IDE ni un fork** : c'est de l'**orchestration mince** (scripts + config + docs) qui assemble des briques existantes :

| Brique | Rôle | Source |
|---|---|---|
| **agent-vm** | Sandbox d'isolation (VM Lima jetable, mode autonome sûr) | `github.com/sylvinus/agent-vm` |
| **OpenCode** | Harness unique (assistant de code terminal) | `opencode.ai` |
| **Albert API** | Provider LLM souverain (OpenAI-compatible) | `albert.api.etalab.gouv.fr` |
| **Skills État** | Connaissances métier (DSFR, RGAA, sécurité, data.gouv) | `github.com/etalab-ia/skills` |
| **MCP** | Connecteurs clés : data.gouv, context7, playwright, chrome-devtools | — |
| **Profils** | Conventions par contexte (beta.gouv / La Suite / IAE / autre) | `profiles/` |

### Pour qui
Agents publics : devs en ministère, prototypeurs, équipes de startup d'état. Le bundle doit marcher **autant pour un dev confirmé que pour un non-tech** (cf. `README.md`).

### Positionnement (ce que c'est / ce que ce n'est pas)
- ✅ Un assembleur souverain, mince, reproductible, qui se branche sur l'existant.
- ❌ Pas un nouvel outil à apprendre, pas un IDE, pas un modèle, pas un fork d'OpenCode.

---

## 2. Comment travailler dans ce dépôt (méthode)

Les documents du dépôt forment un système. **Respecte cette boucle :**

| Document | Rôle | Quand le lire / l'écrire |
|---|---|---|
| `AGENTS.md` (ce fichier) | Le **pourquoi** + les règles + l'archi cible | Toujours, en premier |
| `BACKLOG.md` | Le **quoi faire** : epics → tickets ordonnés (🔴🟠🟡) avec Definition of Done | Choisir le prochain ticket ici |
| `TESTS.md` | Le **comment valider** : scénarios (préconditions → étapes → attendu) | Avant de clore un ticket |
| `README.md` | Le **livrable utilisateur** (onboarding non-tech) | À tenir à jour quand le comportement change |
| `FEEDBACK.md` | Le **pourquoi** : registre des retours utilisateurs codifiés (`AC-R###`) | Consulter pour la genèse d'un ticket / y consigner un nouveau retour |
| `docs/PLAN.md` | Le **contexte complet** (décisions, analyses, références) | Pour comprendre l'historique du projet |

**Boucle de travail attendue de l'agent :**
1. Lire `docs/PLAN.md` pour avoir l'historique complet
2. Lire `BACKLOG.md`, prendre le **prochain ticket non fait** dans l'ordre (commencer par l'EPIC 0).
3. Lire les fichiers concernés avant d'éditer.
4. Tout nouveau retour utilisateur identifié pendant le build est d'abord consigné dans `FEEDBACK.md` (`AC-R###`, 🆕) avant d'être éventuellement backlogué.
5. Implémenter le ticket en respectant sa **DoD**.
6. Valider avec le ou les **scénarios `TESTS.md`** référencés par le ticket (passer le statut ☐ → ✅).
7. Si le ticket porte un renvoi `<- AC-R###`, mettre à jour le finding correspondant dans `FEEDBACK.md` (Statut → ✅ traité, colonne Renvoi vers le ticket).
8. Mettre à jour `README.md` si le comportement utilisateur change.
9. Commit atomique (Conventional Commits, cf. §6).

> Ne traite pas un ticket sans avoir vérifié sa DoD ET son scénario de test. Si un ticket est ambigu, demande avant de coder.

---

## 3. Architecture cible du dépôt

À construire au fil du backlog (ne pas tout créer d'un coup) :

```
albert-code/
├── README.md                      # Guide utilisateur — livrable n°1 (FAIT)
├── AGENTS.md                      # Ce fichier (FAIT)
├── BACKLOG.md                     # Tickets de construction (FAIT)
├── TESTS.md                       # Scénarios de validation (FAIT)
├── FEEDBACK.md                    # Registre des retours utilisateurs (FAIT)
├── LICENSE                        # MIT
├── docs/
│   └── PLAN.md                     # Contexte & décisions (FAIT)
├── install.sh                     # Wizard d'installation (point d'entrée unique)
├── uninstall.sh                   # Désinstallation propre
├── lib/                           # Fonctions bash partagées (banner, ui, checks)
├── config/
│   └── opencode.template.json     # Config OpenCode : provider Albert + MCP + permissions
├── runtime/
│   └── agent-vm.runtime.sh        # Runtime de référence (provider + sync skills + MCP), idempotent
├── profiles/                      # Un dossier par contexte — isolation physique
│   ├── beta.gouv/AGENTS.md
│   ├── lasuite/AGENTS.md
│   └── iae/AGENTS.md
└── templates/
    ├── PULL_REQUEST_TEMPLATE.md   # Fusion DoD OpenGateLLM + checklist beta
    └── .github/workflows/         # CI réutilisable : semgrep, trivy, codeql
```

**Repo cible :** `github.com/etalab-ia/albert-code` · **Licence :** MIT.

---

## 4. Stack de ce dépôt

| Élément | Choix |
|---|---|
| Langage principal | **Bash** (bootstrap/runtime), **JSON/JSONC** (config OpenCode), **Markdown** (profils, docs) |
| Cible OS | macOS + Linux (parc agents). Pas de Windows en v1 |
| Dépendances hôte | Lima (via agent-vm), Node (pour `npx`/MCP), git |
| Pas de | build step, framework applicatif, dépendance propriétaire |

---

## 5. Règles de comportement (agent)

1. **Think before coding.** Lis les fichiers concernés avant d'éditer. Pas de refactor non demandé.
2. **Surgical changes.** Modifie uniquement ce qui est demandé ; ne reformate pas le reste.
3. **Simplicity first.** Le bundle reste mince et lisible. Préfère 30 lignes de bash claires à une usine.
4. **Idempotence obligatoire.** Tout script (`install.sh`, `runtime/agent-vm.runtime.sh`) doit être relançable sans casser : tester l'état (`command -v`, `dpkg -s`, présence de fichier) avant chaque action. Référence : `datagouv/apistration#70`.
5. **Souveraineté.** Préférer libre + souverain. Signaler toute dépendance propriétaire/non-souveraine ajoutée.
6. **Le test fait foi.** Un ticket n'est « fait » que si son scénario `TESTS.md` passe.
7. **Retours utilisateurs → `FEEDBACK.md` d'abord.** Tout retour identifié pendant le build est consigné dans `FEEDBACK.md` (anonymisé, `AC-R###`, 🆕) avant d'être backlogué. Un ticket issu d'un retour cite son finding via `<- AC-R###`. Ne jamais mettre de nom complet, verbatim nominatif ou URL Tchap interne dans le dépôt.

---

## 6. Conventions techniques

### Bash
- `bash` 3.2 compatible (macOS), `set -euo pipefail`, fonctions nommées (`install_opencode()`, `sync_skills()`…).
- Messages utilisateur en **français**, tutoiement, une action = un retour. Couleurs : vert/jaune/rouge/bleu.
- Jamais de `sudo` sans explication. Pas de chemins absolus en dur. Pas de dépendance Homebrew obligatoire (installeurs standalone).

### Secrets & données (NON négociable)
- **Jamais** de secret / clé API / token / URL de prod en clair dans le repo ou les commits. Lire depuis l'environnement (`{env:ALBERT_API_KEY}`) ou `~/.zshenv`.
- **Clé dédiée par projet** : recommander une clé Albert révocable par usage, pas la clé perso maître (une fuite est contenue et rotable).
- **Risque d'exfiltration** : l'IA peut lire du contenu malveillant (prompt-injection). La VM isole du réseau hôte, mais l'agent peut tenter des appels réseau. Mitigations : clé dédiée révocable, permissions bash durcies (`sudo` / `git push --force` = deny), validation humaine de chaque PR.
- **Jamais** de données réelles dans des exemples/fixtures.
- gitleaks recommandé en pre-commit ; ne jamais contourner avec `--no-verify`.
- `chmod 600` sur tout fichier contenant une clé (`~/.zshenv`, `~/.agent-vm/runtime.sh`).
- **Notes de validation** (`TESTS.md`, tickets, commits) : anonymiser les chemins absolus / username ; ne jamais coller de sortie brute contenant `/Users/<toi>` ou `/home/<toi>`. Un garde-fou CI (`tests/check_no_personal_paths.sh`, T4.5) le vérifie à chaque push/PR.

### Git
- Commits **Conventional Commits** : `type(scope): message` (`feat|fix|docs|refactor|chore|test`). Message qui explique le *pourquoi*. Squash des commits intermédiaires avant push.
- Branches `feat/…`, `fix/…`. PR avec checklist (`templates/PULL_REQUEST_TEMPLATE.md`).

---

## 7. Spécificités OpenCode (à connaître pour builder juste)

- **Config** : `opencode.json` (racine projet) + `~/.config/opencode/opencode.json` (global), fusionnés. `$schema: https://opencode.ai/config.json`. Substitution `{env:VAR}` / `{file:path}`.
- **Provider Albert** : `provider.albert.npm = "@ai-sdk/openai-compatible"`, `options.baseURL = "https://albert.api.etalab.gouv.fr/v1"`, `options.apiKey = "{env:ALBERT_API_KEY}"`, `models` listant `Mistral-Medium-3.5-128B` et `DeepSeek-V4-Flash`. Puis `model = "albert/Mistral-Medium-3.5-128B"`, `small_model = "albert/DeepSeek-V4-Flash"`.
- **Règles** : OpenCode lit `AGENTS.md`. La clé `instructions` accepte fichiers, globs ET URLs (timeout 5 s).
- **MCP** : clé `mcp.<nom>` type `local` (`command`) ou `remote` (`url`+`headers`). data.gouv = remote `https://mcp.data.gouv.fr/mcp` (lecture publique). **context7 = remote nécessitant une clé API** (https://context7.com/plans → `CONTEXT7_API_KEY` dans `~/.zshenv`, passée en header) ; rendre ce MCP optionnel si pas de clé. playwright = local. chrome-devtools = local (`npx chrome-devtools-mcp@latest`) — déjà préinstallé dans agent-vm mais à déclarer côté OpenCode.
- **Skills = dossiers locaux scannés uniquement.** Chemins : `.opencode/skills/`, `.agents/skills/`, `.claude/skills/` (projet) ; `~/.config/opencode/skills/` (global). Format `SKILL.md` + frontmatter (`name` kebab = dossier, `description`). **La clé `skills` / chargement par URL n'existe PAS dans OpenCode** → ne pas l'utiliser (contrairement au repo DNUM-MI).
- **Permissions** : `read/edit/bash/skill/webfetch/websearch/task` = `allow|ask|deny`, patterns, dernière règle gagnante.
- **Ne pas créer de `CLAUDE.md`** : s'il coexiste avec `AGENTS.md`, OpenCode l'ignore (source de confusion).

---

## 8. Synchro des skills (décision d'archi)

Les skills ne se mettent **PAS** à jour toutes seules. Mécanisme retenu : **cloner `etalab-ia/skills` dans `~/.config/opencode/skills/` et `git pull` dans `runtime/agent-vm.runtime.sh`** → skills fraîches à chaque démarrage de VM. Ne pas reposer sur un snapshot `npx skills add` figé.

---

## 9. Profils (séparation des conventions — NON négociable)

Un utilisateur **ne doit jamais hériter du mauvais jeu de conventions**. Isolation **physique** : `profiles/<contexte>/AGENTS.md`, un fichier par contexte, **aucun merge, aucun défaut implicite**. Le bootstrap **demande le contexte** et copie le bon profil.

- `profiles/beta.gouv/` — commits FR, pnpm, DSFR, skills react-dsfr/rgaa/securite-developpement/datagouv-apis.
- `profiles/lasuite/` — commits gitmoji EN, yarn, La Suite UI Kit, Django REST.
- `profiles/iae/` — house style OpenGateLLM (uv, Ruff, FastAPI, pytest, Alembic), skill conventions-iae.
- **`autre`** — **aucune convention imposée** : ne copie aucun `AGENTS.md` de profil. L'utilisateur fournit le sien (ou aucun). Albert Code reste neutre.

Source des profils existants : `etalab-ia/skills/templates/instructions/` (`beta.gouv.md`, `LaSuite.md`).

---

## 10. À NE PAS faire

- Ne pas supporter d'autre harness que **OpenCode** (ni Vibe, ni Claude Code).
- **Ne pas écraser une config OpenCode / agent-vm existante.** La config provider du bundle est de **portée projet** (`opencode.json` à la racine du projet cible), jamais le global perso de l'utilisateur (qui peut contenir d'autres providers, ex. Scaleway). Écritures globales (dossier skills, `~/.zshenv`) = **additives + idempotentes** (détecter avant d'écrire).
- Ne pas utiliser de modèle Albert autre que `Mistral-Medium-3.5-128B` (principal) et `DeepSeek-V4-Flash` (small).
- Ne pas créer de défaut implicite de profil ni merger les conventions de deux contextes.
- Ne pas s'appuyer sur la clé `skills`/`skills.urls` (non documentée OpenCode).

---

## 11. Références

- **Plan produit** : `docs/PLAN.md`
- Doc OpenCode : https://opencode.ai/docs/fr
- agent-vm : https://github.com/sylvinus/agent-vm
- Skills État : https://github.com/etalab-ia/skills · templates d'instructions : `…/tree/main/templates/instructions`
- Albert API : https://albert.api.etalab.gouv.fr · doc https://doc.incubateur.net/alliance/albert-api
- Inspirations : `dnum-mi/starter-kit-opencode`

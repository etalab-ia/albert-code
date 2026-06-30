# Albert Code — Plan & contexte

> Contexte produit et décisions d'architecture du bundle. Document de référence interne au dépôt, lu par les contributeurs et l'agent de build.
> Pour les règles de construction, voir [`AGENTS.md`](../AGENTS.md) ; pour les tâches, [`BACKLOG.md`](../BACKLOG.md) ; pour la validation, [`TESTS.md`](../TESTS.md).

## Vision

Albert Code est un **meta-bundle d'agentic coding souverain** pour les agents publics. En une commande, il fournit un assistant de code IA isolé, alimenté par l'IA de l'État, avec les standards de l'administration déjà embarqués.

Ce n'est pas un IDE ni un fork : c'est de l'orchestration mince (scripts + config + docs) qui assemble des briques existantes.

## Le problème

L'IA bouleverse le développement (prototypage comme delivery). Les agents publics, devs comme non-devs, utilisent déjà des outils IA commerciaux (Claude Code, Cursor, Copilot) sans cadre, sans souveraineté, sans sandbox : du shadow IT généralisé. L'État n'a pas d'alternative à proposer. 12 entretiens utilisateurs convergent sur ce constat et sur le besoin d'un package souverain avec standards intégrés.

## Pourquoi maintenant

Deux tentatives de bundle de mars 2026 étaient en pause pour deux raisons, aujourd'hui levées :

| Blocage mars 2026 | Statut |
|---|---|
| Modèles Albert trop faibles (GPT-OSS 120B échoue sur multi-fichiers / react-dsfr) | Levé : `Mistral-Medium-3.5-128B` et `DeepSeek-V4-Flash` disponibles sur Albert API |
| Mistral Medium plantait sur le tool calling (`strict: null` rejeté par Albert) | Levé, prouvé par 2 PR réelles |

Preuves de bout en bout (agent souverain produisant une vraie PR) :
- [observatoire-spdr#2](https://github.com/benoitvx/observatoire-spdr/pull/2) — durcissement sécurité (en-têtes HTTP, HSTS, conformité ANSSI) + optimisation cache, sur un projet Next.js réel.
- [etalab-ia/skills#25](https://github.com/etalab-ia/skills/pull/25) — refactorisation de skill.

L'hypothèse cœur du produit est validée. Reste à industrialiser et distribuer.

## Cibles utilisateurs

Agents publics : devs en ministère, PM/CPO prototypeurs, équipes incubées (ALLiaNCE). Le bundle doit fonctionner autant pour un dev confirmé que pour un profil non technique (cf. [`README.md`](../README.md)).

## Stack verrouillée

| Brique | Choix | Notes |
|---|---|---|
| Sandbox | [agent-vm](https://github.com/sylvinus/agent-vm) (Lima) | Code sous `~/Dev/` (chemin sans espace requis). Clé Albert persistée dans `~/.zshenv` |
| Harness | **OpenCode uniquement** | Pas de Vibe, pas de Claude Code |
| Provider | Albert API via `@ai-sdk/openai-compatible` | `model` = `Mistral-Medium-3.5-128B`, `small_model` = `DeepSeek-V4-Flash` |
| Skills | [etalab-ia/skills](https://github.com/etalab-ia/skills) | Dossiers locaux scannés (voir Synchro des skills) |
| MCP v1 | data.gouv, context7, playwright, chrome-devtools | Pas de MCP Docs La Suite en v1 |
| Conventions | Fichier `AGENTS.md` (pas `CLAUDE.md`) | OpenCode ignore `CLAUDE.md` si `AGENTS.md` présent |
| Repo | `github.com/etalab-ia/albert-code` | Archi inspirée de DNUM-MI + template-proto |

## Architecture

```
agent-vm (Lima)  ->  sandbox, isolation noyau, mode autonome sûr
│   pas d'accès SSH / credentials / cookies de l'hôte
│   runtime.sh : provider Albert (~/.zshenv) + git pull skills + MCP
│
└── OpenCode
    ├── Provider  = Albert API (@ai-sdk/openai-compatible)
    │     model = Mistral-Medium-3.5-128B, small_model = DeepSeek-V4-Flash
    ├── AGENTS.md = profil choisi au bootstrap (beta.gouv | lasuite | iae | autre)
    ├── Skills    = ~/.config/opencode/skills/ (clone etalab-ia/skills, pull au boot)
    └── MCP       = data.gouv, context7, playwright, chrome-devtools
```

## Décisions clés (et leur rationale)

### OpenCode, pas Claude Code
OpenCode lit `AGENTS.md` nativement (standard inter-outils [agents.md](https://agents.md)) et ignore `CLAUDE.md` si les deux existent. Provider custom via `@ai-sdk/openai-compatible` (parfait pour un endpoint OpenAI-compatible comme Albert). Le build du bundle se fait lui-même avec OpenCode.

### Synchro des skills
Les skills OpenCode sont des dossiers locaux scannés ; il n'existe pas de clé `skills` ni de chargement par URL dans la doc OpenCode (le `skills.urls` du repo DNUM-MI n'est pas documenté, on ne s'en sert pas). `npx skills add` produit un snapshot figé.

Mécanisme retenu : cloner `etalab-ia/skills` dans `~/.config/opencode/skills/` et faire un `git pull` dans le `runtime.sh` d'agent-vm. Résultat : skills à jour à chaque démarrage de VM, sans action manuelle. C'est l'avantage d'avoir le runtime agent-vm.

### Séparation des conventions par profil
Exigence non négociable : un utilisateur d'un contexte ne doit jamais hériter des conventions d'un autre. Isolation physique, un fichier par contexte, aucun merge, aucun défaut implicite. Le bootstrap demande le contexte. Pattern repris de `etalab-ia/skills/templates/instructions/`.

| | beta.gouv | La Suite | IAE | Autre |
|---|---|---|---|---|
| Commits | conventionnel FR | gitmoji EN | conventionnel | au choix |
| Package manager | pnpm | yarn | uv (Python) | au choix |
| Design System | DSFR | La Suite UI Kit | DSFR si front | au choix |
| Backend | Next.js / FastAPI | Django REST | FastAPI | au choix |
| Conventions imposées | oui | oui | oui | aucune |

Socle commun aux profils : code/commentaires en anglais, UI en français, RGAA, sécurité ANSSI, RGPD, gitleaks, pas de secret/URL prod en dur, pas de données réelles en fixtures, souveraineté.

### Standards embarqués
- Standards d'ingénierie IAE (depuis le `.github` d'[OpenGateLLM](https://github.com/etalab-ia/OpenGateLLM/tree/main/.github)) : uv, Ruff, pytest unit+intég, Alembic, CI Semgrep + Trivy + CodeQL, PR template, Conventional Commits. Alimentent le profil IAE et les templates CI.
- Doctrine delivery [standards.beta.gouv.fr](https://standards.beta.gouv.fr/) (28 standards) : observabilité (Sentry), tests gating CI/CD, linter obligatoire, OpenAPI, données prod != test, obligations d'accessibilité. Alimentent une skill `delivery-standards-beta`.

### Coexistence avec une config OpenCode existante (non-destructif)
Beaucoup d'utilisateurs (et le poste de dev du projet) ont déjà agent-vm + OpenCode configurés, parfois avec plusieurs providers (ex. Albert + Scaleway). Le bundle ne doit donc **jamais écraser une config existante** :
- la config provider Albert du bundle est de **portée projet** (`opencode.json` à la racine du projet cible), pas globale ; OpenCode fusionne global+projet, projet prioritaire ;
- les écritures globales (dossier `~/.config/opencode/skills/`, clés `~/.zshenv`) sont **additives et idempotentes** ;
- `install.sh` détecte agent-vm/OpenCode déjà présents et les saute.

Corollaire pratique : un utilisateur déjà équipé peut faire tourner le spike (EPIC 0) immédiatement avec son setup existant, sans installer le bundle.

### Hors périmètre v1
- Pas de commandes custom type `/cadrer /build /preview /save` (inspiration template-proto non reprise) : Albert Code = OpenCode nu + skills + MCP.
- Pas de MCP Docs La Suite.
- Pas d'autre modèle Albert que Mistral Medium 3.5 (principal) et DeepSeek V4 Flash (small).

## Le chaînon manquant à construire

Un `runtime/agent-vm.runtime.sh` de référence + un `config/opencode.template.json` qui : (a) configurent Albert comme provider OpenAI-compatible, (b) synchronisent les skills (clone + `git pull`), (c) branchent les MCP, (d) sélectionnent le profil. Idempotents (pattern repris de [apistration#70](https://github.com/datagouv/apistration/pull/70)).

## Feuille de route

- Phase 0 — spike : agent-vm + OpenCode + Albert + une skill (dé-risque la chaîne).
- Phase 1 — bundle de référence : `opencode.json`, `runtime.sh`, profils + bootstrap, README non-tech.
- Phase 2 — standards + distribution : skills `conventions-iae` et `delivery-standards-beta`, templates CI, diffusion aux early adopters.

Voir [`BACKLOG.md`](../BACKLOG.md) pour le détail des tickets.

## Références analysées

| Source | Apport |
|---|---|
| [sylvinus/agent-vm](https://github.com/sylvinus/agent-vm) | Runtime d'isolation Lima ; archi runtime.sh permet tout brancher sans forker |
| [etalab-ia/skills](https://github.com/etalab-ia/skills) | Skills officielles + templates d'instructions (pattern profils) |
| [dnum-mi/starter-kit-opencode](https://github.com/dnum-mi/starter-kit-opencode) | Pattern repo mince `opencode.json` + `AGENTS.md` (mais `skills.urls` non documenté, aucun MCP) |
| [betagouv-experimentations/template-proto](https://github.com/betagouv-experimentations/template-proto) | Pattern « constitution » (commandes custom non reprises) |
| [datagouv/apistration#70](https://github.com/datagouv/apistration/pull/70) | `.agent-vm.runtime.sh` idempotent, scopes projet/user, compat ARM |
| [OpenGateLLM `.github`](https://github.com/etalab-ia/OpenGateLLM/tree/main/.github) | House style IAE -> profil IAE + templates CI |
| [standards.beta.gouv.fr](https://standards.beta.gouv.fr/) | Doctrine delivery -> skill delivery-standards-beta |
| [doc OpenCode](https://opencode.ai/docs/fr) | Config, skills locales, AGENTS.md, provider, MCP, permissions |

## Décisions ouvertes (v2)

- [datagouv-cli](https://github.com/datagouv/datagouv-cli) : complémentaire au MCP (écriture/publication) mais public producteur de données, et v0.1.0 immature -> option « profil producteur » plus tard.
- MCP Docs La Suite (angle cockpit branché à la suite numérique).
- « Vercel de l'État » (déploiement) : dépendance à l'équipe cloud DINUM.
- Workflow proto -> prod (documentation auto, PR template, review dev obligatoire).

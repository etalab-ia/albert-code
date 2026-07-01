# Skills à créer dans `etalab-ia/skills`

> Ces deux skills **ne vivent pas dans `albert-code`** : elles vont dans le repo `github.com/etalab-ia/skills` (réutilisables par tous les agents de l'État, pas seulement le bundle). Tickets T4.1 et T4.2 du `BACKLOG.md`.
> Format skill (OpenCode + Claude Code compatibles) : un dossier `skills/<nom>/` avec un `SKILL.md` (frontmatter `name` kebab = dossier, `description` au format « Use when… » pour le déclenchement) + un sous-dossier `references/` pour les guides détaillés.
> Installation côté utilisateur : `npx skills add etalab-ia/skills --skill <nom>` (ou clone du repo dans un chemin scanné).

---

## T4.1 — Skill `conventions-iae`

**But.** Embarquer le house style d'ingénierie de l'équipe IAE / Albert API (extrait du `.github` et de la config d'[OpenGateLLM](https://github.com/etalab-ia/OpenGateLLM)). C'est le pendant IAE/Python du `conventions-cofabnum` de DNUM-MI. Alimente le **profil `iae`** d'Albert Code.

**Déclencheurs (description).** Projet Python backend de l'État, FastAPI, OpenGateLLM/Albert API, « conventions IAE », « house style etalab », mise en place uv/Ruff/Alembic/pytest sur un projet Python public.

**Structure cible.**
```
skills/conventions-iae/
├── SKILL.md
└── references/
    ├── python-tooling.md      # uv, Ruff, structure projet
    ├── tests.md               # pytest async, coverage, unit+integ
    ├── database.md            # Alembic (upgrade + downgrade)
    └── ci-pr.md               # CI sécu, PR template, commits
```

**Contenu à encoder (factuel, repris d'OpenGateLLM) :**
- **Outils** : `uv` (pas pip/poetry) ; `uv venv` + `uv pip install ".[api,dev,test]"`. Python ≥ 3.12.
- **Lint/format** : **Ruff seul** (pas black/isort/flake8). `line-length = 150`, `target-version = "py312"`, règles `E,W,F,I,N,UP`, ignores exacts (`F403,F841,E501,N806,UP031,W291,N805,N815`), isort `force-sort-within-sections = true`, `known-first-party = ["config","utils","api","app"]`. Lancer `ruff check --fix` + `ruff format` (via pre-commit) avant commit.
- **Tests** : pytest, `asyncio_mode = "auto"`, fixtures async `scope=session`, **unitaires ET intégration**, viser **≥ 80 %** de couverture. Entrypoints `make test-unit` / `make test-integ`.
- **DB** : migrations **Alembic** ; toute modif de modèle (`api/sql/models.py`) → générer la migration + **tester `upgrade` ET `downgrade` en local**.
- **Git/PR** : Conventional Commits `type(scope): message`. PR avec Definition of Done : tests unit+integ ajoutés, pas de debug logs, **aucun secret/var d'env en clair**, section migration si DB touchée.
- **Sécurité CI** : chaîne **Semgrep (SAST) + Trivy (conteneurs) + CodeQL** ; sévérité **CRITICAL/ERROR bloquante**, HIGH/WARNING informative.
- **Stack de référence** (pour contexte, pas imposée) : FastAPI, SQLAlchemy async, Alembic, Celery, Redis, PostgreSQL.

**DoD.** Skill chargée par OpenCode, se déclenche sur un projet Python, propose la config `uv`/Ruff/pytest/Alembic conforme. PR ouverte sur `etalab-ia/skills`. → `TESTS.md` S9.

---

## T4.2 — Skill `delivery-standards-beta`

**But.** Scaffolder et auditer un projet conforme à la doctrine delivery de [standards.beta.gouv.fr](https://standards.beta.gouv.fr/) (28 standards). N'embarque **que l'apport net** non couvert par les skills existantes (`rgaa`, `react-dsfr`, `securite-developpement` couvrent déjà ~90 % du volet code).

**Déclencheurs (description).** Démarrer un produit beta.gouv « production-grade », « standards beta.gouv », rendre un service conforme (observabilité, page stats, DashLord, mentions légales, déclaration d'accessibilité), checklist avant comité d'investissement.

**Structure cible.**
```
skills/delivery-standards-beta/
├── SKILL.md
└── references/
    ├── checklist-28-standards.md   # les 28 standards en items binaires
    ├── observabilite.md            # Sentry + logs structurés + APM/Apdex
    ├── obligations-declaratives.md # /accessibilite, mentions légales, CGU, confidentialité
    └── page-stats-dashlord.md      # page /stats (matrice impact) + conf DashLord
```

**Contenu à encoder (apport net beta.gouv) :**
- **Observabilité** : configurer un outil de gestion d'erreurs (type **Sentry**), logs applicatifs structurés en rotation, surveillance perf (APM / Apdex).
- **Tests + CI/CD** : suite **unitaire ET E2E** ; les tests conditionnent l'intégration (CI) et le déploiement (CD) ; **linter obligatoire** intégré au pipeline.
- **Documentation** : README (objectif du service, stack, archi, lancement local), **APIs documentées en OpenAPI/Swagger**.
- **Données** : **prod ≠ hors-prod** — jeux de test fictifs/anonymisés, URLs/secrets de prod via **variables d'environnement** (jamais en dur).
- **Obligations déclaratives a11y** : page `/accessibilite`, déclaration de conformité RGAA, mention de conformité dans le footer (rappel : sanction possible).
- **Documents légaux** : mentions légales + CGU + politique de confidentialité accessibles (footer).
- **Transparence** : page `/stats` publique (matrice d'impact : utilisable / utilisé / utile / impactant / efficient) + configuration **DashLord**.
- **Open-source / souverain** : code ouvert, solutions souveraines (SecNumCloud) privilégiées ; signaler toute dépendance propriétaire.
- **UX** : pas d'adresse `no-reply` ; bouton « Je donne mon avis ».

**Mode d'emploi de la skill** : deux usages — (a) **scaffolder** la structure conforme sur un nouveau projet, (b) **auditer** un projet existant contre la checklist des 28 standards (rapport conforme/non-conforme).

**DoD.** Skill chargée par OpenCode, génère la structure conforme et/ou produit l'audit checklist. PR ouverte sur `etalab-ia/skills`. → `TESTS.md` S9.

---

## Notes communes

- **Ne pas dupliquer l'existant** : ces skills renvoient vers `rgaa`, `react-dsfr`, `securite-developpement`, `datagouv-apis` plutôt que ré-encoder leur contenu.
- **Agnostiques du modèle/provider** : les skills vivent dans l'agent, pas dans le runtime ; aucune mention d'Albert ou d'un provider.
- Après création, mettre à jour le `README.md` et l'index de `etalab-ia/skills`, et relancer `/wikifier` côté vault si une fiche Entité doit pointer vers elles.

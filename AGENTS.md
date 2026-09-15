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
| **agent-vm** | Sandbox d'isolation (VM Lima jetable, mode autonome sûr). **Dépendance externe**, détectée sur le poste à l'exécution — plus vendorisée (EPIC 13) | `github.com/sylvinus/agent-vm` |
| **OpenCode** | Harness unique (assistant de code terminal) | `opencode.ai` |
| **Albert API** | Provider LLM souverain (OpenAI-compatible) | `albert.api.etalab.gouv.fr` |
| **Skills État** | Connaissances métier (DSFR, RGAA, sécurité, data.gouv) | `github.com/etalab-ia/skills` |
| **MCP** | Connecteurs clés : data.gouv, context7, playwright, chrome-devtools | — |
| **AGENTS.md par défaut** | Règles sécurité + conventions universelles | `templates/AGENTS.default.md` |

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
4. Tout nouveau retour utilisateur ou incident interne identifié pendant le build ou l'instruction d'un ticket est d'abord consigné dans `FEEDBACK.md` (`AC-R###`, 🆕) avant d'être éventuellement backlogué.
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
├── bin/
│   └── albert-code                # Dispatcher à 4 verbes : install|setup|run|update
├── install.sh                     # Amorçage (Phase A + pose du shim)
├── uninstall.sh                   # Désinstallation propre
├── lib/                           # Fonctions bash partagées (banner, ui, checks, phases)
│   ├── ui.sh
│   ├── vm.sh                      # Résolution du moteur agent-vm à l'exécution + _vm()
│   └── phases.sh
├── config/
│   └── opencode.template.json     # Config OpenCode : provider Albert + MCP + permissions
├── runtime/
│   └── agent-vm.runtime.sh        # Runtime de référence (provider + sync skills + MCP), idempotent
└── templates/
    ├── AGENTS.default.md          # Règles sécurité + conventions universelles
    ├── PULL_REQUEST_TEMPLATE.md   # Fusion DoD OpenGateLLM + checklist beta
    └── .github/workflows/         # CI réutilisable : semgrep, trivy, codeql
```

**Repo cible :** `github.com/etalab-ia/albert-code` · **Licence :** MIT.

---

## 4. Stack de ce dépôt

| Élément | Choix |
|---|---|
| Langage principal | **Bash** (bootstrap/runtime), **JSON/JSONC** (config OpenCode), **Markdown** (docs) |
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
7. **Retours utilisateurs et incidents → `FEEDBACK.md` d'abord.** Tout retour ou incident interne identifié pendant le build ou l'instruction d'un ticket est consigné dans `FEEDBACK.md` (anonymisé, `AC-R###`, 🆕) avant d'être backlogué. Un ticket issu d'un retour cite son finding via `<- AC-R###`. Ne jamais mettre de nom complet, verbatim nominatif ou URL Tchap interne dans le dépôt.
8. **Nommer ce qu'on détruit.** Toute décision qui remplace, purge ou supprime quelque chose nomme explicitement ce qu'elle fait perdre à l'utilisateur et le justifie ; une perte non nommée est une régression.

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
- **Ancrage des scénarios** (`TESTS.md`) : dans une **étape de procédure**, ancrer sur un repère qui ne bouge pas (nom de fonction, branche conditionnelle, chaîne exacte affichée), **jamais un numéro de ligne** : le code bouge à chaque PR et les renvois pointent alors le mauvais endroit sans que rien ne le signale (T4.6). Une note **`Validé le :`** est un **constat figé à sa date** : on ne la met jamais à jour quand le code bouge, on l'annote.

### Git
- Commits **Conventional Commits** : `type(scope): message` (`feat|fix|docs|refactor|chore|test`). Message qui explique le *pourquoi*. Squash des commits intermédiaires avant push.
- Branches `feat/…`, `fix/…`. PR avec checklist (`templates/PULL_REQUEST_TEMPLATE.md`).

---

## 7. Spécificités OpenCode (à connaître pour builder juste)

- **Config** : `opencode.json` (racine projet) + `~/.config/opencode/opencode.json` (global), fusionnés. `$schema: https://opencode.ai/config.json`. Substitution `{env:VAR}` / `{file:path}`.
- **Provider Albert** : `provider.albert.npm = "@ai-sdk/openai-compatible"`, `options.baseURL = "https://albert.api.etalab.gouv.fr/v1"`, `options.apiKey = "{env:ALBERT_API_KEY}"`, `models` listant uniquement `deepseek-v4-flash`. Puis `model = "albert/deepseek-v4-flash"`, `small_model = "albert/deepseek-v4-flash"`.
- **Règles** : OpenCode lit `AGENTS.md`. La clé `instructions` accepte fichiers, globs ET URLs (timeout 5 s).
- **MCP** : clé `mcp.<nom>` type `local` (`command`) ou `remote` (`url`+`headers`). data.gouv = remote `https://mcp.data.gouv.fr/mcp` (lecture publique). **context7 = remote nécessitant une clé API** (https://context7.com/plans → `CONTEXT7_API_KEY` dans `~/.zshenv`, passée en header) ; rendre ce MCP optionnel si pas de clé. playwright = local. chrome-devtools = local (`npx chrome-devtools-mcp@latest`) — déjà préinstallé dans agent-vm mais à déclarer côté OpenCode.
- **Skills = dossiers locaux scannés uniquement.** Chemins : `.opencode/skills/`, `.agents/skills/`, `.claude/skills/` (projet) ; `~/.config/opencode/skills/` (global). Format `SKILL.md` + frontmatter (`name` kebab = dossier, `description`). **La clé `skills` / chargement par URL n'existe PAS dans OpenCode** → ne pas l'utiliser (contrairement au repo DNUM-MI).
- **Permissions** : `read/edit/bash/skill/webfetch/websearch/task` = `allow|ask|deny`, patterns, dernière règle gagnante.
- **Ne pas créer de `CLAUDE.md`** : s'il coexiste avec `AGENTS.md`, OpenCode l'ignore (source de confusion).

---

## 7bis. Le moteur de VM est une dépendance externe (EPIC 13)

agent-vm n'est **plus vendorisé**. Conséquences sur la façon d'écrire du code ici :

- **Appeler la COMMANDE `agent-vm`, jamais sourcer `agent-vm.sh`.** Une fonction shell n'est pas héritée par un processus fils : la sourcer imposerait de retrouver un chemin de fichier, ce qui est précisément ce qu'on a supprimé. `_vm()` fait `command agent-vm "$@"`.
- **Ne pas réimplémenter ce que le moteur expose.** Les secrets passent par `agent-vm env` (le fichier est sourcé par la VM : un échappement raté y coûte tous les secrets, et le moteur teste ce quoting sur bash 3.2). L'état passe par `agent-vm info`. Si quelque chose manque au moteur, c'est là qu'il faut l'ajouter.
- **Le plancher `AC_AGENT_VM_MIN` (`lib/vm.sh`) est bloquant, et ne se lève QUE si Albert Code ne peut vraiment pas tourner en dessous** — sinon on casse la promesse « ça marche avec celui déjà installé ». À `0.1.0` il est légitime : c'est la version qui apporte `agent-vm info` (toute la détection d'état), `agent-vm env` (les secrets), le nom `mcp-chrome` et le lancement par shell de connexion. Comme tout est arrivé ensemble, exiger le plancher autorise à **supposer que `mcp-chrome` existe** — c'est la seule supposition de version permise, et elle est verrouillée par `TESTS.md` S70 §7. Un moteur qui ne sait pas dire sa version est antérieur au verbe `version` : trop ancien, sans autre sondage. Échappatoire assumée : `AC_AGENT_VM_MIN=0` désactive la vérification.
- **Ne jamais lire l'intérieur du moteur.** Ni ses fonctions privées (`_agent_vm_name`), ni le nom du template (`agent-vm-base`), ni ses fichiers d'état (`.agent-vm-base-version`). Tout passe par `agent-vm info` via `ac_vm_info()`, qui publie `AC_VM_INFO_*`. Un état indéterminable vaut `unknown` : ne jamais le convertir en `0`/`1`.
- **Ne jamais appeler `limactl` directement** (verrouillé par `TESTS.md` S65). Le moteur possède Lima.
- **Ne jamais retirer la ligne de sourçage d'agent-vm** d'un rc utilisateur : c'est sa commande à lui, pas une trace d'Albert Code. Ceci **inverse T7.2**, qui la supprimait.
- **Préférer faire corriger le moteur en amont** plutôt que contourner ici : un contournement local survit à sa cause (cf. T7.6, T-FIX-16, tous deux repris upstream dans agent-vm 0.1.0).

Les secrets passent par `agent-vm env` (canal du moteur, repoussé dans la VM à chaque démarrage), pas par le `~/.zshenv` de l'hôte. Seules `ALBERT_API_KEY` et `CONTEXT7_API_KEY` restent aussi dans `~/.zshenv` : ce sont les clés de l'utilisateur, et l'hôte en a besoin pour interroger le catalogue Albert.

---

## 8. Synchro des skills (décision d'archi)

Les skills ne se mettent **PAS** à jour toutes seules. Mécanisme retenu : **cloner `etalab-ia/skills` dans `~/.config/opencode/skills/` et `git pull` dans `runtime/agent-vm.runtime.sh`** → skills fraîches à chaque démarrage de VM. Ne pas reposer sur un snapshot `npx skills add` figé.

---

## 9. AGENTS.md par défaut

Le bundle pose un `AGENTS.md` de référence (`templates/AGENTS.default.md`) avec les règles de sécurité, plan mode, task management, code quality, git et accessibilité — applicable à tout projet, neutre par nature. Si le projet a déjà son `AGENTS.md`, il est conservé (non-destructif).

---

## 10. À NE PAS faire

- Ne pas supporter d'autre harness que **OpenCode** (ni Vibe, ni Claude Code).
- **Ne pas écraser une config OpenCode / agent-vm existante.** La config provider du bundle est de **portée projet** (`opencode.json` à la racine du projet cible), jamais le global perso de l'utilisateur (qui peut contenir d'autres providers, ex. Scaleway). Écritures globales (dossier skills, `~/.zshenv`, `~/.agent-vm/env`) = **additives + idempotentes** (détecter avant d'écrire). Dans `~/.agent-vm/env`, ne toucher QUE les cinq variables gérées : le fichier appartient à agent-vm et peut contenir les secrets d'autres outils.
- **Ne pas vendoriser agent-vm à nouveau**, ni le patcher localement. Ce qui manque au moteur se corrige en amont (cf. §7bis).
- Ne pas utiliser de modèle Albert autre que `deepseek-v4-flash` (le seul modèle embarqué).
- Ne jamais coder un **alias** de modèle Albert. Utiliser uniquement le champ `id` renvoyé par `GET /v1/models` ; les alias sont une commodité utilisateur non contractuelle et ont déjà été re-versionnés ou supprimés sans préavis.
- Ne pas créer de défaut implicite de profil ni merger les conventions de deux contextes. (Les profils ont été supprimés dans T6.3 — un seul `AGENTS.default.md` neutre.)
- Ne pas s'appuyer sur la clé `skills`/`skills.urls` (non documentée OpenCode).

---

## 11. Références

- **Plan produit** : `docs/PLAN.md`
- Doc OpenCode : https://opencode.ai/docs/fr
- agent-vm : https://github.com/sylvinus/agent-vm
- Skills État : https://github.com/etalab-ia/skills · templates d'instructions : `…/tree/main/templates/instructions`
- Albert API : https://albert.api.etalab.gouv.fr · doc https://doc.incubateur.net/alliance/albert-api
- Inspirations : `dnum-mi/starter-kit-opencode`

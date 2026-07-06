# FEEDBACK — albert-code

> Registre des retours utilisateurs (crash tests, entretiens, Tchap), codifiés et traçables.
> Sens unique : un retour brut → un finding ici (`AC-R###`) → un ticket `BACKLOG.md` (`<- AC-R###`) → un scénario `TESTS.md`.
> Les verbatims détaillés et l'identité des testeurs restent hors du repo (notes de recherche privées). Ici : finding anonymisé + source légère.

**Légende**
- **Type** : 🐛 bug · 🎛️ UX/friction · ✨ feature · ⚙️ infra · ❓ question/doute
- **Sévérité** : 🔴 bloquant · 🟠 majeur · 🟡 mineur
- **Statut** : 🆕 à trier · 📥 backlogué · 🔧 en cours · ✅ traité · ⛔ rejeté

---

## Registre

| ID | Type | Sév | Retour | Source | Statut | Renvoi |
|----|------|-----|--------|--------|--------|--------|
| AC-R001 | 🐛 | 🔴 | Après `./install.sh`, `agent-vm` reste introuvable dans le même terminal (fonction shell sourcée, non chargée dans le shell parent), même après relance de l'installeur. | Crash test 2026-07-02, profil dev power user | ✅ traité | `BACKLOG.md` T-FIX-11 · `TESTS.md` S15 |
| AC-R002 | 🎛️ | 🟠 | Les messages « ✓ agent-vm cloné / sourcé » laissent croire que la commande est utilisable immédiatement, alors qu'elle ne l'est pas. | Crash test 2026-07-02, profil dev power user | ✅ traité | `BACKLOG.md` T-FIX-11 |
| AC-R003 | 🎛️ | 🟡 | Chemin `~/Dev/…` codé en dur (défauts + README + doc) : convention personnelle qui ne doit pas fuiter dans un installeur distribué. | Revue interne 2026-07-02 | ✅ traité | `BACKLOG.md` T-FIX-12 |
| AC-R004 | ⚙️ | 🟠 | Absence de prompt caching (Scaleway ; à confirmer côté Albert API) → coût x~10 sur un usage code-harness. Considéré comme prérequis, surtout gros modèles. | Crash test 2026-07-02, profil dev power user | 🆕 à trier | — |
| AC-R005 | ❓ | 🟡 | Certaines skills ne se déclenchent pas dans OpenCode/Vibe (`/skill` → l'agent ne fait rien) : question de harness/compatibilité vs Claude Code. | Crash test 2026-07-02, profil dev power user | 🆕 à trier | — |
| AC-R006 | 🎛️ | 🟠 | Le hint de scaffold (`phase_b`) affiche un chemin hardcodé `~/albert-code/install.sh` au lieu du chemin réel (`$SELF_DIR`) → copier-coller cassé si le dépôt est cloné ailleurs (ex. `~/Dev/albert-code`). Régression de T-FIX-12. | Dogfood 2026-07-02 | ✅ traité | `BACKLOG.md` T-FIX-13 · `TESTS.md` S16 |
| AC-R007 | 🐛 | 🔴 | Après une install fraîche, `agent-vm opencode` échoue (`Base VM not found. Run 'agent-vm setup' first.`) : `install.sh` ne crée pas la VM de base et le message « Prochaines étapes » ne mentionne pas `agent-vm setup`. Onboarding cassé pour tout nouvel utilisateur. | Dogfood 2026-07-02 | ✅ traité | `BACKLOG.md` T-FIX-14 · `TESTS.md` S17 |
| AC-R008 | ⚙️ | 🟠 | Des notes de validation / sorties de dry-run collées dans le dépôt public fuitent le chemin home absolu personnel (`/Users/<name>/…`) et le username. Même classe que AC-R003 mais autre vecteur (docs, pas code). Instance neutralisée au pré-vol (note S16), mais rien n'empêche la récidive. | Pré-vol commit 2026-07-02 | ✅ traité | `BACKLOG.md` T4.5 · `TESTS.md` S18 |
| AC-R009 | 🎛️ | 🟡 | L'installeur signale « OpenCode absent du PATH » et suggère un contournement hors-VM (`npm i -g opencode-ai`). Contraire à la doctrine Albert Code = usage **exclusivement** via `agent-vm` (bulle isolée) ; ne pas proposer de bypass de l'isolation. Redondance en prime (« absent du PATH » ×2). | Dogfood 2026-07-02 | ✅ traité | `BACKLOG.md` T-FIX-15 |
| AC-R010 | ⚙️ | 🟠 | Ressources VM par défaut d'agent-vm trop justes pour du code (`1 CPU / 3 GiB / 10 GiB`). En usage réel il faut ~`4 CPU / 8 GiB / 30 GiB`. agent-vm n'a pas de défaut configurable par env → Albert Code doit fixer une taille adaptée (disque au `setup`, cpu/mémoire au lancement) sans sur-allouer sur petite machine. | Dogfood 2026-07-02 | ✅ traité | `BACKLOG.md` T1.4 · `TESTS.md` S20 |
| AC-R011 | 🎛️ | 🟡 | `context7` est `enabled: true` en dur dans `opencode.template.json` alors qu'il exige `CONTEXT7_API_KEY` → pour un utilisateur **sans clé**, le MCP échoue (401 / bearer vide) au démarrage dans la VM et s'affiche « cassé ». T1.1 notait « rendre le MCP optionnel/skippable si pas de clé » — pas encore fait. | Revue config dogfood 2026-07-02 | 📥 backlogué | `BACKLOG.md` T1.5 |
| AC-R012 | 🎛️ | 🟠 | Scaffold dans un repo ayant DÉJÀ un `opencode.json` : le fichier est conservé (non-destructif) → le provider `albert` n'est pas ajouté → Albert ne se connecte pas dans la VM, et l'installeur affiche seulement « conservé » sans avertir que le merge n'a pas eu lieu. Footgun silencieux. | Dogfood 2026-07-02 | 📥 backlogué | `BACKLOG.md` T1.6 |
| AC-R013 | 🎛️ | 🟠 | Albert Code onboarde « coder dans la VM » mais pas « committer/pusher depuis la VM » : ni l'identité git (`user.name`/`user.email`) ni la clé SSH ne sont configurées dans la VM, alors que le README promet « l'agent pousse des PR depuis la VM ». L'agent tombe sur `Author identity unknown`. Rappel : SSH (auth) ≠ identité de commit. | Dogfood 2026-07-02 | 📥 backlogué | `BACKLOG.md` T1.7 |
| AC-R014 | ✨ | 🟠 | Test d'install S28 : l'interface à 3 verbes (`install` / `setup` / `run`) facilite la vie de l'utilisateur : une commande `albert-code` unique au lieu de mémoriser `install.sh` + `agent-vm setup` + `agent-vm opencode`. | Test utilisateur S28 2026-07 | 🆕 à trier | — |
| AC-R015 | 🎛️ | 🟡 | Manque de pédagogie sur agent-vm : c'est quoi cette « VM bulle isolée » dont tout le monde parle ? Un non-dev ne comprend pas pourquoi on a besoin d'une VM, ni ce que ça fait concrètement. | Test utilisateur S28 2026-07 | 🆕 à trier | — |
| AC-R016 | 🎛️ | 🟡 | Choix de profil (beta.gouv / La Suite / IAE / Autre) déroutant pour qui n'est pas familier de cette typologie. Question posée trop tôt, avant toute configuration. La valeur « Autre » donne l'impression d'avoir choisi par défaut. | Test utilisateur S28 2026-07 | 🆕 à trier | — |
| AC-R017 | ✨ | 🟠 | Au setup, on aimerait choisir quelles skills et MCP on branche (Y/N). La config ouverte ne donne aucun contexte de ce qu'apporte chaque brique — « est-ce que j'ai besoin de playwright pour mon projet ? » | Test utilisateur S28 2026-07 | 🆕 à trier | — |
| AC-R018 | 🎛️ | 🟡 | Bascule FR->EN vers le wizard agent-vm : quand install.sh passe la main à `agent-vm setup`, le wizard natif d'agent-vm (en anglais) s'affiche sans prévenir. Déroutant pour un public non-tech francophone. | Dogfood install 2026-07 | ✅ traité | `BACKLOG.md` T6.5 · `TESTS.md` S30 |
| AC-R019 | 🐛 | 🔴 | À l'étape auth GitHub, `install.sh` demande « Email noreply GitHub » avec pour défaut le vrai email de l'utilisateur, qui échoue la validation. Un utilisateur non-tech ne connaît pas son email noreply ni comment le trouver. | Dogfood install 2026-07 | 🔧 en cours (réouvert) | `BACKLOG.md` T6.6 · `TESTS.md` S31 (séd non matché, corrigé dans hotfix #2) |
| AC-R020 | ⚙️ | 🟠 | `agent-vm setup` installe 4 harnais (Claude Code, OpenCode, Codex, Mistral Vibe). En test réel, l'installeur Mistral Vibe a retourné HTTP 429 (rate limit) et TOUT le setup a échoué, alors qu'Albert Code n'a besoin que d'OpenCode. Un seul installeur qui rate = base non finalisée. Le retry a fonctionné (429 transitoire), mais risque de fiabilité à l'install party (plusieurs testeurs en parallèle). Dépendance upstream agent-vm. | Dogfood install 2026-07 | 📥 backlogué | `BACKLOG.md` T6.7 |
| AC-R021 | 🐛 | 🟠 | (a) install avortée sans shim : `install.sh` a `set -e` et `install_shim` est appelé APRÈS la création fragile de la VM de base. Un échec d'`agent-vm setup` (429) fait sortir l'installeur en erreur AVANT de poser le shim -> install incomplète, aucune commande `albert-code`. (b) ancien installeur MVP écrivait une fonction shell `albert-code()` dans ~/.zshrc, qui masque le shim PATH -> le nouveau shim est ignoré. | Dogfood install 2026-07 | ✅ traité | `BACKLOG.md` T6.8 · `TESTS.md` S32 |
| AC-R022 | 🐛 | 🔴 | Le shim `albert-code` (généré par `install_shim`) avale les prompts interactifs : il source le script avec `2>/dev/null` (avale stderr où `confirm()`/`prompt_*` écrivent) puis appelle `$name "$@"`. Résultat : `albert-code setup` affiche l'entête puis semble figé (questions MCP/skills invisibles, `read` attend). | Dogfood install 2026-07 | ✅ traité | `BACKLOG.md` T6.9 · `TESTS.md` S33 |
| AC-R023 | 🎛️ | 🟡 | MCP chrome-devtools présent malgré 0 MCP sélectionné : `agent-vm` le préinstalle au niveau global de la VM. Pas une fuite (MCP local), mais ça casse la transparence « ce que je choisis = ce que j'ai » du public souveraineté. À cadrer avec Sylvain (agent-vm). | Dogfood install 2026-07 | 📥 backlogué | `BACKLOG.md` T6.11 |
| AC-R024 | 🐛 | 🟠 | L'agent scaffold un projet react-dsfr (npm install) puis commit SANS .gitignore -> `node_modules/` dans la PR : 41659 fichiers, +5,4M lignes. Hygiène cassée + risque sécurité (sans .gitignore, un `.env` part aussi facilement). | Dogfood E2E 2026-07 | ✅ traité | `BACKLOG.md` T6.10 · `TESTS.md` S34 |
| AC-R025 | 🐛 | 🟠 | `install_shim` fait « si le fichier shim existe → return 0 » → quand le contenu change (ex. fix exec d'AC-R022), un `git pull && ./install.sh` ne repose PAS le nouveau shim. Il faut `rm` manuel. Pas idempotent pour les mises à jour. | Dogfood hotfix re-test 2026-07 | ✅ traité | `BACKLOG.md` T6.12 · `TESTS.md` S36 |
| AC-R026 | 🐛 | 🟡 | Au boot VM (`runtime/agent-vm.runtime.sh`, sync_skills), la sortie affiche des lignes parasites « name=<skill> » (ex. name=datagouv-apis, name=react-dsfr). Bruit de debug, comptage correct mais gène la lisibilité. | Dogfood hotfix re-test 2026-07 | ✅ traité | `BACKLOG.md` T6.13 |

---

## Notes

- **AC-R004 (prompt caching)** : à instruire avant tout scaling. Vérifier si Albert API expose du caching sur `chat/completions` ; sinon, arbitrer l'infra d'inférence. vLLM implémente le caching nativement.
- **AC-R005 (harness skills)** : investiguer le déclenchement des skills selon le harness (OpenCode / Vibe / Claude Code). Impacte la portabilité du bundle hors Claude Code.
- **AC-R006 / AC-R007** : détectés en dogfood (réinstall complète sur machine remise à zéro le 2026-07-02). R007 est bloquant onboarding (le « next step » affiché échoue). Fixes validés par S16 / S17.
- **AC-R008** : fuite récurrente de chemin absolu / username dans un dépôt public. L'instance (note S16) a été neutralisée au pré-vol du commit `7f84d9a` ; le fix durable est un **garde-fou CI** (T4.5), pas un edit ponctuel — sinon ça reviendra.

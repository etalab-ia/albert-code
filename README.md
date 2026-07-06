```
    _    _ _               _      ____          _
   / \  | | |__   ___ _ __| |_   / ___|___   __| | ___
  / _ \ | | '_ \ / _ \ '__| __| | |   / _ \ / _` |/ _ \
 / ___ \| | |_) |  __/ |  | |_  | |__| (_) | (_| |  __/
/_/   \_\_|_.__/ \___|_|   \__|  \____\___/ \__,_|\___|
```

# Albert Code

⚠️ PROJET EXPÉRIMENTAL ⚠️

**Stack d'agentic coding souveraine pour l'État, en une commande : OpenCode + agent-vm + Albert API + skills de l'État + MCP.**

Albert Code assemble des briques existantes pour coder avec une IA souveraine, isolée, avec les standards de l'administration embarqués :

- **[Albert API](https://albert.api.etalab.gouv.fr)** : modèles souverains de l'État (hébergement SecNumCloud), provider OpenAI-compatible.
- **[agent-vm](https://github.com/sylvinus/agent-vm)** : sandbox Lima jetable. L'agent tourne en autonomie sans accès à l'hôte.
- **[OpenCode](https://opencode.ai)** : le harness (assistant de code en terminal).
- **[Skills de l'État](https://github.com/etalab-ia/skills)** : DSFR, accessibilité (RGAA), sécurité, data.gouv.
- **MCP** : data.gouv, context7, playwright, chrome-devtools.

Ce n'est pas un IDE ni un fork : de l'orchestration mince (scripts + config) au-dessus d'OpenCode.

> Statut : v1, validé en dogfood bout en bout le 2026-07-02. En test avec des early adopters. Retours et issues bienvenus.

## Prérequis

- macOS ou Linux (pas de Windows).
- [Lima](https://lima-vm.io) (installé par le script si absent, via Homebrew).
- Node.js (pour les serveurs MCP lancés via `npx`).
- Une **clé Albert API** (réservée aux agents publics : demande sur https://albert.api.etalab.gouv.fr).
- Un compte GitHub (pour que l'agent pousse des PR depuis la VM).

## Installation

```bash
git clone https://github.com/etalab-ia/albert-code.git ~/albert-code
cd ~/albert-code
./install.sh
```

> Le chemin d'installation ne doit **pas contenir d'espace** (contrainte agent-vm/Lima, qui monte le répertoire de travail dans la VM).

`install.sh` est **idempotent** et **non-destructif** : il ne réinstalle rien de déjà présent et n'écrase aucune config existante. Deux phases :

- **Phase A (bootstrap poste)** : Lima + agent-vm, provider Albert, skills de l'État, connecteurs MCP, clés dans la VM. Lancée quand tu exécutes le script depuis le dépôt.
- **Phase B (scaffold projet)** : lancée quand tu exécutes le script depuis un répertoire projet. Te demande ton contexte, puis pose l'`AGENTS.md` du profil + un `opencode.json` de **portée projet**.

Flags : `--dry-run` (simule sans rien écrire), `--help`.

### Profils de conventions

Au scaffold d'un projet, le script demande le contexte et applique **uniquement** ses conventions (aucun défaut, aucun mélange) :

| Profil | Conventions |
|---|---|
| `beta.gouv` | DSFR, pnpm, commits FR, Next.js / FastAPI |
| `La Suite` | UI Kit La Suite, yarn, commits gitmoji, Django |
| `IAE / Albert` | FastAPI, uv, Ruff (house style OpenGateLLM) |
| `Autre` | aucune convention imposée (tu fournis ton `AGENTS.md`) |

## Utilisation

```bash
mkdir -p ~/mon-projet && cd ~/mon-projet
~/albert-code/install.sh                                  # Phase B : choix du profil + config projet
agent-vm setup --disk 32                                  # 1 seule fois : crée la VM de base
agent-vm --cpus 4 --memory 8 --disk 32 opencode            # ouvre la bulle isolée + OpenCode
```

Dans la bulle, l'agent tourne en mode autonome (`--dangerously-skip-permissions`), sûr parce que tout est confiné dans la VM. Tu peux lui parler en français.

Les commandes exactes (avec tes valeurs) s'affichent à la fin de `install.sh`, sous « Prochaines étapes ».

> Si ton projet a déjà un `opencode.json`, il est **conservé** (non-destructif) — vérifie qu'il contient bien le provider Albert, sinon Albert ne sera pas câblé. Voir [Dépannage](#dépannage) si besoin.

### Ressources de la VM

Les défauts d'agent-vm (1 CPU / 3 GiB / 10 GiB) sont trop justes pour un agent de code. Albert Code applique par défaut `4 CPU / 8 GiB / 32 GiB`, surchargeables par variable d'environnement :

```bash
AC_VM_CPUS=8 AC_VM_MEMORY=16 AC_VM_DISK=64 ./install.sh
```

| Variable | Défaut | Rôle |
|---|---|---|
| `AC_VM_CPUS` | `4` | CPU alloués (s'applique au lancement `agent-vm opencode`). |
| `AC_VM_MEMORY` | `8` (GiB) | RAM allouée (s'applique au lancement). |
| `AC_VM_DISK` | `32` (GiB) | Disque, fixé au 1er `agent-vm setup`, ne peut ensuite que grandir. |

**Garde-fou hôte** (lecture seule, macOS + Linux) : `install.sh` détecte les ressources de ta machine (`sysctl`/`nproc`) et ne propose jamais plus de ~la moitié du CPU/RAM hôte, même si `AC_VM_*` demande plus — pour ne pas sur-allouer sur un petit poste. Le disque n'est jamais rogné (sparse : alloué à l'usage, pas d'un coup) ; un avertissement s'affiche si l'espace libre est insuffisant.

### Push & PR depuis la VM

Par défaut, l'agent peut **committer** dans la VM mais **ni pusher ni ouvrir de PR** : agent-vm isole la bulle de tes credentials hôte (aucun SSH, aucun token). Pour l'autoriser, fournis un **token GitHub dédié**.

1. **Crée un PAT fine-grained** sur [github.com/settings/personal-access-tokens](https://github.com/settings/personal-access-tokens) :
   - *Repository access* → seulement les dépôts que l'agent doit toucher (pas « All repositories »).
   - *Permissions* → **Contents: Read and write** + **Pull requests: Read and write** (Metadata: read est ajouté d'office).
   - Expiration courte, à renouveler. **Token dédié et révocable** (pas ton token maître).
2. **Pose-le dans ton runtime perso** `~/.agent-vm/runtime.sh` (hôte, hors de tout dépôt, `chmod 600`) — jamais dans un `opencode.json` ni un fichier versionné :
   ```bash
   # --- albert-code : auth GitHub VM ---
   grep -q 'GH_TOKEN'          ~/.zshenv 2>/dev/null || echo "export GH_TOKEN='github_pat_XXXXXXXX'"                 >> ~/.zshenv
   export GH_TOKEN='github_pat_XXXXXXXX'
   grep -q 'AC_GIT_USER_NAME'  ~/.zshenv 2>/dev/null || echo "export AC_GIT_USER_NAME='Prénom Nom'"                  >> ~/.zshenv
   export AC_GIT_USER_NAME='Prénom Nom'
   grep -q 'AC_GIT_USER_EMAIL' ~/.zshenv 2>/dev/null || echo "export AC_GIT_USER_EMAIL='ton-id@users.noreply.github.com'" >> ~/.zshenv
   export AC_GIT_USER_EMAIL='ton-id@users.noreply.github.com'
   # --- /albert-code ---
   ```
   Utilise ton **email noreply GitHub** ([settings/emails](https://github.com/settings/emails)) pour ne pas exposer ton email perso dans l'historique git.
3. **Relance la bulle** (`agent-vm opencode`). Le runtime du bundle branche alors automatiquement le credential helper (`gh auth setup-git`) et pose l'identité git. `git push` et `gh pr create` marchent depuis la VM.

> Le token vit dans une bulle exposée au prompt-injection : garde-le **fine-grained, scopé, révocable**, et **relis chaque PR avant merge**. Un contenu malveillant pourrait pousser l'agent à en abuser dans la limite de sa portée — d'où les permissions minimales.

## Sécurité

- **Isolation noyau (Lima)** : l'agent n'a aucun accès à tes clés SSH, credentials, cookies ou sessions de l'hôte. La VM est jetable (`agent-vm rm`).
- **Secrets** : les clés (`ALBERT_API_KEY`, `CONTEXT7_API_KEY`) ne sont jamais versionnées ni loggées ; elles sont persistées dans le `~/.zshenv` de la VM en `chmod 600`.
- **Risque résiduel (prompt-injection)** : un contenu malveillant (page web, issue, fichier) pourrait pousser l'agent à exfiltrer une clé par le réseau. Bonnes pratiques : clé Albert **dédiée et révocable** (pas ta clé maître), revue humaine de chaque PR avant merge, pas de données sensibles confiées à l'agent.

## Sous le capot

- **Harness** : OpenCode uniquement. Provider Albert via `@ai-sdk/openai-compatible`.
- **Modèles Albert embarqués** : trois modèles, sélectionnables dans OpenCode via `/models`.

  | Modèle | Rôle | Usage type | Contexte |
  |---|---|---|---|
  | `Mistral-Medium-3.5-128B` | **`model`** (défaut) | Usage agentique principal : édition multi-fichiers, refacto, tool calling. | 128k |
  | `DeepSeek-V4-Flash` | **`small_model`** | Tâches légères et rapides (titres, résumés, sous-étapes). | 384k |
  | `Qwen/Qwen3.6-27B` | disponible (non défaut) | **Multimodal (vision)** : lire un screenshot, une maquette DSFR, un rendu d'UI. Sélection : `albert/Qwen/Qwen3.6-27B`. | 256k |

  Pour changer le modèle par défaut d'un projet, édite `model` dans son `opencode.json`.
- **Config** : `opencode.json` de **portée projet** (jamais le global de l'utilisateur, qui peut avoir d'autres providers).
- **Skills** : `etalab-ia/skills` cloné dans un cache (`~/.config/opencode/.albert-skills-cache`) et symliqué dans le dossier scanné par OpenCode, mis à jour à chaque démarrage de VM. Les skills perso existantes ne sont jamais écrasées.
- **MCP** : `data-gouv` (remote), `context7` (remote, **optionnel** — sans `CONTEXT7_API_KEY` on peut l'ignorer ; clé API via https://context7.com/plans si besoin), `playwright` et `chrome-devtools` (local).
  Note : sans clé, le MCP context7 s'affiche en erreur dans la VM → le désactiver dans `opencode.json` si gênant.
- **Conventions** : `AGENTS.md` par profil (OpenCode lit `AGENTS.md`, ignore `CLAUDE.md`). Isolation physique, aucun merge.

Docs : [OpenCode](https://opencode.ai/docs/fr) · [Albert API](https://doc.incubateur.net/alliance/albert-api) · [agent-vm](https://github.com/sylvinus/agent-vm) · [Skills État](https://github.com/etalab-ia/skills)

## Dépannage

- **`agent-vm: command not found` juste après l'install** → le shim est posé sur le PATH. Si vraiment absent, ouvre un nouveau terminal pour recharger le PATH.
- **`Base VM not found. Run 'agent-vm setup' first.`** → lance `agent-vm setup --disk 32` une seule fois (l'install le propose aussi automatiquement).
- **Je suis dans OpenCode mais pas connecté à Albert (pas de `/models`, `/mcp`, `/skills`)** → tu as lancé `agent-vm opencode` dans un dossier **sans `opencode.json`** (ex. le dépôt albert-code lui-même, ou un projet jamais scaffoldé). Scaffolde d'abord : `cd <ton-projet> && ~/albert-code/install.sh` (Phase B), puis relance `agent-vm opencode`.
- **Mon projet a déjà un `opencode.json`** → il est **conservé** (non-destructif). Vérifie qu'il contient le provider albert ; sinon Albert n'est pas câblé — ajoute à la main le bloc `provider.albert` + `model`/`small_model`.

## Désinstallation

```bash
./uninstall.sh
```

Retire le bloc albert-code du runtime VM, le cache et les symlinks skills. Préserve tes skills et ta config perso.

## Contribuer

Issues et PR bienvenues. Le dépôt suit ses propres conventions dans [`AGENTS.md`](AGENTS.md) ; le contexte et les décisions sont dans [`docs/PLAN.md`](docs/PLAN.md).

> **Développer Albert Code lui-même** : `cp config/opencode.template.json opencode.json` (déjà gitignoré) puis `agent-vm opencode` — `install.sh` ne scaffolde pas son propre dépôt.

---

Albert Code · département IA dans l'État (IAE), DINUM · Licence MIT

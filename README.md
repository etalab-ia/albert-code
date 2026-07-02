```
    _    _ _               _      ____          _
   / \  | | |__   ___ _ __| |_   / ___|___   __| | ___
  / _ \ | | '_ \ / _ \ '__| __| | |   / _ \ / _` |/ _ \
 / ___ \| | |_) |  __/ |  | |_  | |__| (_) | (_| |  __/
/_/   \_\_|_.__/ \___|_|   \__|  \____\___/ \__,_|\___|
```

# Albert Code

**Stack d'agentic coding souveraine pour l'État, en une commande : OpenCode + agent-vm + Albert API + skills de l'État + MCP.**

Albert Code assemble des briques existantes pour coder avec une IA souveraine, isolée, avec les standards de l'administration embarqués :

- **[Albert API](https://albert.api.etalab.gouv.fr)** : modèles souverains de l'État (hébergement SecNumCloud), provider OpenAI-compatible.
- **[agent-vm](https://github.com/sylvinus/agent-vm)** : sandbox Lima jetable. L'agent tourne en autonomie sans accès à l'hôte.
- **[OpenCode](https://opencode.ai)** : le harness (assistant de code en terminal).
- **[Skills de l'État](https://github.com/etalab-ia/skills)** : DSFR, accessibilité (RGAA), sécurité, data.gouv.
- **MCP** : data.gouv, context7, playwright, chrome-devtools.

Ce n'est pas un IDE ni un fork : de l'orchestration mince (scripts + config) au-dessus d'OpenCode.

> Statut : v1, en test avec des early adopters. Retours et issues bienvenus.

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
~/albert-code/install.sh   # Phase B : choix du profil + config projet
agent-vm opencode              # ouvre la bulle isolée + OpenCode
```

Dans la bulle, l'agent tourne en mode autonome (`--dangerously-skip-permissions`), sûr parce que tout est confiné dans la VM. Tu peux lui parler en français.

## Sécurité

- **Isolation noyau (Lima)** : l'agent n'a aucun accès à tes clés SSH, credentials, cookies ou sessions de l'hôte. La VM est jetable (`agent-vm rm`).
- **Secrets** : les clés (`ALBERT_API_KEY`, `CONTEXT7_API_KEY`) ne sont jamais versionnées ni loggées ; elles sont persistées dans le `~/.zshenv` de la VM en `chmod 600`.
- **Risque résiduel (prompt-injection)** : un contenu malveillant (page web, issue, fichier) pourrait pousser l'agent à exfiltrer une clé par le réseau. Bonnes pratiques : clé Albert **dédiée et révocable** (pas ta clé maître), revue humaine de chaque PR avant merge, pas de données sensibles confiées à l'agent.

## Sous le capot

- **Harness** : OpenCode uniquement. Provider Albert via `@ai-sdk/openai-compatible` (`model` = `Mistral-Medium-3.5-128B`, `small_model` = `DeepSeek-V4-Flash`).
- **Config** : `opencode.json` de **portée projet** (jamais le global de l'utilisateur, qui peut avoir d'autres providers).
- **Skills** : `etalab-ia/skills` cloné dans un cache (`~/.config/opencode/.albert-skills-cache`) et symliqué dans le dossier scanné par OpenCode, mis à jour à chaque démarrage de VM. Les skills perso existantes ne sont jamais écrasées.
- **MCP** : `data-gouv` (remote), `context7` (remote, **clé API requise** via https://context7.com/plans), `playwright` et `chrome-devtools` (local).
- **Conventions** : `AGENTS.md` par profil (OpenCode lit `AGENTS.md`, ignore `CLAUDE.md`). Isolation physique, aucun merge.

Docs : [OpenCode](https://opencode.ai/docs/fr) · [Albert API](https://doc.incubateur.net/alliance/albert-api) · [agent-vm](https://github.com/sylvinus/agent-vm) · [Skills État](https://github.com/etalab-ia/skills)

## Désinstallation

```bash
./uninstall.sh
```

Retire le bloc albert-code du runtime VM, le cache et les symlinks skills. Préserve tes skills et ta config perso.

## Contribuer

Issues et PR bienvenues. Le dépôt suit ses propres conventions dans [`AGENTS.md`](AGENTS.md) ; le contexte et les décisions sont dans [`docs/PLAN.md`](docs/PLAN.md).

---

Albert Code · département IA dans l'État (IAE), DINUM · Licence MIT

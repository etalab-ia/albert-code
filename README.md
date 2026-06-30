```
    _    _ _               _      ____          _
   / \  | | |__   ___ _ __| |_   / ___|___   __| | ___
  / _ \ | | '_ \ / _ \ '__| __| | |   / _ \ / _` |/ _ \
 / ___ \| | |_) |  __/ |  | |_  | |__| (_) | (_| |  __/
/_/   \_\_|_.__/ \___|_|   \__|  \____\___/ \__,_|\___|
```

# Albert Code

**Coder avec l'IA souveraine de l'État, dans une bulle isolée, avec les standards de l'administration déjà embarqués.**

Albert Code assemble en une commande tout ce qu'il faut pour développer avec un assistant IA :
- 🧠 **[Albert API](https://albert.api.etalab.gouv.fr)** — l'IA souveraine de l'État (hébergée SecNumCloud, aucune donnée ne part chez un éditeur étranger).
- 🫧 **[agent-vm](https://github.com/sylvinus/agent-vm)** — une « bulle » isolée où l'IA travaille en autonomie sans accès à tes mots de passe, clés ni fichiers personnels.
- 💻 **[OpenCode](https://opencode.ai)** — l'assistant de code dans ton terminal.
- 📚 **[Skills de l'État](https://github.com/etalab-ia/skills)** — DSFR, accessibilité (RGAA), sécurité (ANSSI), data.gouv… l'IA les applique automatiquement.
- 🔌 **Connecteurs (MCP)** — data.gouv, context7, playwright, chrome-devtools.

> Albert Code n'est pas un nouvel outil à apprendre : c'est OpenCode, préconfiguré et sécurisé pour l'État.

---

## Avant de commencer

Il te faut :

1. **Un Mac ou un Linux** (Windows pas encore supporté).
2. **Une clé Albert API.** Réservée aux agents publics. Si tu n'en as pas, demande un accès sur 👉 https://albert.api.etalab.gouv.fr
3. **Un compte GitHub** (pour que l'IA puisse proposer ses modifications sous forme de PR).

> 💡 Pas de clé Albert ? Tu peux quand même lancer l'installation : le script t'expliquera comment l'obtenir et tu reviendras après.

> 🔑 **Clé dédiée par projet (recommandé).** Crée une clé Albert spécifique pour Albert Code, pas ta clé perso maître. Une clé dédiée est révocable : en cas de fuite, tu la révoques sans toucher tes autres usages. Voir la [doc Albert API](https://doc.incubateur.net/alliance/albert-api).

---

## Installation

Ouvre le **Terminal** (sur Mac : `Cmd + Espace`, tape `Terminal`, `Entrée`), puis copie-colle ces 3 commandes, une par une :

```bash
git clone https://github.com/etalab-ia/albert-code.git ~/Dev/albert-code
cd ~/Dev/albert-code
./install.sh
```

> ⚠️ On installe dans `~/Dev/` exprès : la bulle isolée a besoin d'un chemin **sans espace** (donc pas dans Google Drive / iCloud).

À partir de là, **le script s'occupe de tout** et t'explique chaque étape. Il va :

1. Vérifier ta machine (système, mémoire, espace disque).
2. Te demander ta **clé Albert** (elle est stockée en sécurité, jamais affichée).
3. Te demander **ton contexte de travail** (voir ci-dessous) — c'est le seul vrai choix.
4. Installer la bulle (agent-vm), OpenCode et brancher Albert.
5. Te connecter à GitHub.
6. Télécharger les skills et brancher les connecteurs.
7. Faire un test de bout en bout pour confirmer que tout marche.

Compte ~10 minutes. Tu peux relancer `./install.sh` autant de fois que tu veux : il ne réinstalle que ce qui manque.

### Le choix du contexte

Albert Code te demande **dans quel écosystème tu travailles**, pour appliquer les bonnes conventions — et seulement celles-là :

| Choix | Conventions appliquées |
|---|---|
| **beta.gouv** | DSFR, pnpm, commits en français, Next.js / FastAPI |
| **La Suite** | UI Kit La Suite, yarn, commits gitmoji, Django |
| **IAE / Albert** | FastAPI, uv, Ruff (standards de l'équipe OpenGateLLM) |
| **Autre** | Aucune convention imposée — tu apportes ton propre `AGENTS.md` (ou pas) |

> 🔒 Les conventions ne se mélangent jamais : si tu choisis beta.gouv, tu n'auras **aucune** règle La Suite ou IAE.

### À propos de context7 (optionnel)

Le connecteur **context7** donne à l'IA la documentation à jour des librairies (React, DSFR…). Il nécessite une **clé API gratuite** à récupérer sur 👉 https://context7.com/plans
Le script te la demandera — tu peux appuyer sur `Entrée` pour l'ignorer et l'ajouter plus tard.

---

## Lancer un projet

Une fois l'installation finie, c'est tout simple. Va dans le dossier de ton projet et ouvre la bulle :

```bash
cd ~/Dev/mon-repo
agent-vm opencode
```

`agent-vm` ouvre la bulle isolée, OpenCode démarre avec Albert, tes skills et tes connecteurs. **Tu peux parler en français à l'assistant.** Exemples :

```
Crée une page d'accueil avec le DSFR et un formulaire de contact accessible.
Analyse ce dépôt et explique-moi son architecture.
Corrige les en-têtes de sécurité de mon site.
```

> 💡 Nouveau projet ? Crée d'abord le dossier (`mkdir ~/Dev/mon-repo && cd ~/Dev/mon-repo`), puis lance `agent-vm opencode`.

---

## Pourquoi c'est sûr

L'IA travaille en mode autonome (elle n'arrête pas de te demander la permission à chaque action) — **et c'est sans danger**, parce que tout se passe dans une bulle isolée :

- pas d'accès à tes clés SSH, mots de passe, cookies ou sessions de navigateur ;
- pas d'accès à tes autres fichiers ;
- la bulle est jetable : en cas de souci, on la supprime et on recommence.

> Règle d'or de l'État : on ne fait **jamais** tourner un agent de code directement sur sa machine. Albert Code applique ça par défaut.

### Risque résiduel : exfiltration par prompt-injection

L'IA peut lire du contenu (issues, pages web, fichiers du projet) qui contient des instructions malveillantes. Même si elle n'a pas accès à tes mots de passe, elle pourrait tenter d'exfiltrer ta clé Albert (par ex. via un appel réseau depuis la VM). Mitigations :

- **Clé dédiée** révocable (voir ci-dessus).
- La VM est isolée du réseau hôte (pas d'accès direct à tes cookies/sessions).
- Les permissions bash refusent `sudo` et `git push --force`.
- Reste vigilant : **valide chaque PR** avant merge, ne donne pas de données sensibles (RH, médicales, classifiées) à l'agent.

---

## Besoin d'aide ?

- 💬 Tchap : `[salon Albert Code à définir]`
- 🐛 Un bug, une idée ? Ouvre une issue sur le dépôt.
- 🗑️ Pour tout désinstaller proprement : `./uninstall.sh`

---

## Sous le capot (pour les profils techniques)

- **Harness** : OpenCode uniquement. Provider Albert via `@ai-sdk/openai-compatible` (`model` = `Mistral-Medium-3.5-128B`, `small_model` = `DeepSeek-V4-Flash`).
- **Skills** : clonées dans `~/.config/opencode/skills/` et mises à jour (`git pull`) à chaque démarrage de bulle — toujours fraîches.
- **Conventions** : un `AGENTS.md` par profil (OpenCode lit `AGENTS.md` nativement, ignore `CLAUDE.md`). Isolation physique, aucun défaut, aucun merge.
- **Secrets** : `ALBERT_API_KEY` (et `CONTEXT7_API_KEY` si fournie) persistés dans `~/.zshenv`, jamais en clair dans le dépôt ou l'historique.
- **MCP** : `data.gouv` (`https://mcp.data.gouv.fr/mcp`, lecture publique), `context7` (clé requise), `playwright`, `chrome-devtools` (debug navigateur, déjà dans agent-vm).

Documentation : [OpenCode](https://opencode.ai/docs/fr) · [Albert API](https://doc.incubateur.net/alliance/albert-api) · [agent-vm](https://github.com/sylvinus/agent-vm) · [Skills État](https://github.com/etalab-ia/skills)

---

*Albert Code — département IA dans l'État (IAE), DINUM. Licence MIT.*

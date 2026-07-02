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

---

## Notes

- **AC-R004 (prompt caching)** : à instruire avant tout scaling. Vérifier si Albert API expose du caching sur `chat/completions` ; sinon, arbitrer l'infra d'inférence. vLLM implémente le caching nativement.
- **AC-R005 (harness skills)** : investiguer le déclenchement des skills selon le harness (OpenCode / Vibe / Claude Code). Impacte la portabilité du bundle hors Claude Code.
- **AC-R006 / AC-R007** : détectés en dogfood (réinstall complète sur machine remise à zéro le 2026-07-02). R007 est bloquant onboarding (le « next step » affiché échoue). Fixes validés par S16 / S17.
- **AC-R008** : fuite récurrente de chemin absolu / username dans un dépôt public. L'instance (note S16) a été neutralisée au pré-vol du commit `7f84d9a` ; le fix durable est un **garde-fou CI** (T4.5), pas un edit ponctuel — sinon ça reviendra.

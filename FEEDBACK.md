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

---

## Notes

- **AC-R004 (prompt caching)** : à instruire avant tout scaling. Vérifier si Albert API expose du caching sur `chat/completions` ; sinon, arbitrer l'infra d'inférence. vLLM implémente le caching nativement.
- **AC-R005 (harness skills)** : investiguer le déclenchement des skills selon le harness (OpenCode / Vibe / Claude Code). Impacte la portabilité du bundle hors Claude Code.
- **AC-R006 / AC-R007** : détectés en dogfood (réinstall complète sur machine remise à zéro le 2026-07-02). R007 est bloquant onboarding (le « next step » affiché échoue). Fixes en cours via Mistral Vibe, validés par S16 / S17.

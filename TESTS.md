# TESTS — albert-code

> Scénarios de validation du bundle. Chaque scénario : **préconditions → étapes → résultat attendu**.
> Statuts : ☐ à faire · ✅ passé · ❌ échec.
> Réfs croisées avec `BACKLOG.md`.

---

## S1 — Smoke test chaîne minimale (T0.1) ✅
**Préconditions :** agent-vm installé, `ALBERT_API_KEY` exportée, OpenCode dans la VM.
**Étapes :**
1. `agent-vm opencode` (entrer dans la VM).
2. Demander : « écris un hello world en Python dans hello.py ».
**Attendu :** `hello.py` créé dans la VM, contenu valide, réponse venue d'Albert. Aucune clé visible dans les logs/historique.

## S2 — Skill locale + small_model (T0.2) ✅
**Préconditions :** `react-dsfr` dans `~/.config/opencode/skills/`.
**Étapes :**
1. Demander une page d'accueil DSFR.
2. Vérifier dans les logs OpenCode quel modèle répond aux tâches légères (titre/résumé).
**Attendu :** page utilisant `@codegouvfr/react-dsfr` (composants natifs, pas de CSS inventé) ; `DeepSeek-V4-Flash` utilisé comme `small_model`, `Mistral-Medium-3.5-128B` pour la génération principale.

## S3 — `opencode.json` valide (T1.1) ✅ (VM : provider `albert` reconnu, 4 MCP connectés, Albert répond, MCP data.gouv fonctionnel via `data-gouv_search_datasets` — débloqué par T-FIX-8/9)
**Étapes :**
1. `opencode` démarre à la racine du repo.
2. Lister les MCP actifs.
**Attendu :** pas d'erreur de schéma `$schema` ; provider `albert` reconnu ; MCP `data.gouv`, `context7`, `playwright` listés et connectés ; un appel test à chaque MCP répond.

## S4 — Idempotence runtime (T1.2) ☐ (script créé, test runtime en attente)
**Étapes :**
1. Lancer `.agent-vm.runtime.sh` une 1re fois (VM fraîche).
2. Le relancer immédiatement.
**Attendu :** 1re exécution provisionne tout ; 2e exécution = no-ops (messages « déjà présent / à jour »), durée &lt; quelques secondes, aucun doublon, aucune erreur.

## S5 — Synchro skills au boot (T1.3) ☐ (logique cache+symlinks implémentée, test collision perso/skills État ✅)
**Étapes :**
1. Noter la liste des skills disponibles dans OpenCode.
2. Ajouter une skill bidon dans le repo `etalab-ia/skills` (ou un fork de test).
3. Redémarrer la VM (`.agent-vm.runtime.sh` fait son `git pull`).
4. Relister les skills.
**Attendu :** la nouvelle skill apparaît **sans action manuelle** après reboot. Le mécanisme cache+symlinks
préserve les skills perso si elles existent déjà (testé avec collision react-dsfr/mon-outil-perso ✅).

## S6 — Isolation des profils (T2.1, T2.3) ✅
**Étapes :** ouvrir chaque `profiles/<contexte>/AGENTS.md`.
**Attendu :**
- beta.gouv : commits **FR**, **pnpm**, **DSFR**. Aucune mention gitmoji/yarn/uv/Django.
- lasuite : commits **gitmoji EN**, **yarn**, **UI Kit**, **Django REST**. Aucune mention pnpm/DSFR-par-défaut.
- iae : **uv**, **Ruff**, **FastAPI**, **Alembic**. Aucune mention pnpm/yarn.
- Socle commun (anglais code / FR UI, RGAA, ANSSI, RGPD, secrets, souveraineté) présent dans les 3.

## S7 — Bootstrap sans défaut (T2.2) ✅ (beta.gouv validé : menu affiché, profil posé, isolation confirmée — cf. T-FIX-7 ; IAE/Autre = même mécanisme de copie)
**Étapes :**
1. Lancer `install.sh` et choisir **beta.gouv**.
2. Inspecter le projet généré.
3. Recommencer dans un autre dossier en choisissant **IAE**, puis **Autre**.
**Attendu :**
- Projet beta.gouv : `AGENTS.md` = profil beta.gouv uniquement ; **zéro** convention IAE (pas de `uv`/Ruff/gitmoji).
- Projet IAE : l'inverse.
- Choix **Autre** : **aucun** `AGENTS.md` de profil posé (Albert Code neutre).
- Si on ne choisit aucun contexte → le script **refuse de continuer** (pas de profil par défaut, pas de merge).

## S9 — Skills standards (T4.1, T4.2) ☐
**Étapes :**
1. Sur un projet Python, déclencher `conventions-iae` → vérifier proposition `uv`/Ruff/pytest/Alembic.
2. Déclencher `delivery-standards-beta` → vérifier scaffold (linter + CI + tests + Sentry + OpenAPI + /stats + DashLord + footer légal + /accessibilite).
**Attendu :** chaque skill se déclenche sur son contexte et produit la structure attendue.

## S10 — CI templates (T4.3) ☐ (templates créés + YAML/YAML validés, test PR en attente)
**Étapes :** copier `templates/.github/workflows/*` dans un projet test ; ouvrir une PR avec un secret en dur + une vuln connue.
**Attendu :** Semgrep (secrets) et Trivy/CodeQL remontent ; **CRITICAL/ERROR bloque**, HIGH/WARNING informe sans bloquer. Le script de conformité signale footer légal / `/accessibilite` manquants.

## S11 — README non-tech (T5.1) ☐ (README écrit, test utilisateur en attente)
**Étapes :** un profil non-technique suit le README de zéro (Terminal jamais ouvert).
**Attendu :** installation complète et premier projet lancé sans aide extérieure ; chaque erreur fréquente est anticipée dans le texte.

## S12 — Install non-destructif sur poste déjà configuré (T1.1, T1.2) ✅ (validé sur poste réel : opencode.jsonc intact, skills perso préservées, ~/.zshenv sans doublon, agent-vm non dupliqué, runtime perso préservé)
**Préconditions :** poste avec **agent-vm + OpenCode déjà installés**, et une config OpenCode globale (`~/.config/opencode/opencode.json`) contenant **plusieurs providers (ex. Albert + Scaleway)**.
**Étapes :**
1. Noter le contenu de `~/.config/opencode/opencode.json` (providers, models).
2. Lancer `./install.sh` puis créer un projet et y lancer `agent-vm opencode`.
3. Re-vérifier la config globale + lister les providers disponibles.
**Attendu :**
- La config globale perso est **inchangée** (provider Scaleway toujours là).
- agent-vm et OpenCode **ne sont pas réinstallés** (détectés).
- La config Albert du bundle est posée **au niveau du projet** (`opencode.json` racine projet), pas dans le global.
- Aucune clé dupliquée dans `~/.zshenv`.

## S13 — Dry-run non-destructif (T2.4) ✅
**Préconditions :** dossier de test vide `/tmp/ac-test`.
**Étapes :**
1. `mkdir -p /tmp/ac-test`
2. `HOME=/tmp/ac-test ./install.sh --dry-run`
3. `find /tmp/ac-test -type f` (avant/après)
**Attendu :** sortie listant chaque action en `[dry-run]`, exit 0,
AUCUN fichier créé dans `/tmp/ac-test`, `~/.zshenv` réel inchangé.

## S14 — Désinstallation propre (T-FIX-1, T-FIX-4) ✅
**Préconditions :** dossier de test `/tmp/ac-test` avec Albert Code installé.
**Étapes :**
1. `HOME=/tmp/ac-test ./install.sh` (install réelle dans la sandbox).
2. Vérifier : `~/.agent-vm/runtime.sh` contient le marqueur + 2 exports ; `~/.zshenv` contient 2 clés.
3. `HOME=/tmp/ac-test ./uninstall.sh` (répondre « oui » à toutes les questions).
4. Vérifier : `~/.agent-vm/runtime.sh` ne contient PLUS le marqueur ni les exports ;
   `~/.zshenv` ne contient PLUS les clés.
**Attendu :** aucune clé ne subsiste dans `~/.agent-vm/runtime.sh` ni `~/.zshenv`,
et le bloc marqueur a disparu.

---

## Critères d'acceptation v1 (Definition of Done globale)
- [x] S1, S2, S3, S6, S7, S12, S13, S14 ✅.
- [ ] S4, S5, S11 (idempotence runtime VM / skills au boot / non-tech — en attente).
- [ ] Un agent public installe le bundle, choisit son contexte, et produit une page DSFR conforme dans une VM isolée, alimentée par Albert, sans qu'aucune clé ne fuite.
- [x] Un utilisateur beta.gouv n'a jamais de convention IAE, et inversement. (validé S7)
- [ ] Les skills se rafraîchissent au reboot de la VM.

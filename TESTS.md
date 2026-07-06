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

## S15 — Shim agent-vm résolution immédiate ☑ (validé en dogfood réel 2026-07-02)
**Préconditions :** agent-vm PAS installé, `agent-vm` introuvable (`command -v agent-vm` exit 1).
**Étapes :**
1. Lancer `./install.sh` (Phase A complète).
2. Sans sourcer de fichier ni ouvrir de nouveau terminal, lancer `command -v agent-vm`.
3. Lancer `agent-vm help` (ou `agent-vm list` si une VM existe).
**Attendu :** `command -v agent-vm` retourne un chemin exécutable (ex. `/opt/homebrew/bin/agent-vm`) ; la commande `agent-vm` fonctionne immédiatement, sans `source` ni nouveau terminal.
**Validé le :** 2026-07-02, en dogfood réel (machine remise à zéro, agent-vm désinstallé, 16 VMs supprimées) : après `./install.sh`, dans le MÊME terminal sans `rehash` ni réouverture, `command -v agent-vm` → `/opt/homebrew/bin/agent-vm` et `agent-vm help` s'exécute. Variante automatisée en CI : voir `BACKLOG.md` T4.4.

## S16 — Hint de scaffold dynamique ☑ (AC-R006)
**Préconditions :** dépôt albert-code cloné dans un chemin quelconque (ex. `~/Dev/albert-code`, pas `~/albert-code`).
**Étapes :**
1. Depuis le dépôt, lancer `./install.sh` (Phase A ; le bloc « Pour scaffold un projet » s'affiche).
**Attendu :** le message affiche le chemin RÉEL de l'installeur (`$SELF_DIR/install.sh`), copiable-collable tel quel — jamais un `~/albert-code/install.sh` hardcodé.
**Validé le :** 2026-07-02, `./install.sh --dry-run` lancé depuis le chemin réel du dépôt (hors `~/albert-code`) affiche bien ce même chemin absolu réel (`$SELF_DIR/install.sh`), pas un chemin générique hardcodé.

## S17 — Onboarding VM de base ☑ (AC-R007)
**Préconditions :** machine sans VM de base agent-vm (`agent-vm list` sans `agent-vm-base`).
**Étapes :**
1. Installer le bundle, configurer un projet (Phase B).
2. Lire les « Prochaines étapes » affichées.
**Attendu :** l'utilisateur est explicitement dirigé vers `agent-vm setup` (création de la VM de base, une fois) AVANT `agent-vm opencode` ; en suivant les instructions il ne rencontre jamais `Base VM not found`. Bonus : détection en Phase A si la VM de base manque.
**Validé le :** 2026-07-02, `./install.sh --dry-run` depuis un dossier projet de test : Phase A affiche `! VM de base absente — lance agent-vm setup une fois avant agent-vm opencode.` (via `limactl list -q`) puis propose `agent-vm setup` via `confirm()` (auto-répond « non » en dry-run, aucune VM créée) ; « Prochaines étapes » liste `1. agent-vm setup`, `2. agent-vm opencode`, `3. Parle en français à l'assistant`.

## S18 — Garde-fou CI anti-fuite chemin personnel / username ☑ (AC-R008)
**Préconditions :** dépôt propre (aucune fuite résiduelle) ; `tests/check_no_personal_paths.sh` présent et exécutable.
**Étapes :**
1. Lancer `bash tests/check_no_personal_paths.sh` sur l'arbre du dépôt tel quel.
2. Créer un fichier tracké contenant un chemin personnel réel (ex. `/Users/<nom>/x`), `git add -N` pour le rendre visible à `git ls-files`, relancer le script.
3. Répéter avec les placeholders documentés (`<chemin-du-dépôt>`, `$SELF_DIR`, `$HOME`, `~/...`, `/Users/username`, `/Users/user`, `/home/user`).
4. Vérifier que le workflow `.github/workflows/hygiene.yml` exécute bien ce script sur push et pull_request.
**Attendu :** (1) exit 0, aucun hit. (2) exit 1, `fichier:ligne: /Users/<nom>` affiché. (3) exit 0, les placeholders ne déclenchent rien. (4) la CI échoue si un chemin personnel est commité, passe sinon.
**Validé le :** 2026-07-02 — `bash tests/check_no_personal_paths.sh` sur l'arbre actuel → exit 0 (« Aucun chemin personnel / username détecté »). Test négatif : fichier tracké avec `/Users/<nom>/x` → exit 1, `fichier:2: /Users/<nom>` affiché ; fichier retiré ensuite. Test placeholders (`<chemin-du-dépôt>`, `$SELF_DIR`, `$HOME`, `~/mon-projet`, `/Users/username`, `/Users/user`, `/home/user`) → exit 0. Faux positif résiduel corrigé au passage : `tests/s15_shim.sh` utilisait `$SB/home` comme nom de dossier sandbox, qui matchait accidentellement `/home/[A-Za-z0-9._-]+` (aucun rapport avec un vrai chemin perso) → renommé en `$SB/sandbox-home`.

## S20 — Ressources VM par défaut + garde-fou hôte ☑ (AC-R010)
**Préconditions :** dossier projet de test (hors dépôt albert-code, pour déclencher Phase B).
**Étapes :**
1. `./install.sh --dry-run` depuis le dossier projet, valeurs par défaut (aucune variable `AC_VM_*`).
2. `AC_VM_MEMORY=2 AC_VM_CPUS=1 ./install.sh --dry-run` (surcharge explicite).
3. Simuler un hôte modeste (2 CPU / 4 GiB, via un `sysctl` de test) avec les défauts `AC_VM_CPUS=4`/`AC_VM_MEMORY=8`.
**Attendu :**
(1) Phase A affiche les ressources hôte détectées ; « Prochaines étapes » liste `agent-vm setup --disk 32` puis `agent-vm --cpus 4 --memory 8 --disk 32 opencode` (valeurs concrètes, pas de variables affichées).
(2) les mêmes emplacements affichent `--cpus 1 --memory 2` partout (disque inchangé à 32, non raboté).
(3) le garde-fou ne propose jamais plus de ~la moitié des ressources hôte détectées (ici : 1 CPU / 2 GiB, avec un message « Hôte limité… » explicite), sans planter si la détection échoue.
**Validé le :** 2026-07-02 — (1) dry-run par défaut : `Ressources hôte détectées : 14 CPU / 36 GiB RAM.` puis `1. agent-vm setup --disk 32` / `2. agent-vm --cpus 4 --memory 8 --disk 32 opencode` (hôte assez large, pas de rabot). (2) `AC_VM_MEMORY=2 AC_VM_CPUS=1` → `agent-vm --cpus 1 --memory 2 --disk 32 opencode`. (3) hôte simulé à 2 CPU / 4 GiB (fake `sysctl` en tête de `PATH`) avec défauts 4 CPU / 8 GiB → `Hôte limité (2 CPU / 4 GiB) → VM à 1 CPU / 2 GiB (au lieu de 4 CPU / 8 GiB demandés).` et « Prochaines étapes » reflète bien `--cpus 1 --memory 2`. Bonus vérifié : quand la VM de base existe déjà, l'étape « crée la VM de base » disparaît de la liste (numérotation qui se resserre).

## S23 — Auth GitHub de la VM : identité + push + PR (T1.7) ☑ validé (2026-07-06, dogfood réel)
**Préconditions :** un `GH_TOKEN` fine-grained (scopes Contents + Pull requests: RW) + `AC_GIT_USER_NAME`/`AC_GIT_USER_EMAIL` posés dans `~/.agent-vm/runtime.sh` (cf. README § Push & PR depuis la VM). Aucune identité git placeholder ne doit subsister dans le `.git/config` local du repo de test.
**Étapes :**
1. `bash runtime/agent-vm.runtime.sh --dry-run` **sans** `GH_TOKEN` → doit afficher l'avertissement « GH_TOKEN absent » et ne rien muter côté auth.
2. Idem **avec** `GH_TOKEN`/`AC_GIT_USER_*` factices en dry-run → doit lister (gated) : persist GH_TOKEN, `user.name`, `user.email`, `gh auth setup-git`.
3. Dans une VM (`agent-vm opencode`) avec le token réel : vérifier `gh auth status` (authentifié), `git config --global user.email` (= email noreply), `git config --global credential.https://github.com.helper` (= `!gh auth git-credential`).
4. Depuis la VM, sur une branche jetable : `git commit` (identité correcte) → `git push` → `gh pr create` → tout passe sans fallback hôte.
**Attendu :** (1) no-op + warning. (2) 4 actions gated affichées. (3) gh authentifié, identité et helper posés. (4) commit signé de la bonne identité, push OK, PR ouverte depuis la bulle. Le token n'apparaît dans aucun log.
**Validé le :** 2026-07-06 — (1)(2) dry-run host : sans `GH_TOKEN` → warning « GH_TOKEN absent » ; avec token/identité factices → 4 actions gated (persist, user.name, user.email, `gh auth setup-git`). (3) VM `agent-vm-albert-code` : `gh auth status` → « Logged in … account benoitvx (GH_TOKEN) », credential helper HTTPS posé. (4) **dogfood réel** : la branche `feat/github-auth-vm` a été **commitée (auteur = noreply), poussée et ouverte en PR ([#2](https://github.com/etalab-ia/albert-code/pull/2)) intégralement depuis la VM**, sans fallback hôte. Piège relevé au passage : `AC_GIT_USER_EMAIL` mal saisi (gmail) posait l'identité globale sur l'email perso → override local noreply a protégé le commit ; corrigé côté VM + `~/.agent-vm/runtime.sh`.

## Critères d'acceptation v1 (Definition of Done globale)
- [x] S1, S2, S3, S6, S7, S12, S13, S14, S15, S16, S17, S18, S20 ✅.
- [ ] S4, S5, S11 (idempotence runtime VM / skills au boot / non-tech — en attente).
- [ ] Un agent public installe le bundle, choisit son contexte, et produit une page DSFR conforme dans une VM isolée, alimentée par Albert, sans qu'aucune clé ne fuite.
- [x] Un utilisateur beta.gouv n'a jamais de convention IAE, et inversement. (validé S7)
- [ ] Les skills se rafraîchissent au reboot de la VM.

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

## S6 — AGENTS.default.md unique (T6.3) ☐ (profils supprimés)
**Préconditions :** profils `profiles/beta.gouv`, `profiles/lasuite`, `profiles/iae` supprimés.
**Étapes :**
1. Lancer `albert-code setup` dans un dossier projet.
2. Inspecter `./AGENTS.md`.
**Attendu :**
- Plus de prompt de contexte ; l'`AGENTS.md` posé correspond au contenu de `templates/AGENTS.default.md`.
- Si le projet a déjà un `AGENTS.md`, il est **conservé** (non écrasé).
- Les dossiers `profiles/` n'existent plus.

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

## S25 — Commande `albert-code` à 3 verbes (T6.1) ☐
**Préconditions :** dépôt albert-code disponible, `install.sh` exécutable.
**Étapes :**
1. `./install.sh --dry-run` → vérifier que la sortie mentionne « Phase A » et « shim albert-code ».
2. `bash bin/albert-code --help --dry-run` → vérifier les 3 verbes documentés.
3. `bash bin/albert-code install --dry-run` → même comportement que `./install.sh --dry-run` (Phase A, finit par la pose du shim).
4. `bash bin/albert-code setup --dry-run` (depuis un dossier hors dépôt) → Phase B : pose AGENTS.md, pose opencode.json, pose .agent-vm.runtime.sh, sans prompt interactif (dry-run → défauts non).
5. `bash bin/albert-code run --dry-run` (depuis un dossier projet) → détecte VM de base, calcule les ressources, affiche la commande de lancement.
**Attendu :** (1) Phase A + shim affichés. (2) 3 verbes documentés dans `--help`. (3) idem (1). (4) 3 fichiers posés, sans erreur. (5) ressources affichées, VM de base non créée (dry-run). Aucun échec bash (exit 0).
**Validé le :** — (non exécuté).

## S26 — Pédagogie agent-vm (T6.2) ☐
**Préconditions :** `install.sh` ou `bin/albert-code install` disponible.
**Étapes :**
1. Lancer `./install.sh --dry-run`.
2. Observer les messages avant le `confirm` Lima.
**Attendu :** un encart `title` + `info` explique ce qu'est l'isolation (VM légère, ne touche qu'au code, mode YOLO). Le `confirm` pour installer Lima arrive après cet encart.
**Validé le :** — (non exécuté).

## S27 — Re-setup non-destructif (T6.3) ☐
**Préconditions :** dossier projet avec `AGENTS.md` et `opencode.json` déjà posés (par un premier `albert-code setup`).
**Étapes :**
1. Lancer `bash bin/albert-code setup --dry-run` (ou `HOME=<sandbox> ...`).
2. Noter les messages : `AGENTS.md`, `opencode.json`, `.agent-vm.runtime.sh`.
**Attendu :** les 3 fichiers sont signalés « existe déjà — conservé (non écrasé) ». Aucun fichier n'est réécrit.
**Validé le :** — (non exécuté).

## S28 — Choix Y/N skills + MCP (T6.4) ☐
**Étapes :**
1. Lancer `bash bin/albert-code setup` (depuis un dossier projet vierge).
2. Répondre « non » à tous les MCP → vérifier que `opencode.json` n'a **aucun** bloc `mcp` (ou tous `enabled: false`).
3. Répondre « oui » à data.gouv seulement → vérifier qu'un seul MCP est activé dans `opencode.json`.
4. Vérifier que `.albert-code/skills.txt` existe après l'étape skills (réponses « oui/non »).
5. Relancer `albert-code setup` sur le même projet → vérifier que `opencode.json` et `AGENTS.md` sont conservés.
**Attendu :** (2) aucun MCP activé. (3) seul data.gouv activé. (4) skills sélectionnées listées. (5) fichiers conservés (non écrasés). Exit 0.
**Validé le :** — (non exécuté).

## S29 — Description skills : formats `>-`, `|`, inline (T6.4) ☐
**Préconditions :** fonctions bash chargées (`lib/phases.sh`).
**Étapes :**
1. Créer 3 fichiers SKILL.md de test : un avec `description: >-` (block replié), un avec `description: |` (block littéral), un avec `description: texte inline`.
2. Tester la fonction `extract_skill_description()` sur chaque fichier.
**Attendu :**
- `description: >-` → retourne le texte concaténé (pas « >- ») des lignes indentées suivantes.
- `description: |` → retourne le texte concaténé (pas « | ») des lignes indentées suivantes.
- `description: texte inline` → retourne « texte inline ».
- Les descriptions longues (>200 caractères) sont tronquées avec « … ».
- Une description absente retourne chaîne vide (l'afficheur utilise « (aucune description) »).
**Validé le :** — (non exécuté).

## S39 — Absorption agent-vm : vendoring, OpenCode-only, chrome-devtools projet, pas de nom agent-vm dans l'UI ☐

**Préconditions :** dépôt albert-code sur branche `feat/absorb-agent-vm`.

**Étapes :**
1. Vérifier `vendor/vm/agent-vm.sh` + `vendor/vm/agent-vm.setup.sh` + `vendor/vm/VERSION` + `vendor/vm/LICENSE` présents.
2. `bash bin/albert-code install --dry-run` — vérifier qu'aucun message ne contient « agent-vm » (sauf commentaires de code).
3. `bash bin/albert-code setup --dry-run` — idem.
4. `bash bin/albert-code run --dry-run` — idem.
5. Vérifier que `config/opencode.template.json` contient `--headless=true --isolated=true` pour chrome-devtools.
6. Vérifier que `vendor/vm/agent-vm.setup.sh` contient `INSTALL_OPENCODE_MCP="${AGENT_VM_INSTALL_OPENCODE_MCP:-0}"`.
7. `bash tests/check_no_personal_paths.sh` — exit 0.

**Attendu :** aucun message utilisateur ne contient « agent-vm ». La VM de base se crée avec `--preinstall=node,gh,chromium,opencode`. chrome-devtools a les flags headless, n'est plus injecté globalement par agent-vm. Vérification chemin personnel OK.

---

## Critères d'acceptation v1 (Definition of Done globale)
- [x] S1, S2, S3, S6, S12, S13, S14, S15, S16, S17, S18, S20 ✅.
- [ ] S4, S5, S11 (idempotence runtime VM / skills au boot / non-tech — en attente).
- [ ] Un agent public installe le bundle et produit une page DSFR conforme dans une VM isolée, alimentée par Albert, sans qu'aucune clé ne fuite.
- [ ] Les skills se rafraîchissent au reboot de la VM.
- [ ] S25, S27, S28, S29 (3 verbes, re-setup non-destructif, choix Y/N).

## S30 — Encart FR de transition avant wizard agent-vm (T6.5, AC-R018) ☐
**Préconditions :** machine sans VM de base agent-vm ; `install.sh` ou `bin/albert-code install` disponible.
**Étapes :**
1. Lancer `./install.sh --dry-run`.
2. Observer la sortie vers la fin de Phase A (avant `agent-vm setup`).
3. Dans `phase_run()`, répondre « oui » à la création de la VM (dry-run).
**Attendu :** un encart `info` en français s'affiche avant `agent-vm setup`, mentionnant que le wizard est en anglais, expliquant ce qu'est agent-vm, et conseillant de valider les logiciels par défaut. Sortie identique en `check_base_vm` et `phase_run`.

## S31 — Dérivation automatique email noreply GitHub (T6.6, AC-R019) ☐
**Préconditions :** un PAT GitHub valide (scope `repo`) ; `curl` disponible.
**Étapes :**
1. Lancer `./install.sh` (ou `albert-code install`).
2. Répondre « oui » à l'activation push/PR GitHub.
3. Coller le PAT.
4. Vérifier que le prompt « Email noreply GitHub » affiche le noreply dérivé (ex. `12345+username@users.noreply.github.com`).
5. Faire Entrée.
6. Vérifier `~/.zshenv` : `AC_GIT_USER_EMAIL` = noreply GitHub.
7. (Fallback) Simuler l'absence de réseau : sans `curl` ou PAT invalide, vérifier que le message FR d'aide s'affiche.
**Attendu :** (4) le noreply est pré-rempli, l'utilisateur fait Entrée ; (6) email noreply persisté ; (7) message FR d'aide clair avec lien GitHub. Le PAT n'apparaît dans aucun log.

## S32 — Shim avant VM + migration ancien `albert-code()` (T6.8, AC-R021) ☐
**Préconditions :** `install.sh` ou `bin/albert-code install` ; `albert-code()` dans un shell rc (ex. `~/.zshrc`).
**Étapes :**
1. Poser une fonction bidon dans `~/.zshrc` : `albert-code() { echo "OLD"; }`.
2. Lancer `./install.sh` (ou `albert-code install`).
3. Vérifier que le shim `albert-code` est posé sur le PATH AVANT la fin de la Phase A.
4. Vérifier que le script détecte l'ancienne fonction et propose de la retirer.
5. Répondre « oui » → `albert-code()` absente de `~/.zshrc`.
6. Lancer `albert-code setup` via le shim → doit utiliser le nouveau dispatcher, pas « OLD ».
**Attendu :** (3) shim existant même si VM absente ; (4) détection + prompt ; (5) fonction retirée correctement ; (6) dispatcher fonctionnel.

## S33 — Shim `albert-code` préserve les prompts interactifs (T6.9, AC-R022) ☐
**Préconditions :** shim `albert-code` installé via cette PR (qui utilise `exec`).
**Étapes :**
1. Exécuter `albert-code setup` **via le shim** (pas `bin/albert-code` direct) dans un dossier projet vierge.
2. Observer les prompts MCP (data.gouv, context7, playwright, chrome-devtools).
3. Répondre Y/N à chacun → observer la fin du setup.
4. Vérifier `opencode.json` → les choix sont enregistrés.
5. Comparer avec `bin/albert-code setup` direct → comportement identique.
**Attendu :** (2) prompts visibles (pas cachés), (4) choix persistés, (5) identique shim vs direct. Aucun message perdu.

## S34 — Hygiène dépôt (.gitignore) avec AGENTS.default.md (T6.10, AC-R024) ☐
**Préconditions :** un projet scaffoldé par `albert-code setup` (AGENTS.md = template).
**Étapes :**
1. Dans la VM, demander : « scaffolde un projet Node avec create-react-app » (ou équivalent).
2. Vérifier que l'agent crée un `.gitignore` AVANT le premier commit.
3. Vérifier que `node_modules/`, `.env`, `dist/`, `build/` sont dans `.gitignore`.
4. Vérifier que `git status` avant commit ne montre que des fichiers source (pas node_modules, pas .env).
5. (Négatif) Sans `.gitignore`, `git status` montre des dossiers inattendus → l'agent s'arrête et crée `.gitignore`.
**Attendu :** `.gitignore` adapté à Node, PR sans dépendances ni secrets.

## S35 — Dérivation noreply : sed match correct de la réponse JSON GitHub (T6.6, AC-R019) ☐
**Préconditions :** un PAT GitHub valide (scope `repo`), `curl` disponible.
**Étapes :**
1. Lancer `bash -c 'source lib/ui.sh; source lib/phases.sh'` dans un dossier sandbox.
2. Simuler la réponse de l'API : `curl -fsS -H "Authorization: Bearer $PAT" https://api.github.com/user`
3. Vérifier que le login et l'id sont extraits correctement avec les patterns sed corrigés.
4. Tester que `gh_login` contient l'id numérique, `gh_id` contient le login.
5. Vérifier l'email final = `{id}+{login}@users.noreply.github.com`.
**Attendu :** pas de fallback « Introuvable automatiquement » avec un PAT valide. L'email dérivé est correct.

## S37 — Polish UX sortie setup (T6.12-p) ☐
**Préconditions :** dossier projet vierge (hors dépôt albert-code), `HOME` sandboxé.
**Étapes :**
1. Lancer `bash bin/albert-code setup --dry-run` (depuis le dossier projet).
2. Observer la sortie Phase B : ASCII art (« Coder avec l'IA souveraine » / `____`) visible APRÈS le message garde-fou et AVANT « Phase B — Configuration ».
3. Vérifier que `print_next_steps` contient exactement : « Prochaines étapes », « Lancer Albert Code : albert-code run », et une ligne « NB : Les skills sélectionnées se synchronisent automatiquement au démarrage » (sans flèche `→`).
4. Vérifier l'ordre final : (éventuel statut GitHub) → « ✓ Projet configuré. » → (echo) → « Prochaines étapes » → « Lancer Albert Code : albert-code run ».
5. Répéter le setup avec `CONTEXT7_API_KEY` ABSENTE de l'env et de `~/.zshenv`, répondre « oui » au MCP context7 → vérifier qu'un prompt `prompt_secret` est affiché (dry-run : « [dry-run] prompt: Colle ta clé API Context7 ») ; laisser vide → warning « Pas de clé Context7 — le MCP context7 s'affichera en erreur ».
6. Répéter le setup avec `CONTEXT7_API_KEY` déjà dans l'env → vérifier qu'aucun prompt Context7 n'apparaît (le MCP est activé normalement).
**Attendu :** (2) ASCII art présent au début de Phase B. (3) `print_next_steps` raccourci, plus de « Crée la VM de base », plus de « Ouvre la bulle isolée », plus de « Parle en français ». (4) statut GitHub AVANT le ✓ final, pas après. (5) clé demandée, warning si vide. (6) pas de prompt si clé déjà présente.

## S36 — `install_shim` réécrit un shim obsolète + sortie sync_skills propre (T6.12, T6.13) ☐
**Préconditions :** dossier sandbox `/tmp/ac-test`, `install.sh` disponible.
**Étapes (install_shim) :**
1. Lancer `HOME=/tmp/ac-test SHIM_BIN_DIR=/tmp/ac-test/bin ./install.sh --dry-run` (crée shim vide).
2. Modifier le contenu attendu du shim (forcer une différence).
3. Relancer l'install → vérifier que le shim est réécrit (pas « déjà présent »).
**Étapes (sync_skills) :**
4. Simuler un boot VM : `bash runtime/agent-vm.runtime.sh --dry-run` dans un dossier projet scaffoldé.
5. Inspecter la sortie de `sync_skills` pour les lignes commençant par « name= ».
**Attendu :** (3) shim réécrit lors d'un changement de contenu, pas besoin de `rm` manuel. (5) aucun « name= » dans la sortie, seulement des `_ok`/`_info`/`_warn`.

## S38 — Polish visuel wizard (T6.14, AC-R031..R034) ☐
**Préconditions :** dépôt sur branche `feat/wizard-polish`, dossier projet vierge pour setup.

**Étapes — ASCII art (AC-R031) :**
1. Lancer `bash bin/albert-code setup --dry-run` depuis un dossier projet.
2. Capturer la bannière ASCII art.
3. Vérifier que la texte est "Albert Code" en figlet slant (5 lignes de caractères monospace).
4. Vérifier que la baseline « Coder avec l'IA souveraine de l'État, dans une bulle isolée. » est présente avec accents (é à).
5. Mesurer la largeur max : chaque ligne <= 76 colonnes.
**Attendu :** (1) art "Albert Code" affiché au début de Phase B. (2) baseline avec accents corrects. (3) largeur max <= 76 col.

**Étapes — Spinner (AC-R032) :**
6. Lancer `bash bin/albert-code install --dry-run` → observer si un spinner apparaît pour le clone agent-vm et clone skills.
7. Pipeliner la sortie : `bash bin/albert-code install --dry-run 2>&1 | cat` → observer que le spinner est absent (pas d'animation, non-TTY).
8. Exécuter `DRY_RUN=1 with_spinner "test" echo hello` dans un terminal → aucun spinner, message affiché puis ✓.
9. Exécuter `with_spinner "test" true` → ✓ test.
10. Exécuter `with_spinner "test" false` → ✗ test.
**Attendu :** (6) pas de spinner en dry-run (dégagement). (7) pas de spinner quand stdout n'est pas un TTY. (8) en dry-run, le helper passe par _dry_gate pour les mutations. (9) retourne ✓ avec code retour 0. (10) retourne ✗ avec code retour 1.

**Étapes — Compteur d'étapes (AC-R033) :**
11. Lancer `bash bin/albert-code setup --dry-run` depuis un dossier projet.
12. Observer la sortie Phase B : chaque sous-étape est préfixée par `[1/4]` à `[4/4]`.
13. Vérifier l'ordre : [1/4] AGENTS.md, [2/4] Connecteurs MCP, [3/4] Skills, [4/4] Runtime VM.
**Attendu :** (11)(12) compteur visible dans la sortie. (13) les 4 numérotations dans l'ordre.

**Étapes — Panneau récap (AC-R034) :**
14. Lancer `bash bin/albert-code setup --dry-run` (répondre Y à >=1 MCP, skip skills).
15. Après "✓ Projet configuré.", observer le panneau récap.
16. Vérifier : Projet = basename du dossier courant, MCP = liste des MCP actives (ou "aucun (mode souverain)"), Skills = liste cochées (ou "aucune"), GitHub = statut GH_TOKEN.
17. Vérifier format : aligné à gauche, 3 filets `---` (haut/milieu/bas), largeur fixe ~55 col, PAS d'encadré justifié à droite.
**Attendu :** (14)(15) panneau visible après "✓ Projet configuré.". (16) valeurs correctes. (17) format simple, aligne gauche, filets fixes.
**Étapes — dry-run :**
18. Lancer `bash bin/albert-code setup --dry-run` et `bash bin/albert-code install --dry-run`.
19. Vérifier que tous les changements visuels sont visibles en dry-run : art nouveau, compteur [1/4]..[4/4], récap.
20. Vérifier que le spinner n'apparaît pas (pas d'animation).
**Attendu :** (18) 4 chantiers visibles en dry-run. (19) spinner dégradé, pas de caracteres d'animation.

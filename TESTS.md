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
**Attendu :** page utilisant `@codegouvfr/react-dsfr` (composants natifs, pas de CSS inventé) ; `deepseek-v4-flash` utilisé comme `small_model` et pour la génération principale.

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
2. `bash bin/albert-code --help --dry-run` → vérifier les 4 verbes documentés.
3. `bash bin/albert-code install --dry-run` → même comportement que `./install.sh --dry-run` (Phase A, finit par la pose du shim).
4. `bash bin/albert-code setup --dry-run` (depuis un dossier hors dépôt) → Phase B : pose AGENTS.md, pose opencode.json, pose .agent-vm.runtime.sh, sans prompt interactif (dry-run → défauts non).
5. `bash bin/albert-code run --dry-run` (depuis un dossier projet) → détecte VM de base, calcule les ressources, affiche la commande de lancement.
6. `bash bin/albert-code update --dry-run` (depuis un dossier hors dépôt) → avertit « Aucun opencode.json », sans prompt interactif.
**Attendu :** (1) Phase A + shim affichés. (2) 4 verbes documentés dans `--help` (`install`/`setup`/`run`/`update`). (3) idem (1). (4) 3 fichiers posés, sans erreur. (5) ressources affichées, VM de base non créée (dry-run). (6) avertissement « Aucun opencode.json », exit 0. Aucun échec bash (exit 0).
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

## S31 — Dérivation automatique identité GitHub (T6.6, AC-R019, T2-CH2) ☐
**Préconditions :** un PAT GitHub valide (scope `repo`) ; `curl` disponible.
**Étapes :**
1. Lancer `./install.sh` (ou `albert-code install`).
2. Répondre « oui » à l'activation push/PR GitHub.
3. Coller le PAT.
4. Vérifier AUCUN prompt « Nom pour les commits » ni « Email noreply GitHub » (dérivation réussie → tout est automatique).
5. Vérifier le récap : ok "Compte GitHub : <login> <<id>+<login>@users.noreply.github.com>"
6. Vérifier `~/.zshenv` : `AC_GIT_USER_NAME` = login, `AC_GIT_USER_EMAIL` = noreply GitHub.
**Attendu :** (4) pas de prompts ; (5) récap correct ; (6) identité persistée. Le PAT n'apparaît dans aucun log.

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

## S40 — Auth GitHub : dérivation OK, token collé à mauvaise étape, token invalide (T2-CH2, AC-R036) ☐

**S40a — Dérivation API OK → pas de prompts nom/email, juste le récap**
**Préconditions :** `install.sh` disponible, `curl`, PAT valide (scope repo).
**Étapes :**
1. Lancer `bash lib/phases.sh` (sourcer) et appeler `_github_auth` avec un vrai PAT (ou stub `api.github.com/user`).
2. Répondre `o` au prompt d'activation, coller le PAT valide.
3. Observer la sortie.
**Attendu :** aucun prompt « Nom pour les commits » ni « Email noreply GitHub ». Le seul message est `✓ Compte GitHub : <login> <<id>+<login>@users.noreply.github.com>`. `AC_GIT_USER_NAME` = login, `AC_GIT_USER_EMAIL` = noreply.

**S40b — Token collé à la question o/N → message d'échec + avertissement sécurité + transition vers prompt masqué**
**Préconditions :** `install.sh` disponible, un token quelconque.
**Étapes :**
1. Lancer `install.sh`.
2. Au prompt « Activer le push et les PR GitHub depuis la VM ? [o/N] », coller un token (commence par `ghp_`, `github_pat_`, ou chaîne >30 car. non reconnue comme o/n).
3. Observer les messages.
**Attendu :** le script affiche `! On dirait que tu as collé ton token à la mauvaise étape (réponds d'abord o).` puis `! Ce token vient d'être affiché en clair dans le terminal : pense à le révoquer` et `! et à en régénérer un (github.com/settings/tokens).` puis `? Continuer la connexion GitHub ?`. Répondre oui → on passe DIRECTEMENT au prompt masqué `prompt_secret` (ETAPE TOKEN, pas de re-demande de [o/N]). Répondre non → `! GitHub non connecté.`

**S40c — Token invalide → message d'échec + retry sur prompt masqué (pas de [o/N])**
**Préconditions :** `install.sh` disponible, un token invalide.
**Étapes :**
1. Lancer `install.sh`.
2. Répondre `o` à l'activation, coller un token invalide.
3. Observer le message.
**Attendu :** le script affiche `! Échec : GitHub non connecté (token invalide ou API injoignable).` puis `! Tentative 1/3 — recolle ton PAT dans le champ masqué ci-dessous.` et le prompt masqué `prompt_secret` réapparaît (pas de [o/N]). Au 3e échec → fallback prompts manuels nom/email.

**S40d — Token valide au 2e essai après un premier échec → connexion directe, pas de fallback**
**Préconditions :** `install.sh` disponible, un token invalide puis un token valide.
**Étapes :**
1. Lancer `install.sh`.
2. Répondre `o` à l'activation, coller un token invalide.
3. Voir le message d'échec + prompt masqué réapparaître.
4. Coller un token valide.
**Attendu :** le script dérive l'identité, affiche `✓ Compte GitHub : <login> <<id>+<login>@users.noreply.github.com>` et persiste. Pas de fallback manuel, pas de prompts nom/email.

## S41 — VM présente → rattachement sans prompt ressource (T7.6, AC-R037, correctif v2)

**Préconditions :** VM projet `agent-vm-<projet>-<hash>` déjà présente dans `limactl list -q`
(Running **ou** Stopped). `bin/albert-code run` exécutable depuis un dossier projet.

**Étapes :**
1. S'assurer que la VM projet est listée : `limactl list -q | grep 'agent-vm-<projet>'`.
2. Lancer `bash bin/albert-code run --dry-run`.
3. Observer la sortie.

**Attendu :** la sortie contient `lancer la VM isolée` via `_vm run --tty zsh -l -c "opencode --auto"` **sans** `--cpus`,
`--memory`, ni `--disk`. Le message `VM déjà créée — rattachement sans re-réglage des ressources.`
est affiché. Aucun prompt « must be stopped to apply new resource settings » ne provient
d'agent-vm — car la condition testée est **présence** (pas `Running`), et le chemin de décision
est capture-first + `case` bash pur (zéro pipe, immunisé SIGPIPE/pipefail). Exit 0.
**Validation réelle** (le bug est une course SIGPIPE, pas reproductible à froid) :
`albert-code run` sur la VM déjà Running ne doit **plus** afficher le prompt « must be stopped ».
Si le prompt réapparaît, tracer avec `bash -x bin/albert-code run 2>/tmp/tr.txt` → vérifier
que la branche `*)` (flags) n'est pas prise.

## S42 — VM inexistante → flags ressources passés (T7.6, AC-R037, correctif v2)

**Préconditions :** VM projet absente de `limactl list -q` (jamais créée pour ce projet).
`bin/albert-code run` exécutable depuis un dossier projet.

**Étapes :**
1. Confirmer que la VM projet n'apparaît pas : `limactl list -q | grep -c 'agent-vm-<projet>'` → 0.
2. Lancer `bash bin/albert-code run --dry-run`.
3. Observer la sortie.

**Attendu :** la sortie contient
`_vm --cpus "${EFF_CPUS}" --memory "${EFF_MEM}" --disk "${AC_VM_DISK}" run --tty zsh -l -c "opencode --auto"`
avec les valeurs calculées de `EFF_CPUS`, `EFF_MEM`, `AC_VM_DISK`. Pas de message
« VM déjà créée ». Le verbe vendored `opencode` n'est plus appelé (PATH bash Lima, AC-R047).

## S43 — `base_vm_exists` détecte la VM de base sans faux négatif (T7.6, AC-R037, même racine SIGPIPE)

**Préconditions :** VM de base `agent-vm-base` présente dans `limactl list -q` (Running ou Stopped).

**Étapes :**
1. Vérifier que la base est listée : `limactl list -q | grep -c '^agent-vm-base$'` → 1.
2. Exécuter la fonction dans le contexte réel du binaire, en boucle pour attraper la course :
   ```sh
   source lib/phases.sh 2>/dev/null   # ou reproduire base_vm_exists()
   r=""; for i in $(seq 20); do ( set -euo pipefail; base_vm_exists ) && r="${r}T" || r="${r}F"; done; echo "$r"
   ```

**Attendu :** `TTTTTTTTTTTTTTTTTTTT` (20/20). Aucun `F`. Avant correctif (`limactl list -q | grep -q`),
un `F` intermittent sous `set -o pipefail` reproposait la création de la VM de base à chaque `run`.
Le correctif capture d'abord (`_list="$(limactl list -q 2>/dev/null || true)"`) puis teste par `case`
bash pur — zéro pipe, donc pas de course SIGPIPE.

## S44 — Garde-fou : `run` dans un projet non câblé pour Albert (T7.7, AC-R040)

**Préconditions :** un dossier **sans** `opencode.json` (ou avec un `opencode.json` sans `"albert"`).

**Étapes :**
1. Se placer dans un dossier jamais `setup` : `mkdir -p /tmp/ac-noalbert && cd /tmp/ac-noalbert`.
2. Lancer `bash <chemin>/bin/albert-code run --dry-run`.

**Attendu :** avertissement « Ce projet n'est pas configuré pour Albert… » + « Fais d'abord … albert-code
setup ». En dry-run/non-interactif, `confirm` répond non → `phase_run` **retourne sans lancer** la VM
(pas de « must be stopped », pas d'ouverture d'OpenCode sans Albert). Répéter avec un `opencode.json`
contenant `{"provider":{"scaleway":{}}}` (sans `albert`) → même avertissement. Avec un `opencode.json`
contenant `"albert"` → aucun avertissement, le lancement se poursuit.

## S45 — Avertissement au `setup` : `opencode.json` existant sans provider Albert (T7.7 ⊃ T1.6, ex-S22)

**Préconditions :** un dossier avec un `opencode.json` **sans** `"albert"` (ex. `{"provider":{"scaleway":{}}}`).

**Étapes :**
1. Lancer `albert-code setup` (ou déclencher `scaffold_opencode_json`) dans ce dossier.

**Attendu :** le fichier est **conservé** (non écrasé), mais le message n'est plus un simple « conservé » :
il signale explicitement que le provider Albert n'est pas déclaré et pointe le bloc `provider "albert"`
à ajouter (ou renommer/supprimer + relancer). Avec un `opencode.json` contenant déjà `"albert"` →
message « conservé (non écrasé) » inchangé.

**S40e — Fallback quand token invalide au 3e essai**
**Préconditions :** `install.sh` disponible, token invalide.
**Étapes :**
1. Lancer `install.sh`.
2. Répondre `o` à l'activation, coller un token invalide 3 fois (Entrée entre chaque pour abandonner).
3. Observer les prompts manuels.
**Attendu :** le script affiche le message d'aide FR `! Introuvable automatiquement...` puis demande le nom et l'email. Ne jamais persister GH_TOKEN.

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

---

## S-ctx-1 — Install ne mentionne plus Context7 (T6.15, AC-R038)

**Préconditions :** dossier sandbox `/tmp/ac-test-ctx`, `install.sh` ou `bin/albert-code install` disponible.

**Étapes :**
1. `HOME=/tmp/ac-test-ctx OPENCODE_CONFIG_DIR=/tmp/ac-test-ctx/.config/opencode AGENT_VM_DIR=vendor/vm bash bin/albert-code install --dry-run`
2. `grep -ciE 'context7|Context7|ctx7'` sur la sortie (hors ensure_vm_runtime).
3. Vérifier qu'aucun block A.4 (prompt clé Context7) n'apparaît dans la sortie.

**Attendu :** l'install ne mentionne pas « Context7 », ne demande pas de clé. Les seules mentions
sont dans `ensure_vm_runtime` (fallback vide), pas de prompt interactif.
**Validé le :** 2026-07-21 — `bash bin/albert-code install --dry-run` sandboxé : aucune ligne
« Context7 » ou « context7 » visible en Phase A. Le prompt de clé (A.4) a disparu.

## S-ctx-2 — Setup Y context7 sans clé → clé demandée, persistée hôte + runtime.sh, visible VM (T6.15, AC-R038)

**Préconditions :** aucun `CONTEXT7_API_KEY` dans l'environnement ni `~/.zshenv`.
Dossier projet vierge `/tmp/ac-test-project-ctx`.

**Étapes :**
1. Lancer `bash bin/albert-code setup --dry-run` depuis le dossier projet.
2. Répondre `o` à context7 (via dry-run ce n'est pas possible → on vérifie le code).
3. Vérifier dans `scaffold_opencode_json`, à l'intérieur de la branche
   `if confirm "Installer le connecteur Context7 ?"` : si Y à context7 et clé absente,
   `prompt_secret` est appelé, puis `persist_zshenv`.
4. Vérifier dans `phase_b` : `ensure_vm_runtime` est appelé après B.4 → la clé fraîchement
   persistée dans `~/.zshenv` est lue par le repli de `ensure_vm_runtime` (la branche qui relit
   la variable depuis `$ZSHENV` quand l'environnement ne la porte pas) et écrite
   dans `~/.agent-vm/runtime.sh` avec la vraie valeur (pas `''`).

**Attendu :** la clé est demandée au setup (pas à l'install), persistée dans `~/.zshenv` ET dans
`~/.agent-vm/runtime.sh`. Au `run` suivant, la VM voit `CONTEXT7_API_KEY` non vide.
**Validé le :** 2026-07-21 — code inspecté : `scaffold_opencode_json` lignes 718-725 appelle
`prompt_secret` + `persist_zshenv` ; `phase_b` ligne 188 appelle `ensure_vm_runtime` après
persistance → le fallback (lignes 334-335) lit la clé depuis `~/.zshenv` et l'écrit dans runtime.sh.
*(Numéros de ligne relevés au 21/07/2026. Le bloc a depuis été déplacé par T6.17 : voir l'étape 3
ci-dessus et S-ctx-6.)*

## S-ctx-3 — Setup N à context7 → aucune question de clé (T6.15, AC-R038)

**Préconditions :** `CONTEXT7_API_KEY` absente.

**Étapes :**
1. Lancer `bash bin/albert-code setup --dry-run` depuis un dossier projet.
2. Répondre `n` (ou dry-run) à la question context7 → `mcp_ctx7="false"`, le bloc de saisie
   de la clé, situé dans la branche du `confirm` Context7, n'est pas exécuté.
3. Vérifier qu'aucun `prompt_secret` ni `persist_zshenv` pour `CONTEXT7_API_KEY` n'est appelé.

**Attendu :** clé jamais demandée. Le MCP context7 n'est pas activé dans `opencode.json`.
**Validé le :** 2026-07-21 — en dry-run, le `confirm` retourne `1` (non) → `mcp_ctx7` reste `false` → pas de prompt.

## S-ctx-4 — Re-run setup sans duplication (T6.15, idempotence)

**Préconditions :** `~/.agent-vm/runtime.sh` existe avec le bloc marqué (écrit par un premier
`install` ou `setup`).

**Étapes :**
1. Lancer `bash bin/albert-code setup --dry-run` une 2e fois sur le même projet.
2. Observer la sortie de `ensure_vm_runtime` : elle détecte le marqueur existant dans runtime.sh,
   supprime l'ancien bloc et en réécrit un neuf avec les mêmes valeurs.
3. Vérifier qu'aucune duplication de lignes n'apparaît dans runtime.sh après réécriture :
   le bloc est remplacé (pas ajouté), GH_TOKEN et l'identité git sont lus depuis env/zshenv
   et réécrits à l'identique.

**Attendu :** pas de duplication dans runtime.sh. GH_TOKEN et AC_GIT_USER_* conservés.
L'opération est idempotente.
**Validé le :** 2026-07-21 — `ensure_vm_runtime` (lignes 336-345) : si `$AC_MARKER` trouvé,
   1. sed supprime du marqueur-début à marqueur-fin (ligne 373),
   2. puis le bloc est réécrit (lignes 387-430) avec les mêmes valeurs lues depuis env/zshenv.
   Pas de duplication possible.
*(Numéros de ligne relevés au 21/07/2026, depuis périmés. Repères stables : la fonction
`ensure_vm_runtime`, son test du marqueur `$AC_MARKER`, la suppression du bloc puis sa réécriture.)*

## S-ctx-5 — Dry-run : explications avant chaque question MCP (T6.16, AC-R039)

**Préconditions :** dossier projet vierge `/tmp/ac-test-project-ctx`.

**Étapes :**
1. `DRY_RUN=1 bash bin/albert-code setup --dry-run` depuis le dossier projet.
2. Observer les lignes avant chaque `confirm` MCP :
   - data.gouv : `→ MCP qui permet à l'agent d'interroger les données publiques de` puis
     `→ data.gouv.fr (catalogue, datasets, API tabulaire), en lecture.` puis le confirm.
   - context7 : explication doc à jour des librairies + clé gratuite + demandée après.
   - playwright : explication navigateur headless.
   - chrome-devtools : explication debug DOM/console/réseau/perf.
3. Vérifier que chaque explain est un `info` (préfixe `→`), pas un `title` ni du texte brut.
4. Vérifier que les confirms sont courts : `Installer le connecteur <nom> ?`

**Attendu :** chaque MCP a ≥1 ligne d'explication avant son Y/n. Les libellés sont textuellement
ceux du ticket T6.16. Aucune ligne ne dépasse 80 colonnes. Les accents sont corrects.
**Validé le :** 2026-07-21 — dry-run confirme les 4 paires explication+confirm. Textes correspondant
au ticket. Aucun tiret cadratin. `bash -n lib/phases.sh` OK.

## S-ctx-6 — La clé Context7 est demandée au moment de l'acceptation du connecteur (T6.17, AC-R048)

**Préconditions :** dépôt à jour, `lib/phases.sh` contenant la branche Context7 de
`scaffold_opencode_json`.

**Étapes :**
1. Relever les numéros de ligne des trois repères dans `lib/phases.sh` :
   - `grep -n 'Installer le connecteur Context7' lib/phases.sh` (confirm d'acceptation)
   - `grep -n 'Colle ta clé API Context7' lib/phases.sh` (demande de la clé)
   - `grep -n 'Installer le connecteur Playwright' lib/phases.sh` (question suivante)
2. Vérifier que les trois numéros sont strictement croissants dans cet ordre.

**Attendu :** la demande de clé est posée entre l'acceptation du connecteur et la question
Playwright : `num_context7 < num_cle < num_playwright`. Contrairement à l'état d'avant (où la clé
était demandée à la construction du JSON, après Playwright et Chrome DevTools), la promesse «
demandée juste après si tu acceptes » est désormais vraie.

**Note d'observabilité :** ce scénario est vérifié par **test d'ordre sur les numéros de ligne**,
pas par une sortie de `--dry-run`. En `--dry-run`, le `confirm` retourne toujours « non » (cf.
S-ctx-3) : la branche « oui » — et donc la demande de clé — n'est jamais exécutée ni observable en
dry-run. Le nouvel ordre ne peut donc pas être prouvé par une sortie de dry-run.

**Validé le :** 2026-09-03 — numéros relevés : `Installer le connecteur Context7` = 1088,
`Colle ta clé API Context7` = 1092, `Installer le connecteur Playwright` = 1103. Ordre
strictement croissant vérifié.

---

## S46 — Merge provider Albert dans opencode.json existant (T8.2)

**Préconditions :** `jq` installé sur le PATH ; un dossier projet avec un `opencode.json` contenant
un provider non-Albert (ex. Scaleway) et des MCP + permissions, sans `"albert"`.

**Étapes :**
1. Créer un fichier `opencode.json` de test avec un provider Scaleway :
   ```json
   {
     "provider": { "scaleway": { "npm": "@ai-sdk/scaleway", "name": "Scaleway", "options": { "baseURL": "https://api.scaleway.ai/v1", "apiKey": "{env:SCW_API_KEY}" } } },
     "mcp": { "data-gouv": { "type": "remote", "url": "https://mcp.data.gouv.fr/mcp", "enabled": true } },
     "permission": { "edit": "allow", "bash": {".*":"allow"} }
   }
   ```
2. Lancer `bash bin/albert-code setup --dry-run` dans ce dossier.
3. Observer la sortie : proposition de merge, dry-run affiche `[dry-run] merge du provider albert dans opencode.json`.
4. Relancer en réel (`DRY_RUN=0` avec un HOME sandboxé) et répondre `o` au confirm.
5. Vérifier le fichier résultant :
   - Provider `albert` présent avec son unique modèle `deepseek-v4-flash`
   - Provider `scaleway` toujours présent (non écrasé)
   - MCP `data-gouv` toujours présent
   - La sauvegarde `.bak` existe et contient l'original
6. Relancer le setup : le fichier est détecté comme ayant `"albert"` → message « conservé (non écrasé) ».

**Attendu :** (3) proposition affichée. (4) jq merge réussi. (5) les 4 vérifications passent — albert ajouté avec son modèle unique, scaleway intact, MCP intact, .bak présent. (6) idempotent, pas de duplication. Sans `jq` → avertissement T7.7 inchangé + info « installe jq ».

## S47 — Garde-fou OpenCode --auto dans la VM (T8.3, AC-R041)

**Préconditions :** `~/.agent-vm/runtime.sh` existe (post-install) ; une VM avec une version
ancienne d'OpenCode (ex. 1.2.9) ne supportant pas `--auto`.

**Étapes (validation du code injecté) :**
1. Lancer `bash bin/albert-code install --dry-run` (ou setup) → le bloc marqué de `ensure_vm_runtime`
   est réécrit avec le garde-fou T8.3.
2. Inspecter `~/.agent-vm/runtime.sh` (ou `/tmp/ac-test/.agent-vm/runtime.sh` sandboxé) :
   le bloc `$AC_MARKER … $AC_MARKER_END` contient les lignes :
   ```
     _oc_help="$(opencode --help 2>&1 || true)"
     case "$_oc_help" in
       *--auto*) : ;;
       *) echo "OpenCode trop ancien pour --auto - mise a jour..."; opencode upgrade || true ;;
     esac
     unset _oc_help
   ```
3. Vérifier qu'elles sont placées APRÈS les exports et AVANT `$AC_MARKER_END`.

**Validation réelle (VM) :**
4. Démarrer une VM où opencode est une ancienne version (simulable en renommant `opencode` ou
   en installant une version antérieure) → au boot, le runtime `~/.agent-vm/runtime.sh` s'exécute :
   `opencode --help` ne contient pas `--auto` → le garde-fou déclenche `opencode upgrade` → après
   upgrade, `opencode --auto` fonctionne → le TUI s'affiche au lieu du help.
5. Même VM avec opencode à jour → le `case` matche `--auto` → no-op, pas d'upgrade.
6. Vérifier que le garde-fou est en `|| true` : un échec d'upgrade ne casse pas le boot.

**Attendu :** (2)(3) le code injecté est correctement placé. (4) opencode 1.2.9 → upgrade auto → TUI.
(5) opencode à jour → no-op. (6) un échec (hors-ligne, etc.) n'empêche pas le runtime de continuer.

## S48 — Catalogue de modèles canonique dans l'opencode.json généré (T9.1)

**Étapes :**
1. Dans un dossier de test vierge, lancer `albert-code setup --dry-run` et capturer le JSON qui serait écrit.
2. Refaire le même contrôle sur un projet ayant déjà un `opencode.json` sans provider albert (chemin du merge jq).

**Attendu :** dans les deux cas, `provider.albert.models` contient exactement `deepseek-v4-flash` ; `model` et `small_model` valent tous deux `albert/deepseek-v4-flash` ; le contexte de `deepseek-v4-flash` est 131072 ; aucun alias (forme `vendor/Nom-Casse`) n'apparaît ; le JSON est valide (`jq .`). Sur le chemin du merge, les autres providers, les MCP et le bloc `permission` préexistants sont préservés.

## S49 — Détecter une VM projet clonée d'une base périmée et proposer sa recréation (T7.8, AC-R044)

**Préconditions :** aucune VM réelle requise. On teste la règle de décision du helper
`_project_vm_from_stale_base` (défini dans `lib/phases.sh`) en pointant `AGENT_VM_STATE_DIR` vers un
bac à sable temporaire et en y posant à la main les fichiers de version :
`.agent-vm-base-version` (version de la base) et `.agent-vm-version-<vm_name>` (version de la VM
projet), où `<vm_name>` est le nom renvoyé par `_agent_vm_name` pour le dossier courant. La VM n'est
jamais créée ni détruite.

**Étapes :**
1. **Cas 1 — base absente :** bac à sable sans `.agent-vm-base-version` (et sans fichier VM).
   Exécuter le helper (`bash bin/albert-code run` en dry-run, ou sourcer `lib/phases.sh` et appeler
   `_project_vm_from_stale_base "$vm_name"`).
2. **Cas 2 — version VM projet absente :** poser `.agent-vm-base-version` avec une valeur quelconque,
   laisser `.agent-vm-version-<vm_name>` absent.
3. **Cas 3 — versions différentes :** poser `.agent-vm-base-version` et
   `.agent-vm-version-<vm_name>` avec des valeurs distinctes.
4. **Cas 4 — versions identiques :** poser les deux fichiers de version avec la même valeur.

**Attendu :**
- (1) pas d'avertissement, lancement normal (le helper retourne 1) ;
- (2) détection, proposition de recréation (le helper retourne 0) ;
- (3) détection, proposition de recréation (le helper retourne 0) ;
- (4) pas d'avertissement (le helper retourne 1).
Dans les cas (2) et (3), en dry-run le `confirm` retourne « non » (défaut non-destructif) et la VM
n'est ni détruite ni recréée ; le message indique ce qui est perdu à la recréation (sessions OpenCode,
paquets installés dans la bulle, fichiers hors du dossier monté).

**Validé le :** — (à exécuter, bac à sable `AGENT_VM_STATE_DIR`).

## S50 — Rafraîchir un secret existant hôte + VM (T10.1, AC-R043)

**Préconditions :** un `GH_TOKEN` présent dans `~/.zshenv` (ou le runtime) mais invalide
(`curl api.github.com/user` renvoie 401).

**Étapes :**
1. Lancer `albert-code install` (ou `setup`), étape du wizard secret.
2. Observer : un prompt propose « garder / remplacer » un jeton présent mais invalide.
3. Répondre « remplacer », coller un jeton valide.
4. Vérifier `~/.zshenv` et le `.zshenv` de la VM : la valeur périmée est remplacée.

**Attendu :** aucun prompt ne saute la question sous prétexte qu'une ligne `export GH_TOKEN=` existe ;
un jeton révoqué est remplacé de bout en bout par le wizard, sans édition manuelle d'aucun `.zshenv`,
ni sur l'hôte ni dans la VM. Même logique pour `ALBERT_API_KEY` et `CONTEXT7_API_KEY`.

## S51 — Le push ne dépend plus d'un `.zshenv` de VM périmé (T10.2)

**Préconditions :** une VM dont la ligne `export GH_TOKEN=` du `.zshenv` est périmée.

**Étapes :**
1. Remplacer le jeton côté hôte (`~/.zshenv` du poste).
2. Lancer `albert-code run` une fois (un seul run).

**Attendu :** après rotation d'un jeton côté hôte, un seul run suffit pour que la VM voie le nouveau
jeton ; `gh auth status` dans la VM renvoie 200, plus 401.

## S52 — Jeton dédié à permissions minimales documenté et demandé (T10.3)

**Préconditions :** un compte GitHub administrateur d'organisation (peut créer un fine-grained token).

**Étapes :**
1. Lire le README § Push & PR depuis la VM.
2. Lancer le wizard de connexion GitHub.

**Attendu :** le README décrit un jeton dédié (fine-grained) à permissions minimales (pousser la
branche + `gh pr create` sur les dépôts du projet), et le wizard le réclame comme tel. Dans le cas
d'un non-admin d'organisation, le README expose l'alternative (jeton classique limité).

## S53 — Les commits produits par Albert Code portent le trailer Co-Authored-By (T10.4)

**Préconditions :** `templates/AGENTS.default.md` pose la consigne de trailer.

**Étapes :**
1. Laisser l'agent produire et commiter un changement dans un projet scaffoldé.
2. Inspecter `git log -1 --format=%B`.

**Attendu :** chaque commit porte un trailer `Co-Authored-By` nommant le modèle Albert utilisé
(ex. `albert/deepseek-v4-flash`).

## S54 — Détection et réparation des identifiants périmés dans un opencode.json existant (T9.2)

**Préconditions :** jq installé, `ALBERT_API_KEY` valide et joignable (`GET /v1/models` répond) ;
un dossier de test avec un `opencode.json` contenant le provider `albert` mais **un modèle périmé**
(ex. `deepseek-v4.5` ou un ancien id non renvoyé par le catalogue), avec **en plus** : un modèle ajouté
à la main et présent dans le catalogue, un autre provider (ex. `scaleway`), un MCP et un bloc
`permission` ; `model` et `small_model` pointent vers l'id périmé (donc en double).

**Étapes :**
1. Lancer `bash bin/albert-code setup --dry-run` dans ce dossier → le fichier est détecté comme
   branché sur Albert, comparé au catalogue → avertissement listant **une seule fois** l'id périmé
   (même s'il apparaît dans `models`, `model` ET `small_model`), `[dry-run] réparation`.
2. Vérifier qu'aucune écriture n'a eu lieu en dry-run (fichier inchangé, pas de `.bak`).
3. Relancer en réel (`DRY_RUN=0`, HOME sandboxé) et répondre `o` à la confirmation de réparation.
4. Vérifier que le `setup` **se poursuit jusqu'à la fin** : le récapitulatif et les prochaines étapes
   sont affichés, et `echo $?` rend **0** (étape qui n'abortit pas, malgré `set -e`). C'est le
   défaut bloquant corrigé : une réparation ne doit JAMAIS couper la phase en cours.
5. Vérifier le fichier résultant :
   - L'id périmé a été **retiré** de `provider.albert.models` ; le modèle ajouté à la main ET présent
     dans le catalogue est **conservé** ; `deepseek-v4-flash` est présent.
   - `model` / `small_model`, qui pointaient l'id retiré, ont été repositionnés sur
     `albert/deepseek-v4-flash`.
   - L'autre provider (`scaleway`), le MCP et le bloc `permission` sont **intacts** (non écrasés).
   - La sauvegarde `.bak` existe et contient l'original périmé.

**Attendu :** (1) avertissement + listing dédupliqué de l'id mort, dry-run ne répare pas. (2) aucune
écriture ni `.bak`. (3) réparation confirmée. (4) le setup se poursuit (récap + prochaines étapes
affichés) et le code de sortie est **0** — sinon fail bloquant. (5) les 5 vérifications passent :
périmé retiré, modèle manuel conservé, model/small_model repris, reste du fichier préservé, `.bak`
présent.


## S55 — Catalogue injoignable → on avertit, on ne modifie rien (T9.2)

**Préconditions :** un `opencode.json` existant avec un modèle périmé, mais **réseau coupé** pour
`albert.api.etalab.gouv.fr` (ou `ALBERT_API_KEY` absente).

**Étapes :**
1. Lancer `bash bin/albert-code setup` dans ce dossier.
2. Observer la sortie.

**Attendu :** un avertissement (« Catalogue Albert injoignable », « ALBERT_API_KEY absente » ou
« jq absent ») précède le message « conservé (non écrasé) ». Le fichier n'est **pas modifié**, aucun
`.bak` créé, exit 0. Un catalogue injoignable ne casse jamais un setup.

## S56 — opencode.json déjà à jour → no-op (T9.2)

**Préconditions :** un `opencode.json` branché sur Albert dont **tous** les identifiants correspondent
exactement au catalogue (`provider.albert.models = deepseek-v4-flash`, `model`/`small_model` =
`albert/deepseek-v4-flash`).

**Étapes :**
1. Lancer `bash bin/albert-code setup` dans ce dossier.

**Attendu :** message « déjà à jour avec le catalogue Albert — conservé », **aucune écriture**, **aucun
`.bak`** créé, exit 0.

## S57 — `albert-code update` répare + régénère le runtime, sans questions (T9.3)

**Préconditions :** un dossier projet avec un `opencode.json` branché sur Albert contenant un modèle
périmé ; `~/.zshenv` avec `ALBERT_API_KEY` ; `~/.agent-vm/runtime.sh` existant (bloc marqué).

**Étapes :**
1. Lancer `bash bin/albert-code update` dans ce dossier et répondre `o` à la confirmation.
2. Observer : **aucune** question MCP, **aucune** question skills (non interactif côté config).
3. Vérifier `opencode.json` → ids corrigés vers le catalogue, `.bak` présent.
4. Vérifier `~/.agent-vm/runtime.sh` → le bloc `$AC_MARKER … $AC_MARKER_END` est régénéré
   (exports + garde-fou OpenCode `--auto` T8.3), **sans duplication** du bloc.
5. Relancer `albert-code update` → le projet est à jour → « rien à faire ».

**Attendu :** (1) réparation appliquée. (2) aucune question MCP/skills. (3) opencode.json réparé avec
`.bak`. (4) bloc runtime régénéré, pas de doublon. (5) second run no-op avec récapitulatif « rien à
faire » / « à jour ».

## S58 — `albert-code update --dry-run` annonce sans rien écrire (T9.3)

**Préconditions :** un dossier projet avec un `opencode.json` à modèle périmé.

**Étapes :**
1. Lancer `bash bin/albert-code update --dry-run` dans ce dossier.

**Attendu :** le dry-run **annonce** la réparation (listing de l'id périmé, mention `[dry-run]`), mais
n'écrit **rien** : `opencode.json` inchangé, **aucun `.bak`**, runtime inchangé, exit 0.

## S59 — Abstention : clé absente côté hôte → valeur VM manuelle conservée (T10.2)

**Préconditions :** une VM dont `~/.zshenv` contient une ligne `export CONTEXT7_API_KEY='valeur-manuelle'`
posée à la main, alors que l'hôte ne définit pas `CONTEXT7_API_KEY` (variable absente ou vide).

**Étapes :**
1. Régénérer le runtime (`albert-code install` / `setup` / `update`).
2. Inspecter le bloc marqué `$AC_MARKER … $AC_MARKER_END` dans `~/.agent-vm/runtime.sh`.
3. Relancer un run (le runtime s'exécute à chaque boot de VM) et vérifier `~/.zshenv` de la VM.

**Attendu :** (1) aucune ligne `_ac_zsh_set CONTEXT7_API_KEY …` n'est émise dans le bloc marqué quand
l'hôte n'a pas de valeur (abstention : l'ancien comportement `export VAR=''` est supprimé). (2) le bloc
ne référence jamais `CONTEXT7_API_KEY`. (3) la valeur manuelle posée dans la VM est **conservée**
inchangée après un run : une absence côté hôte ne doit jamais écraser une valeur VM existante par un
vide.

## S60 — Deux `setup` successifs : bloc runtime ni dupliqué ni empilé (T10.2, idempotence)

**Préconditions :** un `RUNTIME_VM_FILE` cible (réel `~/.agent-vm/runtime.sh` ou fichier sandboxé)
existant ou absent, avec des valeurs hôte définies pour `ALBERT_API_KEY`, `GH_TOKEN`,
`CONTEXT7_API_KEY` et l'identité git.

**Étapes :**
1. Lancer `ensure_vm_runtime` (ou `albert-code setup`) une première fois.
2. Lancer `ensure_vm_runtime` (ou `albert-code setup`) une seconde fois.
3. Inspecter le fichier runtime résultat.

**Attendu :** après deux exécutions successives, le fichier contient **exactement** : un seul marqueur
`$AC_MARKER` (pas de bloc dupliqué), une seule définition de la fonction helper `_ac_zsh_set()` (pas
d'empilement), et une seule paire `_ac_zsh_set VAR …` + `export VAR='…'` par variable (ex. **2** lignes
pour `GH_TOKEN`, pas 4+). Le contenu hors bloc marqué n'est pas altéré. Les helpers ne s'empilent donc
jamais entre deux runs.

## S61 — Le helper `_ac_zsh_set` est régénéré sans here-doc imbriqué dans `$()` (non-régression bash 3.2)

**Préconditions :** `lib/phases.sh` et `lib/ui.sh` disponibles hors dépôt ; un bac à sable `$SB` ;
`RUNTIME_VM_FILE` et `ZSHENV` redirigés vers des fichiers temporaires.

**Pourquoi :** la racine du bug était le here-doc construit dans une substitution de commande
(`_ac_helper="$(cat <<'AC_HELPER' … )"`). Sous bash 3.2 (macOS) ce motif n'est pas parse correctement,
le corps du helper est évalué comme du code et le `*) printf …` fait exploser `$1` sous `set -u`
(« unbound variable » en ligne 448). `bash -n` ne détecte rien : c'est l'évaluation qui dérape.

**Étapes :**
1. Sourcer `lib/ui.sh` puis `lib/phases.sh` dans un shell `set -euo pipefail`.
2. Poser `RUNTIME_VM_FILE="$SB/runtime.sh"` et `ZSHENV="$SB/.zshenv"` (fichiers vides ou absents),
   avec au moins une valeur hôte (`ALBERT_API_KEY` en variable d'environnement).
3. Appeler `ensure_vm_runtime` et noter le code de retour.
4. Inspecter le bloc marqué `$AC_MARKER … $AC_MARKER_END` de `$SB/runtime.sh`.

**Attendu :** (1) `ensure_vm_runtime` se termine avec un **code 0**, sans erreur « unbound variable ».
(2) le bloc marqué contient bien la **définition complète** de la fonction `_ac_zsh_set()` (motif
`_ac_zsh_set() {`…`}`) telle qu'embarquée dans `lib/phases.sh`, et non du code exécuté.
(3) la définition extraite du bloc passe `bash -n` et fait **453 octets**.

## S62 — Échec en cours de régénération : le bloc runtime d'origine reste intact (atomicité)

**Préconditions :** `lib/phases.sh` et `lib/ui.sh` disponibles ; un bac à sable `$SB` ; un
`RUNTIME_VM_FILE` contenant **déjà** un bloc marqué précédent (ex. une ligne
`# --- albert-code : clés VM ---` et le bloc helper qui suit), entouré de contenu hors bloc
(« head » avant, « tail » après).

**Étapes :**
1. Forcer un échec **en cours de construction** : s'aviser que `ensure_vm_runtime` construit d'abord
   tout le nouveau contenu dans un fichier temporaire puis ne remplace le runtime qu'à la toute fin.
   Pour le provoquer, masquer `mktemp` pour qu'il renvoie un chemin non inscriptible :
   `mktemp() { printf '/nonexistent-dir/fail.$$'; }`, puis appeler `ensure_vm_runtime` sous
   `set -euo pipefail` (l'écriture du gabarit échoue → la fonction s'interrompt **avant** le `mv`).
2. Inspecter `$RUNTIME_VM_FILE` après l'échec.

**Attendu :** (1) `ensure_vm_runtime` échoue (code non nul, « No such file or directory »). (2) le
fichier runtime d'origine est **intact et complet** : le bloc marqué précédent est **toujours présent**,
y compris la définition de `_ac_zsh_set()`, et le contenu hors bloc (« head » / « tail ») n'a pas été
altéré ni tronqué. (3) la réécriture n'a donc **jamais** lieu en cas d'échec de construction : le
runtime n'est jamais laissé vide ou incomplet.

**Note dry-run :** avec `DRY_RUN=1`, l'exécution est sans effet (runtime inchangé) et **aucun fichier
temporaire ne subsiste** à l'issue de la fonction (les gabarits `mktemp` créés au vol sont nettoyés
quoi qu'il arrive).

## S65 — OpenCode lancé via `zsh -l`, sans filet symlink bash (T-FIX-16, AC-R047)

**Préconditions :** `runtime/agent-vm.runtime.sh` et `lib/phases.sh` du dépôt. Pas de VM requise
pour la partie automatisée (`tests/s65_opencode_bash_path.sh`).

**Étapes (automatisé) :**
1. `bash tests/s65_opencode_bash_path.sh`
2. Vérifier que `phase_run` lance via `zsh -l -c "opencode --auto"`, plus via `_vm opencode`.
3. Vérifier que `ensure_vm_runtime` (`lib/phases.sh`) ne contient plus d'`apply_append` posant un
   symlink opencode (~/.local/bin).
4. Dans un HOME sandboxé : binaire factice dans `~/.opencode/bin` et exécutable réel préexistant
   dans `~/.local/bin` → `check_opencode` signale la présence mais ne pose AUCUN symlink
   (ni ~/.local/bin ni ailleurs).
5. Relancer `check_opencode` → toujours aucun symlink (idempotent). Aucune suggestion `npm i -g`.

**Validation réelle (VM) :**
6. `albert-code run` dans un projet configuré → plus de `/bin/bash: line 1: opencode: command not found` ;
   le TUI OpenCode s'ouvre, avec les clés Albert chargées.

**Attendu :** (1) exit 0. (2)(3)(4)(5) assertions du script. (6) TUI, pas d'erreur PATH.

**Validé le :** 2026-09-01 — S65 automatisé OK (`tests/s65_opencode_bash_path.sh`). Cause racine
confirmée sur VM projet réelle : binaire présent dans `~/.opencode/bin`, `command -v` OK sous
`zsh -l`, `MISSING` sous `/bin/bash` (login et non-login).


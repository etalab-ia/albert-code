# BACKLOG — albert-code

> Tickets de construction du bundle, ordonnés. À dérouler avec OpenCode.
> Convention : chaque ticket a un **but**, une **définition de done (DoD)** et un renvoi aux scénarios de `TESTS.md`.
> Un ticket issu d'un retour utilisateur cite son finding via `<- AC-R###` (registre `FEEDBACK.md`).
> 🔴 bloquant v1 · 🟠 important · 🟡 nice-to-have

---

## EPIC 0 — Spike technique (dé-risquer la chaîne)

### T0.1 🔴 Smoke test chaîne minimale ✅ validé
**But :** prouver que agent-vm + OpenCode + Albert (`Mistral-Medium-3.5-128B`) fonctionnent ensemble.
**Tâches :**
- Installer agent-vm (Lima) ; `agent-vm setup`.
- Config OpenCode minimale avec provider Albert (`@ai-sdk/openai-compatible`, baseURL, `{env:ALBERT_API_KEY}`).
- Dans la VM : `opencode run "écris un hello world en python"` → vérifier réponse + écriture fichier.
**DoD :** un fichier est créé par l'agent dans la VM, via Albert, sans clé en clair. → `TESTS.md` S1 ✅.

### T0.2 🔴 Valider une skill + le small_model ✅ validé
**But :** confirmer chargement skill local + bascule modèle.
**Tâches :** placer `react-dsfr` dans `~/.config/opencode/skills/` ; demander une page DSFR ; configurer `small_model = DeepSeek-V4-Flash` et vérifier qu'il est utilisé pour les tâches légères.
**DoD :** page DSFR générée conforme + small_model actif. → `TESTS.md` S2 ✅.

---

## EPIC 1 — Config & runtime de référence

### T1.1 🔴 `opencode.json` (provider + MCP + permissions) ✅ implémenté
**But :** config OpenCode canonique du bundle.
**Tâches :**
- `provider.albert` (`@ai-sdk/openai-compatible`, models `Mistral-Medium-3.5-128B` + `DeepSeek-V4-Flash`).
- `model` / `small_model`.
- `mcp` (réf ci-dessous).
- `permission` : `edit`/`bash` raisonnables (allow dans la VM isolée, `deny` sur `git push *` hors VM à débattre), `webfetch: allow`.
- **Portée projet (non-destructif)** : écrire ce fichier à la **racine du projet cible**, PAS dans `~/.config/opencode/`. Le global perso de l'utilisateur (possiblement avec d'autres providers, ex. Scaleway) ne doit jamais être touché. OpenCode fusionne global+projet, projet prioritaire.

Config MCP de référence :
```jsonc
"mcp": {
  "data-gouv": { "type": "remote", "url": "https://mcp.data.gouv.fr/mcp", "enabled": true },
  "context7":  { "type": "remote", "url": "https://mcp.context7.com/mcp", "headers": { "Authorization": "Bearer {env:CONTEXT7_API_KEY}" }, "enabled": true },  // CLÉ API REQUISE
  "playwright": { "type": "local", "command": ["npx", "-y", "@playwright/mcp@latest"], "enabled": true },  // paquet à confirmer
  "chrome-devtools": { "type": "local", "command": ["npx", "-y", "chrome-devtools-mcp@latest"], "enabled": true }  // paquet à confirmer
}
```
- **data.gouv** : confirmé → `https://mcp.data.gouv.fr/mcp` (remote HTTP, lecture publique).
- **context7** : **clé API requise** (https://context7.com/plans) → stockée comme `CONTEXT7_API_KEY` dans `~/.zshenv`. Rendre le MCP **optionnel/skippable** si pas de clé.
- **chrome-devtools** : debug navigateur (DOM, console, réseau, perf). Déjà préinstallé dans la VM agent-vm (mais câblé pour Claude Code) → à déclarer côté OpenCode. Complémentaire de playwright (auto/tests).
- playwright / chrome-devtools : paquets npx à valider au câblage.
**DoD :** `opencode` démarre sans erreur de schéma, les 3 MCP sont listés et connectés (au moins data.gouv répond), Albert répond. → `TESTS.md` S3.

### T1.2 🔴 `.agent-vm.runtime.sh` idempotent ✅ implémenté
**But :** bootstrap reproductible de l'environnement dans la VM.
**Tâches (idempotentes, tester l'état avant chaque action) :**
- Persister `ALBERT_API_KEY` (et baseURL) dans `~/.zshenv` (piège auth shells non-interactifs). Idem `CONTEXT7_API_KEY` si fournie (optionnelle).
- Cloner/`git pull` `etalab-ia/skills` dans `~/.config/opencode/skills/`.
- Installer les serveurs MCP requis (npx/binaire).
- Vérifier OpenCode présent, sinon installer.
- **Non-destructif** : détecter une config agent-vm/OpenCode déjà en place et ne rien écraser (écritures additives uniquement : clone skills, clés `~/.zshenv` si absentes).
**DoD :** 2 exécutions consécutives = la 2e est une suite de no-ops en quelques secondes ; skills à jour après `git pull` ; une config OpenCode perso préexistante (ex. provider Scaleway) reste intacte. → `TESTS.md` S4, S5, S12.

### T1.3 🟠 Synchro skills au boot ✅ implémenté
**But :** garantir des skills toujours fraîches (réponse au « pas de maj auto »).
**DoD :** ajouter une skill dans le repo distant → après reboot VM, elle apparaît dans OpenCode sans action manuelle. → `TESTS.md` S5.

### T1.4 🟠 Ressources VM par défaut adaptées au code `<- AC-R010` ✅ implémenté
**But :** les défauts d'agent-vm (`1 CPU / 3 GiB / 10 GiB`) sont trop justes pour un agent de code ; en usage réel on tourne à `4 CPU / 8 GiB / 30 GiB`. agent-vm ne lit aucune variable d'env pour ses défauts (ressources uniquement via `--cpus/--memory/--disk`), et le **disque se fige à la création du template** (`agent-vm setup`) — il ne peut que grandir.
**Config proposée (surchargeable par env) :** `AC_VM_CPUS=4`, `AC_VM_MEMORY=8`, `AC_VM_DISK=32`.
**Tâches :**
- Définir ces défauts (env-overridables) en tête d'`install.sh`.
- `check_base_vm()` : `agent-vm setup --disk ${AC_VM_DISK}` (dimensionner le disque de base d'emblée).
- « Prochaines étapes » + README : recommander le 1er lancement dimensionné `agent-vm --cpus ${AC_VM_CPUS} --memory ${AC_VM_MEMORY} opencode` (cpu/mémoire s'appliquent au run et persistent au clone du projet).
- Garde-fou hôte : ne pas allouer plus que ~la moitié de la RAM/CPU de la machine (détecter `sysctl`/`nproc`, capper) — éviter 8 GiB sur un Mac 8 Go.
**DoD :** une install fraîche produit une VM ≥ `4 CPU / 8 GiB / ≥30 GiB` sans réglage manuel ; valeurs surchargeables par env ; pas de sur-allocation sur petite machine. → `TESTS.md` S20.

### T1.5 🟡 context7 conditionnel selon présence de la clé `<- AC-R011`
**But :** `context7` est `enabled: true` en dur dans `config/opencode.template.json` ; sans `CONTEXT7_API_KEY`, le MCP échoue au démarrage dans la VM (401 / bearer vide) et s'affiche « cassé ». Répond à la note de T1.1 restée ouverte.
**Tâches :** au scaffold (Phase B, pose de `opencode.json`), fixer `context7.enabled` selon la présence de `CONTEXT7_API_KEY` (env ou `~/.zshenv`) — `false` (ou MCP retiré) si absente ; `true` si présente. Post-patch du fichier posé (sed/jq) ou template conditionnel. Documenter le comportement.
**DoD :** install **sans** clé context7 → `opencode.json` posé a `context7.enabled: false` → aucun MCP en erreur dans la VM ; **avec** clé → `enabled: true`. → `TESTS.md` S21.

### T1.6 🟠 Scaffold : `opencode.json` existant sans provider `albert` `<- AC-R012`
**But :** dans un repo ayant déjà un `opencode.json`, le scaffold le conserve (non-destructif) → le provider `albert` n'est jamais ajouté → Albert ne se connecte pas dans la VM, sans alerte (juste « conservé »). Footgun silencieux.
**Tâches :** en Phase B, si `./opencode.json` existe déjà, détecter s'il contient le provider `albert` ; sinon → **avertir clairement** (« opencode.json existant sans provider Albert → Albert non câblé ») et proposer/documenter le merge du bloc `provider.albert` + `model`/`small_model` (jq/sed) sans écraser le reste. Ne jamais écraser silencieusement.
**DoD :** scaffold dans un repo avec `opencode.json` sans `albert` → message explicite (+ option de merge) ; avec `albert` déjà présent → info « rien à faire ». → `TESTS.md` S22.

### T1.7 ✅ Auth GitHub de la VM : commit OK, mais push + PR impossibles depuis la bulle `<- AC-R013` — résolu (validé 06/07/2026)
**But :** le README promet « l'agent pousse des PR depuis la VM », mais Albert Code ne configure dans la VM ni l'identité git (`user.name`/`user.email`), ni la clé SSH, ni de token `gh` → l'agent peut committer localement mais **ni pusher ni ouvrir la PR**. SSH = auth ≠ identité de commit.

**⚠️ Confirmé en test réel (06/07/2026)** — lors de l'ajout du modèle Qwen 3.6 (branche `feat/add-qwen-3.6`, commit `b9eb1e9`). Séquence observée dans la VM agent-vm :
- `git commit` → OK (l'identité était présente sur ce poste).
- `git push` → échec : ni auth HTTPS, ni host key SSH.
- `gh pr create` → échec : `gh` non authentifié (pas de `GH_TOKEN`).
- Fallback navigateur (`chrome-devtools new_page` sur l'URL `pull/new/…`) → échec : pas de navigateur ouvrable dans le sandbox.
- **Résultat : blocage total du push/PR côté VM.** Contournement utilisé : push + `gh pr create` **depuis l'hôte** (où `gh` est authentifié). → à documenter comme procédure intérimaire tant que T1.7 n'est pas implémenté.

**Tâches :** au setup (`ensure_vm_runtime` / runtime VM), configurer l'identité git de la VM — reprendre le `git config --global user.name/email` de l'hôte s'il existe, sinon prompt (**recommander l'email _noreply_ GitHub**, pas l'email perso) ; **et** régler l'auth push par l'une des voies (à trancher) : (a) injecter un `GH_TOKEN` fine-grained scopé dans l'env VM (jamais loggé, jamais commité), ou (b) injecter la clé SSH GitHub (cf. `runtime.example.sh` d'agent-vm) + `url.insteadOf` pour forcer SSH. Documenter aussi le fallback hôte (commit VM → push/PR hôte) pour les postes non configurés.
**✅ Implémenté (06/07/2026, branche `feat/github-auth-vm`)** — voie (a) retenue : `GH_TOKEN` fine-grained (SSH écarté car `gh pr create` exige un token, pas une clé). Câblage générique **sans secret** dans `runtime/agent-vm.runtime.sh` (`setup_github_auth`) : si `GH_TOKEN` présent → persiste le token, pose l'identité git globale (`AC_GIT_USER_NAME`/`AC_GIT_USER_EMAIL`), `gh auth setup-git`. Le secret reste dans `~/.agent-vm/runtime.sh` (perso, hors dépôt). Doc utilisateur : README § « Push & PR depuis la VM ». Reste : **test end-to-end en VM fraîche** (DoD ci-dessous) + nettoyage de l'identité placeholder `albert-code-user` dans les `.git/config` locaux.
**DoD :** dans une VM fraîche, l'agent fait un commit de la bonne identité + push + `gh pr create` sans config manuelle. → `TESTS.md` S23.
**✅ Validé (06/07/2026)** — dogfood réel : la PR [#2](https://github.com/etalab-ia/albert-code/pull/2) (le câblage lui-même) a été commitée, poussée et ouverte **intégralement depuis la VM**. Voir `TESTS.md` S23. Suite → T1.8.

### T1.8 🟠 Intégrer l'auth GitHub à l'installeur (zéro config manuelle) `<- T1.7`
**But :** T1.7 a livré le *câblage* (`setup_github_auth` dans le runtime), mais l'utilisateur doit encore **créer un PAT et coller un bloc à la main** dans `~/.agent-vm/runtime.sh` (section README « Push & PR depuis la VM »). Sans cette étape, push/PR restent indisponibles (échec désormais *explicite* : « GH_TOKEN absent → voir README », plus silencieux). Objectif : rendre l'auth GitHub aussi transparente que les clés Albert, posées d'office par `install.sh`.
**Tâches :**
1. **Prompt token à l'install** (`ensure_vm_runtime`, Phase A) : proposer (optionnel, skippable) de saisir un `GH_TOKEN`, l'écrire dans le **bloc géré** `# --- albert-code : clés VM ---` aux côtés d'`ALBERT_API_KEY` (même pattern grep-guard + `chmod 600`, jamais loggé). Supprime la fragilité actuelle du **2ᵉ bloc manuel qui partage le marqueur de fin** `# --- /albert-code ---`.
2. **Identité + garde-fou email** : demander/dériver `AC_GIT_USER_NAME` + `AC_GIT_USER_EMAIL`, avec **validation « doit finir en `users.noreply.github.com` »** (aurait attrapé le gmail saisi le 06/07). Proposer de dériver le noreply depuis le compte `gh` de l'hôte si dispo.
3. **Gotcha de rotation** : documenter (README) + garde-fou — un `GH_TOKEN`/email déjà persisté dans le `~/.zshenv` de la VM n'est **pas** mis à jour par un changement côté hôte (grep-guard). Prévoir un chemin de mise à jour (réécrire la ligne `~/.zshenv` de la VM, ou `agent-vm rm` documenté).
4. **Next-steps de l'install** : mentionner l'auth GitHub dans « Prochaines étapes » (actuellement absente).
**DoD :** sur un poste vierge, `install.sh` propose l'auth GitHub ; après acceptation, une VM fraîche pushe + ouvre une PR sans aucune édition manuelle de `runtime.sh` ; un email non-noreply est refusé avec un message clair. → `TESTS.md` S24.
**⏳ Implémenté (06/07/2026, branche `feat/github-auth-installer`)** — sous-points 1 (prompt token dans Phase A), 2 (identité + garde-fou email noreply, 3 tentatives) et 4 (next-steps) faits ; token jamais loggé (vérifié par canari en dry-run). **Reste** : sous-point 3 (gotcha de rotation — mise à jour d'un `~/.zshenv` VM déjà écrit) → PR séparée. Validation S24 à finaliser.

---

## EPIC 2 — Profils & bootstrap (séparation des conventions)

### T2.1 🔴 Structure `profiles/` ✅ implémenté
**But :** isoler physiquement les conventions par contexte.
**Tâches :** créer `profiles/{beta.gouv,lasuite,iae}/AGENTS.md` (+ set de skills + bouts d'`opencode.json` spécifiques). Reprendre `etalab-ia/skills/templates/instructions/{beta.gouv,LaSuite}.md` ; créer le profil `iae` (house style OpenGateLLM). Plus un choix **`autre`** = **aucune convention imposée** (ne copie aucun `AGENTS.md` de profil ; l'utilisateur fournit le sien s'il veut).
**DoD :** 3 profils complets + option `autre` neutre, zéro convention partagée divergente entre eux (commits, package manager, design system). → `TESTS.md` S6.

### T2.2 🔴 `install.sh` / bootstrap qui DEMANDE le contexte ✅ implémenté
**But :** aucun profil par défaut, aucun merge.
**Tâches :** prompt « Quel contexte ? (1) beta.gouv (2) La Suite (3) IAE (4) Autre » → copie le bon `AGENTS.md` + installe le bon set de skills ; **(4) Autre = ne copie rien** (neutre). Refuser de continuer si rien n'est choisi.
**DoD :** choisir beta.gouv → le projet ne contient AUCUNE convention IAE (commits gitmoji/uv absents), et inversement ; choisir Autre → aucun `AGENTS.md` de profil n'est posé. → `TESTS.md` S6, S7.

### T2.3 🟠 Couche universelle commune ✅ implémenté
**But :** factoriser le socle (anglais code / FR UI, RGAA, ANSSI, RGPD, secrets, souveraineté) sans casser l'isolation.
**DoD :** le socle est présent dans les 3 profils, les divergences restent dures par profil. → `TESTS.md` S6.

### T2.4 🔴 Mode --dry-run + sandbox de test (testabilité) ✅ implémenté
**But :** pouvoir tester install.sh / runtime sur une machine déjà configurée sans rien modifier.
**Tâches :**
- `install.sh` et `runtime/agent-vm.runtime.sh` acceptent `--dry-run` : chaque action
  (write fichier, clone/pull skills, append `~/.zshenv`, install outil) est AFFICHÉE
  préfixée `[dry-run]` mais PAS exécutée ; exit 0.
- Toutes les écritures passent par UNE fonction unique (ex. `apply()`), qui en dry-run
  logge au lieu d'exécuter → aucun chemin ne peut « oublier » le dry-run.
- Respecter des overrides d'env pour sandboxer les écritures :
  `OPENCODE_CONFIG_DIR` (défaut `~/.config/opencode`) et un `HOME` configurable
  pour `~/.zshenv` → tout peut être redirigé vers un dossier jetable.
- `--help` documente `--dry-run` et ces variables.
**DoD :** `HOME=/tmp/ac-test ./install.sh --dry-run` n'écrit AUCUN fichier
(diff de `/tmp/ac-test` avant/après = vide), affiche le plan complet, exit 0. → TESTS S13.

---

## EPIC 4 — Standards & CI

### T-FIX-1 🟠 uninstall.sh laisse les clés + install non-idempotent ✅ implémenté
**But :** corriger le marqueur cassé (casse-sensible) et le retrait awk défectueux.
**Tâches :**
- Définir UNE constante marqueur unique (`AC_MARKER`) utilisée à l'écriture (install.sh) ET aux tests (install.sh idempotence, uninstall.sh retrait).
- Réécrire le retrait dans uninstall.sh : `grep -vE` pour supprimer marqueur + lignes `export ALBERT_API_KEY=` / `export CONTEXT7_API_KEY=`.
**DoD :** install.sh relancé n'ajoute pas un 2e en-tête (S4) ; uninstall.sh retire le bloc ET les 2 clés de ~/.agent-vm/runtime.sh (S14).

### T-FIX-2 🟠 Posture sécurité clé/bash ✅ implémenté
**But :** durcir la posture sécurité (clé, exfiltration, permissions bash).
**Tâches :**
- Recommander/imposer une clé Albert DÉDIÉE par projet (révocable) → README + AGENTS.
- Documenter le risque résiduel d'exfiltration (prompt-injection) dans README + AGENTS.
- Corriger la deny-list git push : `git push.*(--force|-f | --force-with-lease)` (l'ancienne ne matchait pas `... main --force`).
**DoD :** README + AGENTS documentent clé dédiée + exfiltration ; config bash deny-list corrigée.

### T-FIX-3 🟡 Quick wins ✅ implémenté
**But :** durcissements rapides.
**Tâches :**
- `templates/.github/workflows/security.yml` : pin `trivy-action@0.28.0` (au lieu de `@master`).
- `chmod 600` sur `~/.zshenv` et `~/.agent-vm/runtime.sh` après création (contiennent une clé).
- `local val` dans `prompt_secret`/`prompt_input` (`lib/ui.sh`).
- Ne pas `source agent-vm.sh` en `--dry-run` (`install.sh`).
**DoD :** bash -n OK ; dry-run ne source rien ; permissions 600 appliquées.

### T-FIX-4 🟠 Test désinstallation ✅ implémenté
**But :** valider la désinstallation complète.
**DoD :** S14 — après install puis uninstall, aucune clé ne subsiste dans `~/.agent-vm/runtime.sh` ni `~/.zshenv`, et le bloc marqueur a disparu.

> **Note numérotation :** T-FIX-5 à T-FIX-10 ont été utilisés lors de la revue sécurité/robustesse (banner, skills sync, prompt_choice, clé VM 401, migrations — cf. `git log`), livrés puis retirés du backlog. Les tickets issus des retours utilisateurs reprennent donc à T-FIX-11 pour éviter toute collision.

### T-FIX-11 🔴 `agent-vm` résolu immédiatement après install ✅ implémenté `<- AC-R001, AC-R002`
**But :** `agent-vm` est une fonction shell (sourcée) ; après `./install.sh`, elle n'est pas chargée dans le terminal courant → « command not found », y compris après relance.
**Tâches :** shim exécutable `agent-vm` posé dans un dossier déjà présent dans `$PATH` (source `agent-vm.sh` + dispatch) ; atténuer les messages « déjà sourcé » trompeurs ; vérif finale `command -v agent-vm`.
**DoD :** `agent-vm` résout dans le même terminal juste après install, sans réouverture. → `TESTS.md` S15.

### T-FIX-12 🟡 Retirer les chemins `~/Dev` en dur `<- AC-R003` ✅ implémenté
**But :** `~/Dev` est une convention personnelle ; ne doit pas apparaître en dur dans le code, le README ni la doc.
**Tâches :** défauts `AGENT_VM_DIR`/`ALBERT_CODE_REPO` → emplacement neutre (XDG / `SELF_DIR`), identiques install/uninstall ; placeholders neutres sans espace dans README/doc ; grep de contrôle 0 hit.
**DoD :** `grep -rE '\$HOME/Dev|~/Dev'` (hors `.git`) ne renvoie rien ; `--dry-run` cohérent install/uninstall.

### T-FIX-13 🟠 Hint de scaffold dynamique (`$SELF_DIR`) `<- AC-R006` ✅ implémenté
**But :** le message de scaffold (`phase_b`, quand on est dans le dépôt) hardcode `~/albert-code/install.sh` au lieu du chemin réel d'invocation → copier-coller cassé si le dépôt est cloné ailleurs. Régression de T-FIX-12.
**Tâches :** remplacer par `$SELF_DIR/install.sh` ; commentaire d'usage en tête d'`install.sh` → placeholder neutre `<chemin-du-dépôt>/install.sh` ; vérifier qu'aucun message runtime ne hardcode un chemin de dépôt.
**DoD :** le hint affiche le chemin réel quelle que soit la position du clone. → `TESTS.md` S16.

### T-FIX-14 🔴 Onboarding VM de base (`agent-vm setup`) `<- AC-R007` ✅ implémenté
**But :** après une install fraîche, `agent-vm opencode` échoue (`Base VM not found`) car la VM de base n'existe pas et `agent-vm setup` n'est ni lancé ni mentionné.
**Tâches :** « Prochaines étapes » → lister `agent-vm setup` comme étape 1 (avant `agent-vm opencode`) ; en Phase A, détecter l'absence de VM de base et prévenir (option : proposer de lancer `agent-vm setup` avec confirmation — pas d'auto-run silencieux, c'est long).
**DoD :** un nouvel utilisateur qui suit les instructions ne rencontre jamais `Base VM not found`. → `TESTS.md` S17.

### T-FIX-15 🟡 Retirer le contournement OpenCode hors-VM `<- AC-R009` ✅ implémenté
**But :** Albert Code s'utilise **exclusivement** via `agent-vm` (bulle isolée). L'installeur ne doit ni signaler l'absence d'OpenCode sur le PATH hôte, ni suggérer `npm i -g opencode-ai` (bypass de l'isolation).
**Tâches :** dans `install.sh` (A.7), retirer le check host-opencode + les warns « absent du PATH » (×2) + l'info `npm i -g opencode-ai`. Optionnel : une seule ligne positive « OpenCode s'exécute dans la bulle agent-vm — rien à installer sur ton poste ». Vérifier qu'aucun message n'oriente vers une exécution d'OpenCode hors VM.
**DoD :** `grep -n 'opencode-ai\|absent du PATH' install.sh` ne renvoie rien ; l'install ne mentionne plus d'OpenCode hôte.

---

### T4.1 🟠 Skill `conventions-iae` (dans etalab-ia/skills)
**But :** house style Python/Albert (uv, Ruff `line-length=150`/`py312`/ignores, pytest async unit+intég ≥80 %, Alembic upgrade+downgrade, Makefile/cli.py, PR DoD). PR sur `etalab-ia/skills`.
**DoD :** skill chargée par OpenCode, déclenchée sur projet Python. → `TESTS.md` S9.

### T4.2 🟠 Skill `delivery-standards-beta` (dans etalab-ia/skills)
**But :** scaffold projet conforme beta.gouv (linter + CI/CD + tests + Sentry + OpenAPI + README + /stats + DashLord + footer légal + /accessibilite) + checklist 28 standards.
**DoD :** la skill génère la structure conforme. → `TESTS.md` S9.

### T4.3 🟡 Templates CI `templates/` ✅ implémenté
**But :** reprendre la chaîne sécu OpenGateLLM.
**Tâches :** workflows réutilisables Semgrep + Trivy + CodeQL (HIGH=warn / CRITICAL=block) ; `PULL_REQUEST_TEMPLATE.md` (fusion DoD OpenGateLLM + checklist beta) ; script de conformité (footer légal + /accessibilite + scan secrets/URL prod + données fixtures).
**DoD :** workflows valides, script de conformité exécutable. → `TESTS.md` S10.

### T4.4 🟠 Test hermétique S15 rejouable en CI `<- AC-R001` ✅ implémenté
**But :** rendre S15 automatisable (le dogfood manuel prouve mais ne se rejoue pas seul).
**Tâches :**
- `lib/ui.sh` `install_shim` : override `SHIM_BIN_DIR` (si défini et non vide → dossier du shim direct, sinon sonde `/opt/homebrew/bin…$PATH` inchangée) ; documenté à côté de `HOME` / `OPENCODE_CONFIG_DIR`.
- `tests/s15_shim.sh` : sandbox jetable (`HOME` / `SHIM_BIN_DIR` / `XDG_DATA_HOME` sous `mktemp -d`), stub `agent-vm.sh` (`agent-vm(){ echo "STUB OK $*"; }`), PATH minimal ; asserter précondition `command -v agent-vm` introuvable → `install_shim` → `command -v agent-vm` = `$SHIM_BIN_DIR/agent-vm` + exécution du stub ; vérifier non-pollution de `/opt/homebrew/bin` et du vrai `$HOME` ; cleanup `trap EXIT`.
**DoD :** `tests/s15_shim.sh` exit 0 sans écrire hors de la sandbox ; intégrable en CI. → `TESTS.md` S15 (variante automatisée).

### T4.5 🟠 Garde-fou CI anti-fuite chemin perso / username `<- AC-R008` ✅ implémenté
**But :** empêcher qu'un chemin home absolu (`/Users/<name>`, `/home/<name>`) ou un username perso ne soit committé dans ce dépôt **public**. Fuite récurrente : défauts `~/Dev` en code (T-FIX-12), puis chemin absolu dans une note de validation `TESTS.md` (attrapé au pré-vol du commit `7f84d9a`).
**Tâches :**
- Ajouter un check (workflow CI du dépôt, ou script de conformité `templates/`) : `git grep -nE '/Users/[^/ ]+|/home/[^/ ]+'` sur les fichiers suivis → **échec si hit**. Tolérer les placeholders documentés (`<chemin-du-dépôt>`, `$SELF_DIR`, `$HOME`, `~/...`) et exclure `*.lock`.
- Documenter la règle dans `AGENTS.md` (« notes de validation : anonymiser les chemins absolus / username ; ne jamais coller de sortie brute contenant `/Users/<toi>` »).
- Créer le scénario `TESTS.md` S18.
**DoD :** un commit contenant `/Users/<qqn>/…` dans un fichier tracké fait échouer la CI ; les placeholders légitimes passent. → `TESTS.md` S18.

---

## EPIC 5 — Distribution

### T5.1 🔴 README copier-coller (non-techs) ✅ implémenté
**But :** guide d'install pas-à-pas. Réutiliser l'UX de `Produits/Albert Code/MVP/Open code + Ollama/spec.md`.
**DoD :** un non-tech installe et lance un premier projet sans aide. → `TESTS.md` S11.

### T5.2 🟠 Test sur machine vierge + early adopters
**But :** valider hors du poste de développement habituel (machine vierge).
**DoD :** install réussie par ≥1 early adopter externe.

### T5.3 🟡 Publication `etalab-ia/albert-code`
**DoD :** repo public, LICENSE MIT, CI verte.

---

## EPIC 6 — Interface 3 verbes & simplification profils `<- AC-R014, AC-R015, AC-R016, AC-R017`

### T6.1 🔴 Commande `albert-code` à 3 verbes `<- AC-R014`
**But :** une commande unique `albert-code` avec 3 verbes : `install` (bootstrap poste), `setup` (scaffold projet), `run` (lancement VM) — au lieu de mémoriser `install.sh` + `agent-vm setup` + `agent-vm opencode`.
**Tâches :**
- Créer `bin/albert-code` : dispatcher en `case "$1" in install|setup|run|--help)`.
- Extraire `phase_a` / `phase_b` / `phase_run` de `install.sh` vers `lib/phases.sh`, sourçable par `bin/albert-code` ET par `install.sh`.
- `install.sh` devient l'amorçage : joue `phase_a` PUIS pose le shim via `install_shim "albert-code" "$SELF_DIR/bin/albert-code"`.
- `phase_run` : reprend le bloc « Prochaines étapes » (créer la VM de base si absente, puis `agent-vm --cpus "$EFF_CPUS" --memory "$EFF_MEM" --disk "$AC_VM_DISK" opencode`).
- Mettre à jour `usage_install` et `README.md` pour documenter les 3 verbes.
**DoD :** `albert-code install` = Phase A ; `albert-code setup` = Phase B ; `albert-code run` = lance la VM ; `albert-code --help` documente tout. install.sh devient mince. → `TESTS.md` S25.

### T6.2 🟡 Pédagogie agent-vm en phase A `<- AC-R015`
**But :** avant d'installer Lima/agent-vm, afficher un encart en français simple expliquant ce qu'est cette VM et pourquoi c'est indispensable.
**Tâches :**
- Dans `phase_a`, avant le `confirm` Lima, afficher un encart `title` + `info` : « une bulle isolée (VM légère Lima) où l'assistant tourne sans accès à tes fichiers perso, clés SSH, cookies. Permet de le laisser tourner en autonomie. Installe : Lima, agent-vm, clé Albert révocable. »
- Garder le `confirm` avant d'installer Lima.
**DoD :** un non-dev comprend pourquoi on installe une VM avant le premier `confirm`. → `TESTS.md` S26.

### T6.3 🔴 Supprimer les profils → un seul AGENTS.md par défaut `<- AC-R016`
**But :** remplacer le choix de profil (beta.gouv / La Suite / IAE) par un unique `templates/AGENTS.default.md` avec sécurité, conventions de code et accessibilité — neutre, applicable à tout projet.
**Tâches :**
- Supprimer `profiles/beta.gouv/`, `profiles/lasuite/`, `profiles/iae/`.
- Retirer le `prompt_choice` de contexte et le `case` profils dans `phase_b`.
- Créer `templates/AGENTS.default.md` avec le contenu fourni (sécurité, plan mode, task management, self-improvement, bug fixing, code quality, git, accessibilité).
- `phase_b` copie `templates/AGENTS.default.md` vers `./AGENTS.md` via `copy_template` (n'écrase jamais un AGENTS.md existant).
- Nettoyer les références aux profils dans `README.md`, `AGENTS.md` (repo), `BACKLOG.md`, `TESTS.md` (retirer S7, S6).
**DoD :** plus de menu contexte ; un seul AGENTS.md par défaut ; profils physiquement supprimés du dépôt ; re-setup non-destructif (AGENTS.md conservé). → `TESTS.md` S27.

### T6.4 🟠 Choix Y/N skills + MCP au `setup` (phase_b) `<- AC-R017`
**But :** au lieu d'activer toutes les skills et MCP en aveugle, demander à l'utilisateur ce qu'il veut brancher.
**MCP (par projet, dans opencode.json) :**
- Passe les 4 MCP de `config/opencode.template.json` en `enabled: false` par défaut.
- Dans `phase_b`, pour chaque MCP : `confirm` « Brancher le MCP <nom> (objectif : <desc>) ? » → `enabled: true` seulement si oui. Génère le bloc MCP en bash (PAS de dépendance jq).
- Objectifs : `data.gouv` = "accès aux données publiques (lecture)" ; `context7` = "doc à jour des librairies (clé requise)" ; `playwright` = "piloter un navigateur / agir dans une page" ; `chrome-devtools` = "debug navigateur".
**Skills (choisies au setup, manifeste projet lu par le runtime) :**
- `phase_b` rafraîchit le cache `etalab-ia/skills`, énumère chaque skill (lit `description` du `SKILL.md` de chaque dossier) et demande `confirm` « Installer la skill <nom> (objectif : <description>) ? ».
- Écrit la sélection dans `./.albert-code/skills.txt` (une skill par ligne).
- Modifie `sync_skills` du runtime : au boot, ne symlinke QUE les skills listées dans `./.albert-code/skills.txt` du projet courant ; réconcilie le dossier global skills/ (retire les symlinks albert-code non sélectionnés, JAMAIS les skills perso). Si aucun manifeste → comportement actuel (toutes) pour rétrocompat.
**DoD :** un « non » à un MCP/skill ne l'écrit pas ; re-setup conserve les choix ; skills perso jamais touchées par la réconciliation. → `TESTS.md` S28.

### T6.5 🟡 Encart FR de transition avant wizard agent-vm `<- AC-R018` ✅ implémenté
**But :** quand `install.sh` passe la main à `agent-vm setup`, le wizard natif (en anglais) s'affiche sans prévenir. Déroutant pour un public non-tech francophone.
**Tâches :** dans `check_base_vm()`, JUSTE AVANT l'appel à `agent-vm setup`, afficher un encart `info` court : « Tu entres maintenant dans le wizard agent-vm (en anglais). C'est normal : agent-vm est l'outil d'isolation open source sur lequel s'appuie Albert Code. Valide les logiciels proposés par défaut (Python, Node, Docker, Chromium, gh, OpenCode…). » Idem dans `phase_run()` si création VM.
**DoD :** l'encart FR s'affiche avant la sortie anglaise d'agent-vm, en dry-run comme en réel. → `TESTS.md` S30.

### T6.6 🔴 Dérivation automatique email noreply GitHub `<- AC-R019` ✅ implémenté
**But :** l'utilisateur non-tech ne connaît pas son email noreply ni comment le trouver. Débuter le prompt avec le vrai email (qui échoue la validation) = blocage.
**Tâches :** après avoir collé le PAT, appeler l'API GitHub pour dériver l'email noreply :
- `curl -fsS -H "Authorization: Bearer <PAT>" https://api.github.com/user`
- Parser `id` et `login` avec `grep`/`sed` (pas de jq)
- Pré-remplir le prompt avec "`<id>+<login>@users.noreply.github.com`"
- Fallback : si l'appel API échoue, garder le prompt manuel avec aide FR : « Introuvable automatiquement. Tu le trouves sur GitHub > Paramètres > Emails, ou sur https://github.com/settings/emails. Il est de la forme `<id>+<login>@users.noreply.github.com`. »
- Ne jamais afficher le PAT en clair.
**DoD :** avec un PAT valide, fait Entrée et l'email est correct ; sans réseau, le message FR d'aide s'affiche. → `TESTS.md` S31.

### T6.7 🟠 Investiguer image de base minimale / tolérante à l'échec `<- AC-R020`
**But :** `agent-vm setup` installe 4 harnais (Claude Code, OpenCode, Codex, Mistral Vibe). Un seul qui rate (429) = base non finalisée. Albert Code n'a besoin que d'OpenCode.
**Tâches :** à investiguer avec Sylvain (upstream agent-vm) : (a) image de base minimale ne contenant que OpenCode, (b) mécanisme de tolérance à l'échec d'un installeur, (c) variable d'env pour sélectionner quels harnais installer. Documenter dans `docs/PLAN.md`.
**DoD :** investigation terminée, décision documentée. Pas de changement de code dans albert-code.

### T6.8 🟠 Fix commande albert-code : shim avant VM + migration ancien `albert-code()` `<- AC-R021` ✅ implémenté
**But :** (a) `install.sh` pose le shim APRÈS la VM de base (fragile) ; échec VM = pas de shim = aucune commande. (b) ancien MVP écrivait `albert-code()` dans ~/.zshrc qui masque le nouveau shim.
**Tâches :**
- (a) Déplacer `install_shim "albert-code"` AVANT `check_base_vm` dans `install.sh`. Rendre la création VM non-fatale : en cas d'échec, warn + continue (pas exit). Le shim doit exister même si la VM échoue.
- (b) Détecter un bloc `albert-code()` dans ~/.zshrc / ~/.bashrc / ~/.zshenv (~.profile) et proposer de le retirer (`confirm`, non-destructif, avec `grep -n` pour localiser). Idem dans `uninstall.sh`
**DoD :** `install.sh` pose le shim avant la VM ; la VM échouant ne bloque pas le reste ; `albert-code` fonctionne post-echec-VM. Ancienne fonction détectée et retirée si confirmée. → `TESTS.md` S32.

### T6.9 🔴 Corriger le shim exécutable : `exec` au lieu de `source+exec` `<- AC-R022` ✅ implémenté
**But :** le shim `albert-code` source le script (`bin/albert-code`) avec `2>/dev/null` (avale les prompts interactifs) puis relance `$name "$@"` (double exécution possible). Résultat : `albert-code setup` figé (MCP/skills prompts invisibles).
**Tâches :** dans `install_shim`, quand la source est un script exécutable (binaire) et non une fonction shell à sourcer, générer un shim minimal :
```
#!/usr/bin/env bash
exec "/chemin/absolu/bin/albert-code" "$@"
```
Préserve stdin/stdout/stderr. Pas de `2>/dev/null`. Pas de double exécution.
Option : ajouter un paramètre `install_shim` pour mode "exec" vs "source", ou détecter automatiquement (si source contient `#!/usr/bin/env bash` et est un script autonome).
**DoD :** `albert-code setup` via le shim affiche bien les prompts MCP + skills et enregistre les choix. Pas de double exécution. `bin/albert-code --help` identique via shim ou direct. → `TESTS.md` S33.

### T6.10 🟠 Hygiène dépôt : .gitignore par défaut dans AGENTS.default.md `<- AC-R024` ✅ implémenté
**But :** sans .gitignore, l'agent commit `node_modules/` (41 659 fichiers) + risque `.env`. Règle forte manquante dans le template.
**Tâches :** dans `templates/AGENTS.default.md`, ajouter une section « Hygiène de dépôt » :
- « Avant le premier commit, toujours créer ou vérifier un `.gitignore` adapté au langage (Node : `node_modules`, `dist`/`build`/`.next`, `.env` ; Python : `__pycache__`, `.venv`, `.env`) »
- « Ne JAMAIS committer : dépendances installées, artefacts de build, fichiers volumineux, secrets/.env »
- « Vérifier `git status` avant de committer »
**DoD :** un agent qui scaffold un projet et commit inclut un `.gitignore` et PR sans node_modules. → `TESTS.md` S34.

### T6.11 🟡 chrome-devtools MCP injecté par agent-vm `<- AC-R023`
**But :** chrome-devtools apparaît dans OpenCode (`/mcp`) même zéro MCP coché au setup, parce qu'agent-vm l'installe globalement dans la VM.
**Tâches :** documenter dans README (section MCP) :
- Préciser que `chrome-devtools` peut apparaître dans OpenCode même si non coché au setup : il est préinstallé par agent-vm (pas par Albert Code).
- Documenter ce MCP dans la liste du README avec sa source (agent-vm). À investir avec Sylvain : le désactiver côté runtime quand non sélectionné, ou le documenter clairement.
**DoD :** le README mentionne chrome-devtools comme venant d'agent-vm. Investigation documentée.

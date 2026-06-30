# AGENTS.md — profil IAE / Albert (OpenGateLLM)

> House style de l'équipe IA dans l'État (IAE) / OpenGateLLM.
> Ce fichier est posé à la racine du projet par le bootstrap Albert Code.
> Ne pas le fusionner avec un autre profil.

---

## Socle commun (non négociable)

### Langue
- Code, commentaires, identifiants, messages de commit : **anglais**.
- UI, messages utilisateur, documentation produit : **français**.

### Accessibilité (RGAA 4.1.2 — niveau AA)
- Navigation clavier complète sur tout composant interactif.
- Contraste minimum AA (4,5:1 texte, 3:1 grands textes).
- `alt` sur toute image (vide si décorative).
- Structure sémantique HTML : `<header>`, `<nav>`, `<main>`, `<footer>`.
- Hiérarchie de titres h1→h6 sans saut de niveau.
- Chaque champ de formulaire a un `<label>` associé + message d'erreur explicite.

### Sécurité (ANSSI)
- HTTPS obligatoire en production.
- Headers : CSP, HSTS, X-Frame-Options, X-Content-Type-Options.
- Dépendances à jour (`pip audit` / `uv pip audit` régulièrement).
- Validation de toutes les entrées utilisateur côté serveur (Pydantic).
- Pas de données sensibles dans les logs.

### Secrets & données
- **Jamais** de secret / clé / token / URL de prod en clair dans le code ou l'historique.
- Lecture depuis l'environnement (`{env:VAR}`) ou `~/.zshenv`.
- **Jamais** de données réelles dans les exemples/fixtures : données fictives uniquement.
- gitleaks en pre-commit ; ne jamais `--no-verify`.

### Souveraineté
- Préférer le libre et les composants souverains (DSFR, Albert API).
- Signaler toute dépendance propriétaire/non-souveraine ajoutée.

### Qualité
- Tests unitaires pour toute nouvelle fonctionnalité.
- Linter respecté (pas de warning dans la CI).

---

## Conventions IAE / OpenGateLLM

### Stack
- **Backend** : Python 3.12 + FastAPI.
- **Frontend** (si présent) : React + `@codegouvfr/react-dsfr` (DSFR).
- **Base de données** : PostgreSQL + SQLAlchemy 2.x + Alembic.

### Gestion des dépendances
- **uv** (gestionnaire de paquets et envs). Pas de pip/poetry/pnpm.
- `pyproject.toml` + `uv.lock` versionnés.
- Python : `3.12`.

### Linter / formatter
- **Ruff** : `line-length = 150`, `target-version = py312`.
- Ignores raisonnés (ex. `E501` déjà couvert par line-length).
- `ruff check` + `ruff format` en pre-commit et CI (bloquant).

### Tests
- **pytest** : unit + intégration.
- Couverture cible ≥ 80 %.
- Tests async pour les endpoints FastAPI (`httpx.AsyncClient`).

### Migrations
- **Alembic** : un `upgrade` + un `downgrade` par migration (les deux doivent passer).

### Structure de projet
- `Makefile` (cibles : `install`, `lint`, `test`, `migrate`, `run`).
- Entrée CLI via `cli.py` (Typer/Click).

### Commits (Conventional Commits, en anglais)
- Format : `type(scope): message` avec `type` ∈ `feat|fix|docs|refactor|chore|test`.
- Messages en **anglais**, explicites sur le *pourquoi*.
- Exemple : `feat(rag): add hybrid search to retrieval pipeline`.
- Squash des commits intermédiaires avant push.

### Branches & PR
- Branches : `feat/…`, `fix/…`.
- PR avec checklist Definition of Done (tests verts, migrations réversibles, Ruff propre).

### Skills recommandées
- `conventions-iae` · `react-dsfr` · `rgaa` · `securite-developpement` · `datagouv-apis` · `albert-api`.

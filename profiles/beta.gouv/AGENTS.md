# AGENTS.md — profil beta.gouv

> Conventions pour les projets incubés (beta.gouv.fr / startups d'État).
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
- Dépendances à jour (`pnpm audit` régulièrement).
- Validation de toutes les entrées utilisateur côté serveur.
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

## Conventions beta.gouv

### Stack
- **Frontend** : React + `@codegouvfr/react-dsfr` (DSFR — composants natifs, pas de CSS inventé, pas de MUI).
- **Backend** : Next.js (API routes) ou FastAPI selon le besoin.
- **Base de données** : PostgreSQL (via Prisma ou SQLAlchemy).

### Package manager
- **pnpm** uniquement. Pas de npm/yarn. `pnpm-lock.yaml` versionné.

### Commits (Conventional Commits, en français)
- Format : `type(scope): message` avec `type` ∈ `feat|fix|docs|refactor|chore|test`.
- Messages en **français**, explicites sur le *pourquoi*.
- Exemple : `feat(auth): ajoute le rafraîchissement du jeton pour éviter les déconnexions`.
- Squash des commits intermédiaires avant push.

### Branches & PR
- Branches : `feat/…`, `fix/…`.
- Une PR par fonctionnalité, avec description et checklist de revue.

### Design System
- **DSFR** systématique. Classes utilitaires DSFR uniquement, pas de CSS custom sauf exception justifiée.
- Charger les skills `react-dsfr` et `rgaa` avant toute création/modification d'interface.

### Skills recommandées
- `react-dsfr` · `rgaa` · `securite-developpement` · `datagouv-apis`.

### Standards delivery (standards.beta.gouv.fr)
- Observabilité : Sentry configuré.
- Linter obligatoire bloquant en CI.
- Tests : le CI/CD doit gate sur les tests (pas de déploiement si tests rouges).
- OpenAPI publié si API.
- Données de prod ≠ données de test.
- Footer légal + page `/accessibilite` obligatoires.

# AGENTS.md — profil La Suite

> Conventions pour les applications de la Suite numérique de l'État (Docs, Drive, People, Webinaire, Messagerie…).
> Ce fichier est posé à la racine du projet par le bootstrap Albert Code.
> Ne pas le fusionner avec un autre profil.

---

## Socle commun (non négociable)

### Langue
- Code, commentaires, identifiants : **anglais**.
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
- Dépendances à jour (`yarn audit` régulièrement).
- Validation de toutes les entrées utilisateur côté serveur.
- Pas de données sensibles dans les logs.

### Secrets & données
- **Jamais** de secret / clé / token / URL de prod en clair dans le code ou l'historique.
- Lecture depuis l'environnement (`{env:VAR}`) ou `~/.zshenv`.
- **Jamais** de données réelles dans les exemples/fixtures : données fictives uniquement.
- gitleaks en pre-commit ; ne jamais `--no-verify`.

### Souveraineté
- Préférer le libre et les composants souverains (La Suite UI Kit, Albert API).
- Signaler toute dépendance propriétaire/non-souveraine ajoutée.

### Qualité
- Tests unitaires pour toute nouvelle fonctionnalité.
- Linter respecté (pas de warning dans la CI).

---

## Conventions La Suite

### Stack
- **Frontend** : React + `@gouvfr-lasuite/ui-kit` et `@gouvfr-lasuite/cunningham-react` (La Suite UI Kit — pas de DSFR par défaut, pas de MUI).
- **Backend** : Django REST Framework.
- **Base de données** : PostgreSQL.

### Package manager
- **yarn** (classic). Pas de npm/pnpm. `yarn.lock` versionné.

### Commits (gitmoji, en anglais)
- Format : `<emoji> <message en anglais>` ou `type(scope): message`.
- Préfixer avec un gitmoji pertinent : `✨` (feat), `🐛` (fix), `📝` (docs), `♻️` (refactor), `🔧` (chore), `✅` (test).
- Exemple : `✨ add document sharing endpoint`.
- Squash des commits intermédiaires avant push.

### Branches & PR
- Branches : `feat/…`, `fix/…`.
- Une PR par fonctionnalité, description en anglais.

### Design System
- **La Suite UI Kit** (`@gouvfr-lasuite/ui-kit`) + `@gouvfr-lasuite/cunningham-react`.
- Layout applicatif, navigation, recherche rapide, badges, icônes Material, menus contextuels, patterns de partage.
- Charger la skill `lasuite-ui-kit` avant toute création/modification d'interface.

### Skills recommandées
- `lasuite-ui-kit` · `rgaa` · `securite-developpement` · `datagouv-apis`.

### Backend
- Django REST Framework : serializers explicites, viewsets, routing par routers.
- Permissions par classe, validation dans `clean()` / serializers.

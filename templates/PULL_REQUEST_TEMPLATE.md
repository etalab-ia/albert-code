# Pull Request

## Description

<!-- Que fait cette PR et pourquoi ? Lien vers l'issue/ticket si pertinent. -->

## Type de changement

- [ ] feat — nouvelle fonctionnalité
- [ ] fix — correction de bug
- [ ] docs — documentation
- [ ] refactor — refacto (pas de changement de comportement)
- [ ] chore — maintenance
- [ ] test — tests
- [ ] breaking change — changement cassant

## Definition of Done

### Qualité & tests
- [ ] Le linter passe sans warning (Ruff / ESLint / selon profil)
- [ ] Tests unitaires ajoutés pour la nouvelle fonctionnalité
- [ ] Tous les tests passent en local et en CI
- [ ] Couverture maintenue/améliorée (≥ 80 % si profil IAE)
- [ ] Migrations de base de données réversibles (`upgrade` + `downgrade` testés) — si applicable

### Sécurité (ANSSI)
- [ ] Aucun secret / clé / URL de prod en clair dans le code
- [ ] Entrées utilisateur validées côté serveur
- [ ] Pas de données sensibles dans les logs
- [ ] Dépendances à jour (`audit` propre)

### Accessibilité (RGAA 4.1.2 — AA)
- [ ] Navigation clavier complète sur les nouveaux composants interactifs
- [ ] Contraste AA respecté (4,5:1 texte)
- [ ] `alt` présent sur toute image (vide si décorative)
- [ ] Structure sémantique HTML (header/nav/main/footer) et hiérarchie de titres cohérente
- [ ] Champs de formulaire associés à un `<label>` + messages d'erreur explicites

### Livraison (standards beta.gouv / OpenGateLLM)
- [ ] Footer légal présent (si site public)
- [ ] Page `/accessibilite` présente (si site public)
- [ ] Données de test ≠ données de prod (fixtures fictives)
- [ ] Observabilité (Sentry) configurée — si applicable
- [ ] OpenAPI publié — si API

## Revue

- [ ] Auto-revue effectuée
- [ ] Au moins 1 relecteur
- [ ] Squash des commits intermédiaires avant merge

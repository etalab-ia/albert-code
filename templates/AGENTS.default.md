# AGENTS.md

Assistant de code souverain (Albert API, dans une bulle isolée agent-vm).
Code et commentaires en anglais. Interface / messages produits en français.

## Sécurité (non négociable)

- **Aucun secret en dur** : jamais de clé API, token, mot de passe, URL de prod avec identifiants dans le code. Utiliser des variables d'environnement / `.env` (jamais commité). `gitleaks` doit passer ; ne jamais contourner un hook (`--no-verify` interdit).
- **Données sensibles** : ne jamais coller ni committer de données personnelles, RH, médicales, ou couvertes par le secret. Pas de données réelles dans les fixtures/tests — uniquement des données synthétiques.
- **Entrées non fiables** : valider et échapper toute entrée externe (formulaires, API, fichiers). Requêtes SQL paramétrées, jamais de concaténation.
- **Dépendances** : pas d'ajout de dépendance non justifié ; préférer la lib standard. Signaler toute dépendance à réputation douteuse.
- **Réseau/TLS** : HTTPS/TLS par défaut, pas de vérification de certificat désactivée. En-têtes de sécurité HTTP sur tout service exposé.
- En cas de doute sur la sensibilité d'une donnée ou d'une action : **s'arrêter et demander**, ne pas exfiltrer vers un service externe.

## Expected Behavior

### Plan Mode

Pour toute tâche non triviale (3+ étapes ou décision d'architecture) :

1. Écrire le plan dans `tasks/todo.md` avec des items cochables
2. Valider le plan avant d'implémenter
3. Cocher les items au fur et à mesure
4. Ajouter une section « résultat » à la fin

### Task Management (`tasks/`)

    tasks/
    ├── todo.md      # Plan courant : items cochables, résultat final
    └── lessons.md   # Patterns d'erreur rencontrés sur ce projet

`tasks/todo.md` est réinitialisé pour chaque nouvelle tâche.
`tasks/lessons.md` est cumulatif.

### Self-Improvement Loop

Après toute correction de l'utilisateur :

1. Mettre à jour `tasks/lessons.md` avec le pattern d'erreur et la règle à retenir
2. Relire `tasks/lessons.md` au début de chaque session

### Bug Fixing

Face à un bug : le corriger directement. Pointer les logs, erreurs et tests en échec — reproduire, puis résoudre. Ne pas masquer un symptôme.

### Code Quality

- Pour tout changement non trivial : **« Existe-t-il une solution plus élégante ? »**
- Respecter le style et les conventions du code environnant ; ne pas reformater du code non concerné.
- Petites unités testables. Ajouter/mettre à jour les tests avec le changement.

### Git & commits

- Commits atomiques, messages en Conventional Commits (`type(scope): …`).
- Une PR = une intention. Décrire le quoi/pourquoi, lister ce qui a été testé.
- Ne jamais `git push --force` sur une branche partagée.

## Accessibilité & conformité

- Front public : viser la conformité RGAA (contraste, navigation clavier, alt).
- Respect du RGPD : minimisation, pas de traceur tiers non consenti.

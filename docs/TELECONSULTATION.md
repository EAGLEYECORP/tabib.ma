# V9 — Téléconsultation

V9 ajoute la couche de téléconsultation sans imposer un fournisseur vidéo.

## Sécurité
- Une salle est liée à un rendez-vous confirmé.
- Seuls patient et médecin du rendez-vous peuvent la consulter.
- Aucun enregistrement n'est activé par défaut.
- Ne pas placer de token vidéo dans le navigateur depuis une variable secrète.
- Le fournisseur réel doit être intégré côté serveur via un adapter et des tokens courts.

## Provider
Configurer `VIDEO_PROVIDER`, `VIDEO_API_URL` et les secrets correspondants dans Vercel. Le dépôt ne contient aucun credential réel.

## Production
Le placeholder vidéo doit être remplacé par un fournisseur validé, avec chiffrement, expiration des rooms/tokens, consentement, gestion des incidents, tests de charge et vérification des exigences réglementaires applicables.

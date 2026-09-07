# V10 — Cliniques multi-sites & permissions

V10 transforme Tabib en modèle multi-tenant pour établissements : une clinique peut avoir plusieurs sites, salles, médecins et collaborateurs.

## Rôles
- owner : gouvernance de la clinique
- clinic_admin : administration opérationnelle
- secretary : opérations autorisées par les policies applicatives
- doctor : accès professionnel limité à ses opérations

Les rôles ne doivent jamais être auto-déclarés depuis le navigateur. L'affectation doit être faite par un owner/admin ou par un workflow d'approbation.

## Sécurité
Toutes les tables V10 sont RLS. Le contexte de clinique est déterminé par `clinic_members` et non par une valeur envoyée par le client. Les endpoints sensibles doivent utiliser un client Supabase server-side et vérifier l'appartenance au tenant.

## Migration
Appliquer après les schémas V5→V9 : `supabase/schema_v10_clinics.sql`.

## Production
Tester isolation inter-cliniques, changements de rôle, suppression d'un membre, accès aux documents, agenda multi-sites et concurrence de réservation avant mise en production.

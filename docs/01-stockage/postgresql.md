---
id: postgresql
title: Configuration PostgreSQL
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 0.1.0
status: draft
priority: high
tags: [postgresql, stockage, oltp, base-de-données]
sidebar_label: PostgreSQL
sidebar_position: 3
---

# Configuration PostgreSQL

⚠️ **Documentation en cours de rédaction**

## Contexte

PostgreSQL est la base de données relationnelle principale pour stocker les métadonnées structurées d'OpenAlex :
- **Works** (250M articles)
- **Authors** (90M auteurs)
- **Institutions** (100K institutions)
- **Concepts** (65K concepts)
- **Sources** (250K journaux/conférences)

## Objectifs

- [ ] Configuration StatefulSet Kubernetes avec Rook/Ceph
- [ ] Schéma de base de données optimisé
- [ ] Stratégie de partitionnement (par année)
- [ ] Index pour requêtes fréquentes
- [ ] Configuration haute disponibilité (Primary + Replica)
- [ ] Tuning des paramètres pour 1.4TB de données

## Spécifications Prévues

### Stockage
- **Volume** : 1.5 TB (1.4TB données + 100GB marge)
- **Type** : NVMe via Rook/Ceph (rook-ceph-nvme)
- **Réplication** : Primary + Replica (Phase 5)

### Ressources
- **CPU** : 8-16 cores
- **RAM** : 64 GB (shared_buffers: 16GB, effective_cache_size: 48GB)
- **Connexions** : 200 max_connections

### Tables Principales
- `works` - 250M lignes (~800GB)
- `authors` - 90M lignes (~200GB)
- `institutions` - 100K lignes (~50MB)
- `concepts` - 65K lignes (~10MB)
- `sources` - 250K lignes (~100MB)
- `works_authors` - 500M lignes (jointure)
- `works_concepts` - 1B lignes (jointure)

## Prochaines Étapes

1. Définir le schéma relationnel complet
2. Planifier la stratégie de partitionnement
3. Identifier les index critiques
4. Configurer pgBackRest pour les backups
5. Tester les performances avec données de test

## Références

- [Stratégie de stockage globale](./strategy.md)
- [Configuration Rook/Ceph](./rook-ceph.md)
- [Stratégie de partitionnement](./partitioning.md)
- [Architecture polyglotte](../00-introduction/polyglot-architecture.md)

---

**Statut** : 📝 Brouillon - À compléter avec schéma SQL, configuration StatefulSet, et stratégie de tuning

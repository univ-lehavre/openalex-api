---
id: overview
title: Vue d'Ensemble du Projet
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 1.0.0
status: draft
priority: high
tags: [introduction, openalex, architecture, projet]
categories: [introduction, stratégie]
dependencies: []
sidebar_label: Vue d'Ensemble
sidebar_position: 1
---

# Vue d'Ensemble du Projet API OpenAlex

## Contexte

L'Université Le Havre Normandie entreprend la construction d'une infrastructure API performante pour servir **3 To de données JSON OpenAlex**. OpenAlex est une base de données bibliographiques ouverte couvrant plus de 250 millions d'articles scientifiques, auteurs, institutions et concepts.

## Objectifs du Projet

### Objectif Principal

Mettre à disposition une API REST performante permettant de :
- **Rechercher** rapidement parmi 3 To de données académiques
- **Analyser** les réseaux de citations et collaborations
- **Agréger** des statistiques sur les publications scientifiques
- **Interroger** les données avec des filtres structurés complexes

### Objectifs Secondaires

- Garantir une **haute disponibilité** (99,9% uptime)
- Assurer des **temps de réponse** rapides (< 500ms P95)
- Permettre des **mises à jour mensuelles** sans interruption de service
- Maintenir l'**intégrité des données** avec sauvegardes automatisées

## Périmètre

### Données Couvertes

Les données OpenAlex comprennent 7 types d'entités :
1. **Works** (Articles) - 250M+ publications scientifiques
2. **Authors** (Auteurs) - 90M+ chercheurs
3. **Sources** (Revues) - 250K+ journaux et conférences
4. **Institutions** - 100K+ universités et centres de recherche
5. **Concepts** - 65K+ sujets de recherche
6. **Publishers** (Éditeurs) - 10K+ maisons d'édition
7. **Topics** (Thématiques) - 4,5K+ domaines de recherche

### Cas d'Usage

**Recherche Académique :**
- Trouver des publications sur un sujet spécifique
- Identifier les auteurs experts dans un domaine
- Découvrir les tendances de recherche émergentes

**Analyse Bibliométrique :**
- Calculer l'impact des publications (citations)
- Cartographier les réseaux de collaboration
- Analyser la production scientifique par institution

**Veille Scientifique :**
- Suivre les nouvelles publications dans un domaine
- Identifier les articles les plus cités
- Détecter les collaborations interdisciplinaires

## Architecture Cible

### Approche Hybride

L'architecture repose sur une **approche hybride** combinant :

```
┌─────────────────┐      ┌──────────────────┐
│   PostgreSQL    │◄─────┤   FastAPI API    │
│  (Relationnel)  │      │   (Python Async) │
└─────────────────┘      └──────────────────┘
                                  ▲
┌─────────────────┐               │
│ Elasticsearch   │◄──────────────┘
│ (Plein texte)   │
└─────────────────┘
```

**Justification :**
- **PostgreSQL** : Optimal pour requêtes structurées, relations, agrégations
- **Elasticsearch** : Optimal pour recherche plein texte, performances de recherche
- **FastAPI** : Framework moderne, async, haute performance

### Infrastructure Kubernetes

Déploiement sur **cluster Kubernetes auto-géré** :
- 10 nœuds workers
- 376 cœurs CPU, 1,5 To RAM
- 13,5 To stockage SSD
- Haute disponibilité avec réplication

## Patterns de Requêtes Supportés

Le système doit supporter **4 patterns de requêtes** distincts :

### 1. Recherche Plein Texte
```http
GET /v1/works?search=machine+learning&per_page=25
```
Recherche dans titres, résumés, noms d'auteurs avec scoring de pertinence.

### 2. Requêtes Structurées avec Filtres
```http
GET /v1/works?filter=publication_year:2020,type:journal-article&sort=cited_by_count:desc
```
Filtrage par année, type, institution, domaine avec pagination et tri.

### 3. Requêtes de Graphes
```http
GET /v1/works/W2124379035/citations
GET /v1/authors/A2208157607/collaborations
```
Navigation dans les réseaux de citations et collaborations.

### 4. Analyses et Agrégations
```http
GET /v1/analytics/trends?group_by=year&filter=institution:ULHN
```
Statistiques agrégées, tendances temporelles, distributions.

## Contraintes et Exigences

### Contraintes Techniques

| Contrainte | Valeur | Justification |
|-----------|--------|---------------|
| **Volume de données** | 3 To | Dataset OpenAlex complet avec index |
| **Latence P95** | < 500ms | Expérience utilisateur acceptable |
| **Concurrence** | 100-500 req/s | Usage académique multi-utilisateurs |
| **Disponibilité** | 99,9% | Service de recherche critique |
| **Mise à jour** | Mensuelle | Synchronisation avec OpenAlex |

### Contraintes Organisationnelles

- **Budget** : 6 500 - 11 000 €/mois (infrastructure auto-gérée)
- **Équipe** : 2-3 ingénieurs infrastructure/backend
- **Délai** : 20 semaines (5 mois) pour MVP production
- **Infrastructure** : Cluster Kubernetes existant de l'université

## Bénéfices Attendus

### Pour la Recherche

- **Accès facilité** aux données bibliographiques ouvertes
- **Recherche avancée** avec filtres complexes
- **Analyses** statistiques sur la production scientifique

### Pour l'Institution

- **Valorisation** de l'infrastructure technique
- **Support** à la recherche et à la documentation
- **Données ouvertes** (Open Science)

### Technique

- **Plateforme réutilisable** pour d'autres datasets
- **Expertise** en gestion de données massives
- **Architecture moderne** et scalable

## Prochaines Étapes

1. **Validation** de l'architecture avec parties prenantes
2. **Provisionnement** du cluster Kubernetes (10 nœuds)
3. **Phase 1** : Fondations (monitoring, CI/CD)
4. **Phase 2** : Déploiement des bases de données
5. **Phase 3** : Développement de l'API
6. **Phase 4** : Pipeline ETL d'ingestion
7. **Phase 5-6** : Production et lancement

## Ressources

- [Documentation OpenAlex](https://docs.openalex.org)
- [OpenAlex Snapshot](https://docs.openalex.org/download-all-data/openalex-snapshot)
- [Plan d'implémentation détaillé](../08-implementation/roadmap.md)
- [Décisions d'architecture](./architecture-decision.md)

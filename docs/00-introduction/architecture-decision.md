---
id: architecture-decision
title: Décision d'Architecture Hybride
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 1.0.0
status: draft
priority: high
tags: [architecture, postgresql, elasticsearch, adr, décision]
categories: [architecture, stratégie]
dependencies: [00-introduction/overview.md]
sidebar_label: Décision d'Architecture
sidebar_position: 2
---

# Décision d'Architecture Hybride

## Contexte de la Décision

L'API OpenAlex doit supporter **4 patterns de requêtes distincts** avec des optimisations différentes :

1. **Recherche plein texte** → Nécessite index inversés
2. **Requêtes structurées** → Nécessite index B-tree
3. **Requêtes de graphes** → Nécessite traversée de relations
4. **Analyses et agrégations** → Nécessite calculs sur grands volumes

Une seule technologie de base de données compromettrait au moins 2 des 4 patterns.

## Décision : Architecture Hybride PostgreSQL + Elasticsearch

Nous adoptons une **architecture hybride** avec :
- **PostgreSQL 16** comme base de données principale
- **Elasticsearch 8.11** comme moteur de recherche
- **FastAPI** pour la couche API

### Schéma d'Architecture

```
                    ┌──────────────────────────────┐
                    │      Utilisateurs API        │
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────▼───────────────┐
                    │     Nginx Ingress +          │
                    │     Load Balancer            │
                    └──────────────┬───────────────┘
                                   │
         ┌─────────────────────────┼─────────────────────────┐
         │                         │                         │
┌────────▼────────┐      ┌────────▼────────┐      ┌────────▼────────┐
│   FastAPI Pod   │      │   FastAPI Pod   │      │   FastAPI Pod   │
│   (6-12 pods)   │      │   (autoscaling) │      │   (replicas)    │
└────┬──────┬─────┘      └────┬──────┬─────┘      └────┬──────┬─────┘
     │      │                  │      │                  │      │
     │      └──────────────────┼──────┴──────────────────┘      │
     │                         │                                 │
┌────▼─────────────┐  ┌───────▼──────────┐  ┌─────────────────▼───┐
│   PostgreSQL     │  │  Elasticsearch   │  │     Redis           │
│   (3TB données)  │  │  (1TB recherche) │  │  (64GB cache)       │
│   - Relations    │  │  - Plein texte   │  │  - Rate limiting    │
│   - Graphes      │  │  - Keyword search│  │  - Sessions         │
│   - Analytics    │  │  - Fuzzy match   │  │                     │
└──────────────────┘  └──────────────────┘  └─────────────────────┘
```

## Options Considérées

### Option 1 : PostgreSQL Seul ❌

**Avantages :**
- Architecture plus simple
- Une seule source de vérité
- Moindre complexité opérationnelle
- PostgreSQL a des capacités de recherche plein texte (tsvector)

**Inconvénients :**
- Recherche plein texte **5-10x plus lente** qu'Elasticsearch
- Scoring de pertinence limité
- Pas de highlighting avancé
- Performances dégradées avec volume (3 To)
- Requêtes de recherche impactent les requêtes structurées

**Verdict :** ❌ **Rejeté** - Les performances de recherche seraient insuffisantes

### Option 2 : Elasticsearch Seul ❌

**Avantages :**
- Excellentes performances de recherche
- Bonne capacité d'agrégation
- Interface REST native
- Scalabilité horizontale

**Inconvénients :**
- **Pas conçu pour requêtes de graphes** (citations, collaborations)
- Support transactionnel limité
- Requêtes SQL complexes difficiles
- Pas de CTEs récursifs pour graphes
- Intégrité référentielle faible

**Verdict :** ❌ **Rejeté** - Les requêtes de graphes seraient problématiques

### Option 3 : Architecture Hybride PostgreSQL + Elasticsearch ✅

**Avantages :**
- ✅ **Meilleure solution pour chaque pattern de requête**
- ✅ PostgreSQL : Requêtes structurées, graphes, agrégations
- ✅ Elasticsearch : Recherche plein texte, fuzzy matching
- ✅ Flexibilité : Choisir le moteur optimal par cas d'usage
- ✅ Évolutivité indépendante de chaque composant

**Inconvénients :**
- ⚠️ Complexité opérationnelle accrue
- ⚠️ Synchronisation des données entre systèmes
- ⚠️ Besoin de 2x plus de stockage (~4 To total)
- ⚠️ Coût d'infrastructure plus élevé

**Mitigations :**
- Pipeline ETL mensuel assure synchronisation
- Elasticsearch contient uniquement données dénormalisées (works, authors)
- PostgreSQL reste source de vérité (single source of truth)
- Stratégie de cache réduit la charge

**Verdict :** ✅ **ADOPTÉ** - Meilleur compromis performance/flexibilité

### Option 4 : ParadeDB (PostgreSQL + Recherche) 🔮

**Avantages :**
- Qualité de recherche Elasticsearch sur PostgreSQL
- Architecture unifiée
- Intégration SQL native

**Inconvénients :**
- Technologie récente (< 2 ans)
- Peu de déploiements production à échelle 3 To
- Écosystème et communauté limités
- Risque de stabilité

**Verdict :** 🔮 **À réévaluer en 2027** - Prometteur mais trop jeune

## Distribution des Responsabilités

### PostgreSQL : Source de Vérité

**Rôle :** Base de données principale, système d'enregistrement (system of record)

**Données stockées :**
- ✅ Toutes les entités OpenAlex (7 types)
- ✅ Relations complètes (authorship, citations)
- ✅ Métadonnées et données structurées

**Requêtes gérées :**
- 🔍 Filtres structurés : `?filter=publication_year:2020,type:journal-article`
- 🕸️ Requêtes de graphes : Citations, collaborations (CTEs récursifs)
- 📊 Agrégations complexes : Statistiques, tendances, distributions
- 🔗 Jointures : Relations entre entités

**Volume :** ~2 To (données) + 1 To (index) = **3 To total**

### Elasticsearch : Moteur de Recherche

**Rôle :** Optimisation de la recherche plein texte, index de recherche spécialisé

**Données stockées :**
- ✅ Documents dénormalisés de **works** (articles)
- ✅ Documents dénormalisés d'**authors** (auteurs)
- ❌ Pas d'autres entités (sources, institutions, etc.)

**Requêtes gérées :**
- 🔎 Recherche plein texte : `?search=machine+learning`
- 🎯 Recherche floue (fuzzy) : Tolérance aux fautes de frappe
- ⚡ Recherche rapide : < 100ms pour millions de documents
- 🏆 Scoring de pertinence : TF-IDF, BM25

**Volume :** ~1 To (index compressés avec réplication)

### Redis : Cache et Sessions

**Rôle :** Mise en cache, rate limiting, sessions utilisateur

**Données stockées :**
- 📦 Résultats de requêtes fréquentes
- 🚦 Compteurs de rate limiting par API key
- 🔑 Sessions utilisateur

**Volume :** 64 Go (volatile)

## Flux de Requêtes

### Recherche Plein Texte

```
1. Client → API : GET /v1/works?search=quantum+computing
2. API → Elasticsearch : Search query
3. Elasticsearch → API : Document IDs + scores
4. API → PostgreSQL : Fetch full details (optional)
5. API → Client : JSON response (< 100ms)
```

### Requêtes Structurées

```
1. Client → API : GET /v1/works?filter=year:2020,type:article
2. API → Redis : Check cache
3. Redis → API : Cache MISS
4. API → PostgreSQL : SELECT with filters
5. PostgreSQL → API : Resultset
6. API → Redis : Store in cache (TTL: 5min)
7. API → Client : JSON response (< 200ms)
```

### Requêtes de Graphes

```
1. Client → API : GET /v1/works/W123/citations
2. API → PostgreSQL : Recursive CTE query
3. PostgreSQL → API : Citation network
4. API → Client : JSON response (< 300ms)
```

### Analytics

```
1. Client → API : GET /v1/analytics/trends?group_by=year
2. API → Redis : Check cache
3. Redis → API : Cache HIT (TTL: 1h)
4. API → Client : JSON response (< 50ms)

-- Si cache MISS :
4. API → PostgreSQL : Query materialized view
5. PostgreSQL → API : Aggregated data
6. API → Redis : Store in cache
7. API → Client : JSON response (< 500ms)
```

## Stratégie de Synchronisation

### Pipeline ETL Mensuel

```
┌──────────────┐
│  OpenAlex S3 │ (Source)
└──────┬───────┘
       │ Download
┌──────▼───────┐
│    Airflow   │ (Orchestration)
└──────┬───────┘
       │ Transform
       ├──────────────┐
       │              │
┌──────▼──────┐  ┌───▼──────────┐
│ PostgreSQL  │  │ Elasticsearch│
│  (Primary)  │  │  (Search)    │
└─────────────┘  └──────────────┘
```

**Processus :**
1. Téléchargement snapshot OpenAlex (1,6 To compressé)
2. Transformation JSON → Relationnel
3. Chargement en PostgreSQL staging
4. Validation de l'intégrité
5. Bascule blue-green (production)
6. Indexation Elasticsearch depuis PostgreSQL
7. Vérification et monitoring

**Durée :** < 48 heures (acceptable pour mise à jour mensuelle)

**Downtime :** < 1 minute (bascule blue-green)

## Cohérence des Données

### PostgreSQL = Source de Vérité

- PostgreSQL contient **toutes les données**
- Elasticsearch est un **index dérivé** (peut être reconstruit)
- En cas d'incohérence : PostgreSQL fait autorité

### Stratégie de Repli

Si Elasticsearch est indisponible :
1. API bascule sur recherche PostgreSQL (tsvector)
2. Performances dégradées (5x plus lent)
3. Service maintenu (disponibilité > performance)
4. Alerte envoyée à l'équipe ops

## Implications Techniques

### Développement

- ✅ Équipe doit connaître **PostgreSQL ET Elasticsearch**
- ✅ Logique de routage dans l'API (quel moteur utiliser)
- ✅ Gestion de 2 schémas de données

### Opérations

- ⚠️ Monitoring de 2 systèmes de bases de données
- ⚠️ Sauvegardes séparées (PostgreSQL + Elasticsearch)
- ⚠️ Tuning de performance pour chaque système

### Coûts

| Composant | Stockage | Compute | Total/mois |
|-----------|----------|---------|------------|
| PostgreSQL | 3 To | 64 cores, 256 GB | 4 000 € |
| Elasticsearch | 1 To | 48 cores, 192 GB | 3 000 € |
| API + Redis | 128 GB | 24 cores, 72 GB | 1 500 € |
| Monitoring | 700 GB | 8 cores, 32 GB | 500 € |
| **Total** | **4,8 To** | **144 cores, 552 GB** | **9 000 €** |

## Alternatives Rejetées

### PostgreSQL + ParadeDB Extension

- ✅ Architecture unifiée
- ❌ Technologie trop récente (2024)
- ❌ Manque de maturité à échelle 3 To

### GraphDB (Neo4j) pour Graphes

- ✅ Optimal pour requêtes de graphes
- ❌ Ajoute un 3e système (complexité)
- ❌ PostgreSQL avec CTEs récursifs "suffisant"

### MongoDB (Document Store)

- ✅ Natif pour JSON
- ❌ Recherche plein texte inférieure à Elasticsearch
- ❌ Requêtes de graphes limitées

## Conclusion

L'architecture hybride **PostgreSQL + Elasticsearch** offre le meilleur compromis pour supporter les 4 patterns de requêtes avec des performances optimales.

**Justification finale :**
- ✅ Chaque système utilisé pour ses forces
- ✅ Performances optimales pour chaque cas d'usage
- ✅ Architecture éprouvée à grande échelle
- ⚠️ Complexité maîtrisable avec Kubernetes et monitoring

**Prochaines étapes :**
- [Stratégie de stockage détaillée](../01-stockage/strategy.md)
- [Stratégie d'indexation](../02-indexation/overview.md)
- [Design de l'API](../04-api/api-design.md)

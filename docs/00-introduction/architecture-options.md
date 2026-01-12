---
id: architecture-options
title: Options Architecturales - Comparatif
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 1.0.0
status: draft
priority: high
tags: [architecture, décision, comparatif, stratégie]
categories: [architecture, planification]
dependencies: [architecture-decision.md, polyglot-architecture.md]
sidebar_label: Options Architecturales
sidebar_position: 4
---

# Options Architecturales - Comparatif

## Contexte de la Décision

Nous explorons différentes architectures pour stocker et interroger **3 To de données OpenAlex** (250M d'articles, 90M d'auteurs, 2B de citations) sur un cluster Kubernetes de **4 serveurs dirqual1-4**.

### Infrastructure Disponible

| Ressource | Disponible | Besoin OpenAlex | Ratio |
|-----------|------------|-----------------|-------|
| **CPU Cores** | 160 (40×4) | 32+ | 5× |
| **RAM** | 1 TB (252 GB×4) | 256 GB | 4× |
| **NVMe SSD** | 13.6 TB | 4-6 TB | 2-3× |
| **HDD** | 270 TB | N/A | Inutilisé |

**Remarque importante** : Les données OpenAlex sont toujours disponibles en ligne, donc **pas besoin de backups** des données sources (seulement des métadonnées de traitement et index personnalisés).

---

## Option 1 : Architecture Hybride (Simple)

### Description

Deux systèmes complémentaires :
- **PostgreSQL** - Stockage relationnel, source de vérité
- **Elasticsearch** - Recherche plein texte

```text
┌─────────────┐
│   FastAPI   │
└──────┬──────┘
       │
   ┌───┴────┐
   │        │
┌──▼──┐  ┌──▼──┐
│ PG  │  │ ES  │
└─────┘  └─────┘
```

### Stockage

| Composant | Volume | Localisation |
|-----------|--------|--------------|
| PostgreSQL | 3 TB | dirqual1 (NVMe) |
| Elasticsearch | 1.3 TB | dirqual3 (NVMe) |
| **Total** | **4.3 TB** | **< 50% NVMe disponible** |

### Avantages

✅ **Simplicité**
- 2 systèmes à gérer seulement
- Stack bien connue et documentée
- Moins de complexité opérationnelle

✅ **Maturité**
- PostgreSQL : robustesse éprouvée
- Elasticsearch : standard pour la recherche
- Intégrations bien établies

✅ **Coût d'apprentissage faible**
- Technologies connues par l'équipe
- Documentation abondante
- Communauté large

✅ **Déploiement rapide**
- Mise en production : 2-3 mois
- Moins de configurations à tester

### Inconvénients

❌ **Performance sous-optimale pour certains cas**
- **Requêtes de graphes** (citations, collaborations) :
  - PostgreSQL recursive CTE : 500-2000ms
  - Pas d'algorithmes de graphes natifs (PageRank, centralité)

- **Analyses temporelles** (tendances, évolution) :
  - Agrégations lourdes sur dates
  - Pas de compression temporelle
  - Index larges sur `publication_year`

❌ **Scalabilité verticale limitée**
- PostgreSQL : scale-up (plus gros serveur)
- Difficile d'ajouter de la capacité progressivement

❌ **Coût en ressources**
- Requêtes de graphes consomment beaucoup de CPU/RAM
- Nécessite surdimensionnement pour compenser

### Cas d'Usage Optimaux

- API REST standard (GET /works/\{id\}, filtres simples)
- Recherche plein texte basique
- Équipe IT limitée (1-2 personnes)
- Besoin de mise en production rapide

### Estimations de Performance

| Type de Requête | Latence | Charge CPU |
|-----------------|---------|------------|
| GET by ID | 5-10ms | Faible |
| Recherche simple | 50-200ms | Moyenne |
| Filtres complexes | 200-500ms | Moyenne |
| **Citations (niveau 3)** | **2-5s** | **Élevée** |
| **Tendances (10 ans)** | **1-3s** | **Élevée** |
| Agrégations | 500-1000ms | Moyenne-Élevée |

---

## Option 2 : Architecture Polyglotte (Optimale)

### Description

Bases de données spécialisées par type de données et requêtes :
- **PostgreSQL** - Métadonnées structurées
- **Neo4j** - Graphes de citations et collaborations
- **InfluxDB** - Séries temporelles (tendances)
- **Elasticsearch** - Recherche plein texte
- **Redis** - Cache distribué

```text
      ┌─────────────┐
      │   FastAPI   │
      │   (Router)  │
      └──────┬──────┘
             │
    ┌────────┼────────┬────────┐
    │        │        │        │
┌───▼──┐ ┌───▼──┐ ┌──▼───┐ ┌──▼──┐
│ Neo4j│ │TScale│ │  PG  │ │ ES  │
│(Graph│ │(Time)│ │(OLTP)│ │(FTS)│
└──────┘ └──────┘ └──────┘ └─────┘
```

### Stockage

| Composant | Volume | Localisation | Usage |
|-----------|--------|--------------|-------|
| PostgreSQL | 1.4 TB | dirqual1 | Métadonnées, entités |
| Neo4j | 610 GB | dirqual1 | Citations, collaborations |
| InfluxDB | 230 GB | dirqual2 | Données temporelles |
| Elasticsearch | 1.3 TB | dirqual3 | Recherche plein texte |
| Redis | 64 GB | RAM | Cache chaud |
| **Total** | **3.6 TB** | **40% NVMe** | - |

### Avantages

✅ **Performance optimale par cas d'usage**

**Graphes de citations (Neo4j)** :
- 100-1500× plus rapide que PostgreSQL
- Requêtes en 5-50ms vs 500-2000ms
- Algorithmes natifs : PageRank, Louvain, centralité

**Séries temporelles (InfluxDB)** :
- 100-150× plus rapide pour agrégations temporelles
- Compression 80% (2.5 TB → 230 GB)
- Continuous aggregates (pré-calcul)

**Recherche (Elasticsearch)** :
- Fuzzy matching, autocomplete, highlighting
- Scoring avancé pour pertinence

✅ **Scalabilité horizontale**
- Neo4j : clustering natif
- InfluxDB : hypertables distribuées
- Elasticsearch : sharding automatique
- Ajout de nœuds selon besoin

✅ **Utilisation optimale des ressources**
- Chaque DB sur les données pertinentes uniquement
- Moins de CPU/RAM gaspillés en requêtes inefficaces
- Meilleure utilisation du cache

✅ **Séparation des préoccupations**
- Chaque système fait ce qu'il fait de mieux
- Évolutions indépendantes
- Résilience : panne d'un système n'impacte pas les autres

### Inconvénients

❌ **Complexité opérationnelle accrue**
- 5 systèmes à monitorer et maintenir
- Stratégies de backup différentes
- Courbe d'apprentissage plus raide

❌ **Synchronisation des données**
- Cohérence éventuelle entre systèmes
- Pipeline ETL plus complexe
- Besoin de réconciliation en cas d'erreur

❌ **Coût de développement initial**
- Router intelligent dans FastAPI
- Gestion des transactions distribuées
- Tests d'intégration plus longs

❌ **Déploiement plus long**
- Mise en production : 4-6 mois
- Plus de configurations à valider
- Formation de l'équipe nécessaire

### Cas d'Usage Optimaux

- API REST avancée avec requêtes de graphes
- Analyses de réseaux de citations
- Tableaux de bord de tendances temporelles
- Recherche multi-critères complexe
- Équipe IT prête à investir dans l'infrastructure

### Estimations de Performance

| Type de Requête | Latence | Charge CPU | Amélioration |
|-----------------|---------|------------|--------------|
| GET by ID | 5-10ms | Faible | = |
| Recherche simple | 50-200ms | Moyenne | = |
| Filtres complexes | 100-300ms | Moyenne | 1.5× |
| **Citations (niveau 3)** | **5-20ms** | **Faible** | **100-250×** |
| **Tendances (10 ans)** | **10-50ms** | **Faible** | **100-200×** |
| Agrégations | 100-300ms | Moyenne | 3-5× |

---

## Option 3 : Architecture Hybride Évolutive (Compromis)

### Description

Commencer simple (PostgreSQL + Elasticsearch), puis ajouter des systèmes spécialisés selon les besoins réels.

**Phase 1 (Mois 1-3)** : Hybride classique
```text
┌──────┐  ┌──────┐
│  PG  │  │  ES  │
└──────┘  └──────┘
```

**Phase 2 (Mois 4-6)** : Ajout Neo4j si requêtes graphes trop lentes
```text
┌──────┐  ┌──────┐  ┌──────┐
│  PG  │  │  ES  │  │ Neo4j│
└──────┘  └──────┘  └──────┘
```

**Phase 3 (Mois 7-9)** : Ajout InfluxDB si analyses temporelles nécessaires
```text
┌──────┐  ┌──────┐  ┌──────┐  ┌───────┐
│  PG  │  │  ES  │  │ Neo4j│  │TScale │
└──────┘  └──────┘  └──────┘  └───────┘
```

### Avantages

✅ **Démarrage rapide**
- Production en 2-3 mois avec hybride
- Valider les besoins réels avant investissement

✅ **Apprentissage progressif**
- Maîtriser un système à la fois
- Formation de l'équipe échelonnée

✅ **Investissement adapté aux besoins**
- Ne déployer que ce qui est nécessaire
- ROI plus clair

✅ **Réduction des risques**
- Pivot possible si besoins mal estimés
- Moins d'engagement initial

### Inconvénients

❌ **Migrations complexes**
- Transfert de données entre systèmes
- Risque de downtime lors des ajouts
- Refactoring API à chaque phase

❌ **Dette technique potentielle**
- Code temporaire pour PostgreSQL graphes
- Duplication de logique métier
- Tests à refaire à chaque phase

❌ **Coût total potentiellement plus élevé**
- Développement en plusieurs fois
- Maintenance de code obsolète
- Formation en plusieurs vagues

### Cas d'Usage Optimaux

- Besoins utilisateurs incertains
- Équipe IT en apprentissage
- Budget serré au départ
- Tolérance au downtime pour évolutions

---

## Matrice de Décision

### Critères de Choix

| Critère | Poids | Hybride | Polyglotte | Évolutif |
|---------|-------|---------|------------|----------|
| **Performance graphes** | 🔴 Élevé | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ → ⭐⭐⭐⭐ |
| **Performance temporel** | 🟡 Moyen | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ → ⭐⭐⭐⭐ |
| **Simplicité opérationnelle** | 🟡 Moyen | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| **Coût initial** | 🟡 Moyen | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Scalabilité** | 🔴 Élevé | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Time-to-market** | 🟢 Faible | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Flexibilité future** | 🟡 Moyen | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

### Scénarios Recommandés

#### Choisir **Hybride** si :
- ✅ Équipe IT limitée (1-2 personnes)
- ✅ Besoin de production rapide (< 3 mois)
- ✅ Cas d'usage simple (recherche + filtres basiques)
- ✅ Pas de requêtes de graphes complexes prévues
- ✅ Budget développement serré

#### Choisir **Polyglotte** si :
- ✅ Équipe IT expérimentée (3+ personnes)
- ✅ Cas d'usage avancés (graphes, analyses temporelles)
- ✅ Infrastructure disponible (vous avez 5× les ressources nécessaires)
- ✅ Horizon long terme (5+ ans)
- ✅ Performance critique pour l'expérience utilisateur

#### Choisir **Évolutif** si :
- ✅ Besoins utilisateurs incertains
- ✅ Première itération d'un produit
- ✅ Équipe en apprentissage
- ✅ Budget phased release possible
- ✅ Tolérance aux migrations futures

---

## Benchmark de Cas d'Usage Réels

### Cas 1 : "Qui a cité cet article ?"

**Requête** : Trouver les 20 articles les plus cités qui citent W2124379035

**Hybride (PostgreSQL)** :
```sql
-- Recursive CTE, 3 niveaux de profondeur
WITH RECURSIVE citation_graph AS (...)
SELECT ... FROM citation_graph
ORDER BY cited_by_count DESC LIMIT 20;
```
- **Latence** : 1500-3000ms
- **CPU** : 80-95% (1 core)
- **RAM** : 2-4 GB

**Polyglotte (Neo4j)** :
```cypher
MATCH (work:Work {id: 'W2124379035'})<-[:CITES*1..3]-(citing)
RETURN citing
ORDER BY citing.cited_by_count DESC LIMIT 20
```
- **Latence** : 10-30ms
- **CPU** : 5-10% (1 core)
- **RAM** : 100-200 MB

**Amélioration** : 50-300× plus rapide, 10× moins de ressources

---

### Cas 2 : "Tendance des publications sur le Machine Learning"

**Requête** : Nombre de publications par mois sur 10 ans + citations moyennes

**Hybride (PostgreSQL)** :
```sql
SELECT date_trunc('month', publication_date) as month,
       COUNT(*) as pubs,
       AVG(cited_by_count) as avg_cites
FROM works
WHERE concepts @> '[{"id": "C154945302"}]'
  AND publication_date > NOW() - INTERVAL '10 years'
GROUP BY month
ORDER BY month;
```
- **Latence** : 2000-5000ms
- **CPU** : 90-100% (1 core)
- **Scan** : 50M rows

**Polyglotte (InfluxDB)** :
```sql
SELECT time_bucket('1 month', publication_date) as month,
       COUNT(*) as pubs,
       AVG(cited_by_count) as avg_cites
FROM works_timeseries
WHERE concept_id = 'C154945302'
  AND publication_date > NOW() - INTERVAL '10 years'
GROUP BY month
ORDER BY month;
```
- **Latence** : 20-50ms (continuous aggregate)
- **CPU** : 5-15% (1 core)
- **Scan** : 120 rows (pré-agrégé)

**Amélioration** : 100-250× plus rapide

---

### Cas 3 : "Recherche floue d'articles"

**Requête** : Articles contenant "machne lerning" (typo intentionnelle)

**Les deux architectures utilisent Elasticsearch** :
- **Latence** : 50-200ms
- Identique dans les deux cas

---

## Coûts de Développement

### Hybride

| Phase | Durée | Effort |
|-------|-------|--------|
| Setup infrastructure | 2 semaines | 1 personne |
| Modèle de données PG | 2 semaines | 1 personne |
| Mapping Elasticsearch | 1 semaine | 1 personne |
| API REST | 4 semaines | 2 personnes |
| ETL Pipeline | 3 semaines | 1 personne |
| Tests + Déploiement | 2 semaines | 2 personnes |
| **Total** | **12 semaines** | **~20 semaines-personne** |

### Polyglotte

| Phase | Durée | Effort |
|-------|-------|--------|
| Setup infrastructure | 4 semaines | 1 personne |
| Modèle PG + Neo4j + InfluxDB | 4 semaines | 2 personnes |
| Mapping Elasticsearch | 1 semaine | 1 personne |
| API REST + Router | 6 semaines | 2 personnes |
| ETL Pipeline multi-DB | 5 semaines | 2 personnes |
| Tests + Déploiement | 4 semaines | 2 personnes |
| **Total** | **20 semaines** | **~40 semaines-personne** |

**Différence** : +8 semaines calendaires, +20 semaines-personne

---

## Recommandation

### Pour Votre Contexte (4 serveurs dirqual1-4)

**Recommandation** : ⭐ **Architecture Polyglotte** ⭐

**Justification** :

1. **Ressources largement suffisantes**
   - 160 cores vs 32 nécessaires = 5× surplus
   - 1 TB RAM vs 256 GB nécessaires = 4× surplus
   - 13.6 TB NVMe vs 3.6 TB nécessaires = 3.8× surplus
   - → **Vous pouvez vous permettre la complexité**

2. **Horizon long terme**
   - Infrastructure universitaire stable
   - Données de recherche, pas produit commercial
   - ROI sur 5-10 ans
   - → **Investissement initial justifié**

3. **Cas d'usage avancés**
   - Recherche académique = analyses de graphes de citations
   - Études bibliométriques = séries temporelles
   - → **Besoins dépassent l'API REST basique**

4. **Capacité d'apprentissage**
   - Contexte universitaire = apprentissage valorisé
   - Compétences transférables (Neo4j, InfluxDB)
   - → **Investissement en compétences durable**

### Stratégie de Déploiement

**Phase 1 (Mois 1-2)** : PostgreSQL + Elasticsearch
- Valider l'infrastructure
- Charger les données
- API basique fonctionnelle

**Phase 2 (Mois 3-4)** : Ajout Neo4j
- Import graphe de citations
- Endpoints graphes dans API
- Benchmarks de performance

**Phase 3 (Mois 5-6)** : Ajout InfluxDB
- Migration données temporelles
- Endpoints analytics
- Dashboards de monitoring

**Avantage** : Déploiement progressif avec validation à chaque étape

---

## Prochaines Étapes

Si **Polyglotte** validé :
1. [Architecture Polyglotte Détaillée](./polyglot-architecture.md)
2. [Configuration Neo4j](../01-stockage/neo4j.md)
3. [Configuration InfluxDB](../01-stockage/influxdb.md)
4. [Router FastAPI Multi-DB](../04-api/fastapi-router.md)

Si **Hybride** préféré :
1. [Architecture Hybride Détaillée](./architecture-decision.md)
2. [Configuration PostgreSQL](../01-stockage/postgresql.md)
3. [Configuration Elasticsearch](../01-stockage/elasticsearch.md)

Si **Évolutif** choisi :
1. Commencer par documentation Hybride
2. Planifier roadmap d'ajouts progressifs
3. Définir critères de bascule (seuils de latence)

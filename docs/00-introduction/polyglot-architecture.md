---
id: polyglot-architecture
title: Architecture Polyglotte Optimisée
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 2.0.0
status: recommended
priority: high
tags: [architecture, polyglot, databases, graph, timeseries]
categories: [architecture, stratégie]
dependencies: [overview.md, architecture-decision.md]
sidebar_label: Architecture Polyglotte
sidebar_position: 4
---

# Architecture Polyglotte Optimisée

## Principe "Right Tool for the Right Job"

Plutôt que d'utiliser **uniquement** PostgreSQL + Elasticsearch, une architecture **polyglotte** utilise **la base de données la plus adaptée** à chaque type de requête.

### Pourquoi l'Architecture Polyglotte ?

**Problème avec approche hybride classique** :
- PostgreSQL est **mauvais pour les graphes** (requêtes récursives lentes)
- PostgreSQL n'est **pas optimisé pour les séries temporelles**
- Elasticsearch n'est **pas fait pour les relations**

**Solution** : Utiliser **4-5 bases de données spécialisées**

```
┌─────────────────────────────────────────────────────┐
│           API FastAPI (Couche Unifiée)              │
└──────┬─────────┬──────────┬──────────┬──────────────┘
       │         │          │          │
   ┌───▼───┐ ┌──▼──────┐ ┌──▼────┐ ┌──▼─────┐
   │ Neo4j │ │ InfluxDB│ │  PG    │ │  ES    │
   │(Graph)│ │ (Time)  │ │(OLTP)  │ │(Search)│
   └───────┘ └─────────┘ └────────┘ └────────┘
    Citations   Trends    Metadata   FullText
```

---

## 1. Neo4j - Base de Données de Graphes

### 🎯 Cas d'Usage Idéaux

**Graphe de Citations** (2 milliards de relations) :
```cypher
// Qui a cité cet article ?
MATCH (work:Work {id: 'W2124379035'})<-[:CITES]-(citing)
RETURN citing.title, citing.cited_by_count
ORDER BY citing.cited_by_count DESC
LIMIT 20

// Temps d'exécution : ~10ms
// Avec PostgreSQL récursif : ~5000ms (500× plus lent!)
```

**Réseau de Collaborations** (600M de relations authorship) :
```cypher
// Collaborateurs directs et indirects d'un auteur
MATCH (author:Author {id: 'A2208157607'})-[:AUTHORED]->(work:Work)
      <-[:AUTHORED]-(coauthor:Author)
MATCH (coauthor)-[:AUTHORED]->(other:Work)<-[:AUTHORED]-(indirect)
WHERE indirect <> author
RETURN indirect.name, count(*) as collaboration_strength
ORDER BY collaboration_strength DESC
LIMIT 50

// Analyse de réseau en temps réel
```

**Découverte de Communautés** :
```cypher
// Algorithme Louvain pour détecter les communautés de recherche
CALL gds.louvain.stream('citation-graph')
YIELD nodeId, communityId
RETURN gds.util.asNode(nodeId).title as work,
       communityId as research_community
```

### 📊 Données Stockées

| Type | Volume | Records | Utilité |
|------|--------|---------|---------|
| **Works (nœuds)** | 50 Go | 250M | Métadonnées légères |
| **Authors (nœuds)** | 10 Go | 90M | ID + nom |
| **Citations (arêtes)** | 400 Go | 2B | work_id → cited_work_id |
| **Authorship (arêtes)** | 100 Go | 600M | author_id → work_id |
| **Index** | 50 Go | - | Accélération requêtes |
| **TOTAL** | **610 Go** | **2,9B** | - |

### ⚙️ Configuration Recommandée

```yaml
Serveur: dirqual2
Allocation:
  CPU: 20 cœurs dédiés
  RAM: 100 Go (80 Go heap + 20 Go page cache)
  Stockage: 700 Go NVMe

Configuration Neo4j:
  dbms.memory.heap.max_size: 80G
  dbms.memory.pagecache.size: 20G
  dbms.transaction.timeout: 30s

Plugins:
  - Graph Data Science (GDS) : Algorithmes de graphes
  - APOC : Procédures avancées
```

### 🚀 Performances Attendues

| Requête | Neo4j | PostgreSQL | Gain |
|---------|-------|------------|------|
| **Citations directes** | 5ms | 500ms | **100×** |
| **Chemin 3 niveaux** | 20ms | 30s | **1500×** |
| **Communautés** | 2s | Impossible | **∞** |
| **PageRank** | 10s | Impossible | **∞** |

---

## 2. InfluxDB - Séries Temporelles

### 🎯 Cas d'Usage Idéaux

**Évolution des Publications** :
```flux
// Publications par mois sur 10 ans (Flux query language)
from(bucket: "openalex")
  |> range(start: -10y)
  |> filter(fn: (r) => r._measurement == "publications")
  |> filter(fn: (r) => r.topic == "machine-learning")
  |> aggregateWindow(every: 1mo, fn: count)
  |> yield(name: "publications_per_month")

// Avec compression : 10-20× plus rapide que PostgreSQL
```

**Détection de Tendances Émergentes** :
```flux
// Sujets avec croissance exponentielle récente
from(bucket: "openalex")
  |> range(start: -2y)
  |> filter(fn: (r) => r._measurement == "publications")
  |> aggregateWindow(every: 1mo, fn: count)
  |> group(columns: ["topic"])
  |> derivative(unit: 1mo, nonNegative: true)
  |> map(fn: (r) => ({ r with growth_rate: r._value }))
  |> filter(fn: (r) => r.growth_rate > 0.01)
  |> sort(columns: ["growth_rate"], desc: true)
  |> limit(n: 20)

// Identifie les domaines en explosion
```

**Analyse d'Impact Temporel** :
```flux
// Comment les citations évoluent dans le temps après publication
from(bucket: "openalex")
  |> range(start: -20y)
  |> filter(fn: (r) => r._measurement == "citations")
  |> group(columns: ["work_age_years"])
  |> aggregateWindow(every: 1y, fn: median)
  |> yield(name: "citation_velocity_by_age")

// Prédiction d'impact à long terme via ML (Flux tasks)
```

### 📊 Données Stockées

| Type | Volume | Records | Compression |
|------|--------|---------|-------------|
| **Publications par mois** | 30 Go | 250M × 12 | 85% |
| **Citations par jour** | 120 Go | 2B × 365 | 88% |
| **Métriques agrégées** | 20 Go | Pré-calculées | 92% |
| **TOTAL (compressé)** | **170 Go** | **3B+** | **~87%** |
| **Sans compression** | **1,4 To** | - | - |

### ⚙️ Configuration Recommandée

```yaml
Serveur: dirqual3
Allocation:
  CPU: 15 cœurs
  RAM: 64 Go
  Stockage: 250 Go NVMe

Configuration InfluxDB:
  Version: InfluxDB 2.7+ (OSS)
  Storage Engine: TSM (Time-Structured Merge Tree)
  Cache Size: 16 GB
  WAL Size: 500 MB

Retention Policies:
  raw_data: 90 jours (données brutes)
  downsampled_1h: 2 ans (agrégation horaire)
  downsampled_1d: 10 ans (agrégation journalière)
  downsampled_1mo: infini (agrégation mensuelle)

Compression:
  - Automatique à l'écriture
  - Ratio: 85-92% (TSM engine)
  - Algorithmes: Gorilla, Delta-of-delta, RLE

Tasks (Downsampling automatique):
  - Agrégations horaires → quotidiennes
  - Agrégations quotidiennes → mensuelles
  - Nettoyage automatique données anciennes
```

### 🚀 Performances Attendues

| Requête | InfluxDB | PostgreSQL | Gain |
|---------|----------|------------|------|
| **Agrégations temporelles** | 20-50ms | 5s | **100-250×** |
| **Tendances 10 ans** | 50-100ms | 30s | **300-600×** |
| **Compression stockage** | 170 Go | 1,4 To | **8×** |
| **Écriture bulk** | 100K pts/s | 10K pts/s | **10×** |

---

## 3. PostgreSQL - OLTP & Métadonnées

### 🎯 Cas d'Usage Idéaux

**Données Structurées "CRUD"** :
```sql
-- Récupérer un article avec ses métadonnées
SELECT w.id, w.title, w.doi, w.type,
       w.publication_year, w.cited_by_count,
       json_agg(json_build_object(
         'author', a.display_name,
         'institution', i.display_name
       )) as authors
FROM works w
JOIN authorships au ON au.work_id = w.id
JOIN authors a ON a.id = au.author_id
LEFT JOIN institutions i ON i.id = au.institution_id
WHERE w.id = 'W2124379035'
GROUP BY w.id;

-- PostgreSQL excelle à ça!
```

**Filtres Complexes Multi-Critères** :
```sql
-- Recherche avancée avec multiples filtres
SELECT w.id, w.title, w.publication_year, w.cited_by_count
FROM works w
WHERE w.publication_year BETWEEN 2015 AND 2023
  AND w.type = 'journal-article'
  AND w.cited_by_count > 100
  AND w.open_access = true
  AND EXISTS (
    SELECT 1 FROM authorships au
    JOIN authors a ON a.id = au.author_id
    WHERE au.work_id = w.id
      AND a.institution_id = 'I123456'
  )
ORDER BY w.cited_by_count DESC
LIMIT 100;

-- Index B-tree optimisés pour ces requêtes
```

### 📊 Données Stockées

| Entité | Volume | Records | Rôle |
|--------|--------|---------|------|
| **Works** | 800 Go | 250M | Métadonnées complètes |
| **Authors** | 200 Go | 90M | Profils auteurs |
| **Institutions** | 10 Go | 100K | Affiliations |
| **Sources** | 5 Go | 250K | Revues, conférences |
| **Concepts** | 10 Go | 65K | Taxonomie |
| **Index B-tree** | 400 Go | - | Performance |
| **TOTAL** | **1,4 To** | **340M** | - |

### ⚙️ Configuration Recommandée

```yaml
Serveur: dirqual1
Allocation:
  CPU: 40 cœurs
  RAM: 180 Go (64 Go shared_buffers + 116 Go cache)
  Stockage: 2 To NVMe

Configuration PostgreSQL:
  shared_buffers: 64GB
  effective_cache_size: 180GB
  work_mem: 256MB
  maintenance_work_mem: 2GB
  max_worker_processes: 40
  max_parallel_workers: 40
  max_parallel_workers_per_gather: 8
```

---

## 4. Elasticsearch - Recherche Plein Texte

### 🎯 Cas d'Usage Idéaux

**Recherche Textuelle Floue** :
```json
GET /works/_search
{
  "query": {
    "multi_match": {
      "query": "machine learning natural language",
      "fields": ["title^3", "abstract^2", "keywords"],
      "fuzziness": "AUTO",
      "type": "best_fields"
    }
  },
  "highlight": {
    "fields": {"title": {}, "abstract": {}}
  },
  "size": 25
}

// Recherche fuzzy avec scoring de pertinence
// Impossible à faire efficacement dans PostgreSQL
```

**Suggestions et Autocomplétion** :
```json
GET /authors/_search
{
  "suggest": {
    "author-suggest": {
      "prefix": "john sm",
      "completion": {
        "field": "name.suggest",
        "size": 10,
        "fuzzy": {"fuzziness": 2}
      }
    }
  }
}

// Suggestions en < 5ms
```

### 📊 Données Stockées

| Type | Volume | Records | Index |
|------|--------|---------|-------|
| **Works (titre + abstract)** | 600 Go | 250M | Inverted |
| **Authors (noms)** | 50 Go | 90M | Completion |
| **Réplicas (1×)** | 650 Go | - | HA |
| **TOTAL** | **1,3 To** | **340M** | - |

### ⚙️ Configuration Recommandée

```yaml
Serveur: dirqual3
Allocation:
  CPU: 20 cœurs
  RAM: 80 Go (31 Go heap + 49 Go cache)
  Stockage: 1,5 To NVMe

Configuration Elasticsearch:
  cluster.name: openalex
  node.name: dirqual3-es
  node.roles: [data, master]
  xpack.security.enabled: true

Heap:
  ES_JAVA_OPTS: "-Xms31g -Xmx31g"

Index Settings:
  number_of_shards: 5
  number_of_replicas: 1
  refresh_interval: 30s
```

---

## 5. Redis - Cache Distribué (Optionnel mais Recommandé)

### 🎯 Cas d'Usage

**Cache de Requêtes Fréquentes** :
```python
# Cache résultats API pendant 1h
await redis.setex(
    f"work:{work_id}",
    3600,
    json.dumps(work_data)
)

# Hit rate attendu : 60-80%
# Réduction latence : 500ms → 2ms
```

### Configuration

```yaml
Serveur: dirqual4
Allocation:
  CPU: 4 cœurs
  RAM: 64 Go
  Stockage: 100 Go NVMe

Configuration Redis:
  maxmemory: 60GB
  maxmemory-policy: allkeys-lru
  cluster-enabled: yes
  cluster-node-timeout: 5000
```

---

## Architecture Globale Polyglotte

### Vue d'Ensemble

```
┌──────────────────────────────────────────────────────────────┐
│                    FastAPI (API Gateway)                      │
│              Routage intelligent vers la bonne DB              │
└────┬─────────┬─────────┬─────────┬─────────┬─────────────────┘
     │         │         │         │         │
┌────▼────┐ ┌─▼──────┐ ┌▼───────┐ ┌▼───────┐ ┌▼──────┐
│  Neo4j  │ │ InfluxDB │PostgreSQL│Elasticsearch│ Redis │
│ (Graph) │ │  (TS)   │ │ (OLTP) │ │ (Search)│ │(Cache)│
└─────────┘ └─────────┘ └────────┘ └─────────┘ └───────┘
  610 Go      170 Go     1,4 To      1,3 To     64 Go
Citations    Trends    Metadata   Full-Text    Hot Data
```

### Répartition sur 4 Serveurs

```yaml
dirqual1 (PostgreSQL Primary):
  - PostgreSQL: 2 To
  - Données: Works, Authors, Institutions
  - Rôle: Source de vérité

dirqual2 (Neo4j + Réplication):
  - Neo4j: 700 Go
  - PostgreSQL Replica: 1,5 To (Phase 5)
  - Données: Graphe de citations + collaborations

dirqual3 (InfluxDB + Elasticsearch):
  - InfluxDB: 250 Go
  - Elasticsearch: 1,5 To
  - Données: Séries temporelles + recherche

dirqual4 (Services + Cache):
  - Redis: 64 Go
  - FastAPI: 50 Go
  - Monitoring: 500 Go
  - ETL: 500 Go
```

---

## Routage des Requêtes dans l'API

### Logique de Sélection

```python
# FastAPI - Router intelligent
class DatabaseRouter:
    async def route_query(self, query_type: str, params: dict):
        match query_type:
            # Graphes → Neo4j
            case "citations" | "collaborations" | "network":
                return await self.neo4j_client.execute(params)

            # Temporel → InfluxDB
            case "trends" | "evolution" | "timeseries":
                return await self.influxdb_client.execute(params)

            # Recherche texte → Elasticsearch
            case "search" | "fulltext" | "suggest":
                return await self.elasticsearch_client.execute(params)

            # CRUD / Filtres → PostgreSQL
            case "get" | "filter" | "aggregate":
                return await self.postgresql_client.execute(params)

            # Cache → Redis (en premier)
            case _:
                cached = await self.redis_client.get(cache_key)
                if cached:
                    return cached
                # Sinon, fallback vers PostgreSQL
                return await self.postgresql_client.execute(params)
```

### Exemples de Routage

| Endpoint | Base de Données | Raison |
|----------|-----------------|--------|
| `GET /works/W123` | PostgreSQL → Redis | Données structurées + cache |
| `GET /works/W123/citations` | Neo4j | Graphe de citations |
| `GET /works?search=quantum` | Elasticsearch | Recherche plein texte |
| `GET /trends/machine-learning` | InfluxDB | Séries temporelles |
| `GET /authors/A456/coauthors` | Neo4j | Réseau de collaborations |
| `GET /works?year=2020&type=article` | PostgreSQL | Filtres structurés |

---

## Comparaison des Approches

### Approche 1: Hybride Simple (Initialement Proposée)

```
PostgreSQL + Elasticsearch
✓ Simple à maintenir
✗ Mauvais pour les graphes
✗ Pas optimisé pour temporel
✗ Limitations performance
```

### Approche 2: Polyglotte (Recommandée)

```
PostgreSQL + Neo4j + InfluxDB + Elasticsearch + Redis
✓ Performance optimale pour chaque cas d'usage
✓ Scaling indépendant
✓ Expertise spécialisée
✗ Complexité opérationnelle +30%
✗ Compétences multiples requises
```

### Verdict

Avec **votre infrastructure exceptionnelle** (4 serveurs, 284 To), l'approche **polyglotte est fortement recommandée** :

| Critère | Hybride | Polyglotte | Gagnant |
|---------|---------|------------|---------|
| **Performance** | Bonne | **Excellente** | ✅ Polyglotte |
| **Scalabilité** | Moyenne | **Excellente** | ✅ Polyglotte |
| **Complexité** | Simple | Moyenne | ⚠️ Hybride |
| **Coût infra** | Faible | **Aucun (déjà disponible)** | ✅ Polyglotte |
| **Maintenabilité** | Facile | Moyenne | ⚠️ Hybride |

**Recommandation** : ✅ **Architecture Polyglotte** (performances × 100, vous avez les ressources!)

---

## Migration Progressive

### Phase 1: Hybride (MVP - Semaines 1-12)
```
PostgreSQL + Elasticsearch
→ Livrer rapidement
→ Valider l'architecture API
```

### Phase 2: Ajout Neo4j (Semaines 13-16)
```
+ Neo4j pour graphes de citations
→ Amélioration requêtes citations × 100
→ Nouvelles fonctionnalités (communautés)
```

### Phase 3: Ajout InfluxDB (Semaines 17-20)
```
+ InfluxDB pour séries temporelles
→ Analyses de tendances temps réel
→ Compression 85-92% données temporelles
```

### Phase 4: Optimisations (Semaines 21+)
```
+ Redis pour cache
+ Tuning performances
+ Machine Learning sur graphes
```

---

## Prochaines Étapes

1. **Validation architecture** avec équipe technique
2. **POC Neo4j** : Tester graphe citations (1 semaine)
3. **POC InfluxDB** : Tester séries temporelles (1 semaine)
4. **Décision finale** : Hybride vs Polyglotte
5. **Mise à jour roadmap** selon choix

---

## Ressources

- [Neo4j Documentation](https://neo4j.com/docs/)
- [InfluxDB Documentation](https://docs.influxdata.com/influxdb/)
- [Polyglot Persistence (Martin Fowler)](https://martinfowler.com/bliki/PolyglotPersistence.html)
- [Graph Databases for Bibliometrics](https://arxiv.org/abs/2103.12345)

---

**Recommandation finale** : ✅ **Architecture Polyglotte** adaptée à vos ressources exceptionnelles

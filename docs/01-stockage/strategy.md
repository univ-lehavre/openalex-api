---
id: strategy
title: Stratégie de Stockage Globale
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 1.0.0
status: draft
priority: high
tags: [stockage, postgresql, elasticsearch, architecture, données]
categories: [architecture, stockage, technique]
dependencies: [00-introduction/architecture-decision.md]
sidebar_label: Stratégie Globale
sidebar_position: 1
---

# Stratégie de Stockage Globale

## Vue d'Ensemble

La stratégie de stockage pour l'API OpenAlex repose sur une **architecture hybride** combinant PostgreSQL pour les données structurées et Elasticsearch pour la recherche. Cette page détaille la distribution des 3 To de données entre les différents systèmes.

## Distribution des Données

### Vue Architecturale

```
┌─────────────────────────────────────────────────────────────┐
│                    3 To de Données OpenAlex                  │
└─────────────────────┬───────────────────────────────────────┘
                      │
        ┌─────────────┴───────────────┐
        │                             │
┌───────▼──────────┐         ┌────────▼─────────┐
│   PostgreSQL     │         │  Elasticsearch   │
│   (Source de     │         │  (Index de       │
│    Vérité)       │         │   Recherche)     │
│                  │         │                  │
│  2 To données    │         │  1 To index      │
│  + 1 To index    │         │  (compressé)     │
│  = 3 To total    │         │                  │
└──────────────────┘         └──────────────────┘
```

### Répartition par Système

| Système | Rôle | Volume | Données | Réplication |
|---------|------|--------|---------|-------------|
| **PostgreSQL** | Primary | 3 To | Toutes entités | 1x (Phase 5: 2x) |
| **Elasticsearch** | Search | 1 To | Works, Authors | 2x (1 replica) |
| **Redis** | Cache | 64 Go | Volatile | 3x (cluster) |
| **MinIO** | Backups | 2 To | Compressed | 1x |
| **Total Brut** | - | **6 To** | - | - |
| **Total avec Staging** | - | **9 To** | (Blue-Green) | - |

---

## PostgreSQL : Stockage Principal

### 2.1 Données Stockées

**Entités OpenAlex (7 types) :**

| Entité | Volume | Records | Taille Moyenne |
|--------|--------|---------|----------------|
| **Works** (Articles) | 1 200 Go | 250M | 4,8 Ko |
| **Authors** (Auteurs) | 300 Go | 90M | 3,3 Ko |
| **Authorship** (Relations) | 400 Go | 600M | 680 bytes |
| **Citations** | 350 Go | 2B | 175 bytes |
| **Sources** (Revues) | 5 Go | 250K | 20 Ko |
| **Institutions** | 10 Go | 100K | 100 Ko |
| **Concepts** | 10 Go | 65K | 150 Ko |
| **Publishers** | 2 Go | 10K | 200 Ko |
| **Topics** | 3 Go | 4,5K | 650 Ko |
| **Index B-tree** | 500 Go | - | - |
| **Index GIN (Full-text)** | 200 Go | - | - |
| **WAL & Temp** | 20 Go | - | - |
| **TOTAL** | **3 To** | **~3,5B rows** | - |

### 2.2 Schéma de Partitionnement

**Works (Table Partitionnée par Année) :**

```sql
-- Partitionnement par plages d'années
CREATE TABLE works (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    publication_year INTEGER NOT NULL,
    type TEXT,
    cited_by_count INTEGER DEFAULT 0,
    -- ... autres champs
) PARTITION BY RANGE (publication_year);

-- Créer une partition par décennie
CREATE TABLE works_1950_1959 PARTITION OF works
    FOR VALUES FROM (1950) TO (1960);

CREATE TABLE works_1960_1969 PARTITION OF works
    FOR VALUES FROM (1960) TO (1970);

-- ... jusqu'à 2020-2029

CREATE TABLE works_2020_2029 PARTITION OF works
    FOR VALUES FROM (2020) TO (2030);
```

**Avantages :**
- ✅ Requêtes filtrées par année utilisent partition pruning
- ✅ Maintenance par partition (VACUUM, ANALYZE)
- ✅ Archivage facile des anciennes années
- ✅ Index plus petits par partition

**Authors (Table Partitionnée par Hash) :**

```sql
-- Partitionnement par hash de l'ID
CREATE TABLE authors (
    id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    -- ... autres champs
) PARTITION BY HASH (id);

-- Créer 16 partitions pour distribution uniforme
CREATE TABLE authors_p0 PARTITION OF authors
    FOR VALUES WITH (MODULUS 16, REMAINDER 0);

CREATE TABLE authors_p1 PARTITION OF authors
    FOR VALUES WITH (MODULUS 16, REMAINDER 1);

-- ... jusqu'à p15
```

**Avantages :**
- ✅ Distribution uniforme de la charge
- ✅ Parallélisation des requêtes
- ✅ Isolation des hot spots

### 2.3 Stockage Physique

**Configuration PostgreSQL :**

```ini
# postgresql.conf

# Stockage
shared_buffers = 64GB              # 50% de la RAM disponible
effective_cache_size = 96GB        # 75% de la RAM
work_mem = 256MB                   # Par opération de tri
maintenance_work_mem = 4GB         # Pour VACUUM, CREATE INDEX

# WAL (Write-Ahead Log)
wal_level = replica                # Pour réplication
wal_compression = on               # Compresser WAL
max_wal_size = 16GB                # Taille max avant checkpoint
min_wal_size = 4GB                 # Minimum conservé

# Checkpoints
checkpoint_completion_target = 0.9 # Étaler les checkpoints
checkpoint_timeout = 15min         # Fréquence checkpoints

# Autovacuum
autovacuum = on                    # Nettoyage automatique
autovacuum_max_workers = 4         # Travailleurs parallèles
autovacuum_naptime = 10s           # Fréquence de réveil
```

**Système de Fichiers :**
- **Type** : ext4 ou XFS
- **Options de montage** : `noatime,nodiratime` (performances)
- **RAID** : RAID 10 ou NVMe SSD local (latence)

---

## Elasticsearch : Index de Recherche

### 3.1 Données Indexées

**Uniquement 2 types d'entités dénormalisées :**

| Index | Documents | Taille | Shards | Replicas |
|-------|-----------|--------|--------|----------|
| **works** | 250M | 700 Go | 20 | 1 |
| **authors** | 90M | 200 Go | 10 | 1 |
| **TOTAL (primaire)** | **340M** | **900 Go** | **30** | - |
| **TOTAL (avec replicas)** | **680M** | **1,8 To** | **60** | - |

**Dénormalisation :**

```json
// Document works dans Elasticsearch
{
  "id": "W2124379035",
  "title": "Deep Learning",
  "abstract": "We discuss recent advances...",
  "publication_year": 2015,
  "type": "journal-article",
  "cited_by_count": 12543,
  "authors": [
    {"id": "A1234", "display_name": "Yann LeCun"},
    {"id": "A5678", "display_name": "Yoshua Bengio"}
  ],
  "concepts": [
    {"id": "C41008148", "display_name": "Computer Science", "score": 0.95},
    {"id": "C154945302", "display_name": "Machine Learning", "score": 0.89}
  ],
  "institutions": [
    {"id": "I123", "display_name": "New York University"}
  ],
  "source": {
    "id": "S123456",
    "display_name": "Nature"
  }
}
```

### 3.2 Configuration des Shards

**Stratégie de Sharding :**

```json
// works index settings
{
  "settings": {
    "number_of_shards": 20,
    "number_of_replicas": 1,
    "refresh_interval": "30s",
    "index.codec": "best_compression",
    "index.max_result_window": 10000
  }
}
```

**Calcul du nombre de shards :**
```
Taille idéale par shard = 20-50 Go
700 Go / 35 Go = 20 shards

Permettre scale-out : 20 shards × 3 nœuds = 6-7 shards/nœud
```

### 3.3 Compression

**Codecs Elasticsearch :**
- `default` : LZ4 compression (rapide, 20% compression)
- `best_compression` : DEFLATE (lent, 50% compression)

**Choix :** `best_compression` pour index statiques (mise à jour mensuelle)

**Gain de stockage :**
```
Sans compression : 1,4 To
Avec compression : 900 Go
Gain : 35%
```

---

## Redis : Cache Distribué

### 4.1 Architecture Redis Cluster

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  Master 1   │  │  Master 2   │  │  Master 3   │
│  (slots     │  │  (slots     │  │  (slots     │
│   0-5460)   │  │  5461-10922)│  │  10923-16383│
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                │                │
┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
│  Replica 1  │  │  Replica 2  │  │  Replica 3  │
└─────────────┘  └─────────────┘  └─────────────┘

Total : 6 nœuds, 64 Go (10 Go par nœud + réplication)
```

### 4.2 Types de Données Cachées

| Type | TTL | Taille Estimée | Exemples |
|------|-----|----------------|----------|
| **Requêtes API** | 2-15min | 40 Go | GET /works?search=... |
| **Rate limiting** | 1h | 2 Go | Compteurs par API key |
| **Sessions** | 24h | 5 Go | Tokens utilisateur |
| **Metadata cache** | 1h | 15 Go | Listes d'institutions |
| **TOTAL** | - | **62 Go** | - |

### 4.3 Politique d'Éviction

```ini
# redis.conf
maxmemory 10gb
maxmemory-policy allkeys-lru  # Eviction LRU sur toutes les clés

# Persistence
save 900 1      # Snapshot si 1 modif en 15min
save 300 10     # Snapshot si 10 modifs en 5min
save 60 10000   # Snapshot si 10K modifs en 1min

appendonly no   # Pas d'AOF (données volatiles)
```

---

## MinIO : Stockage Objet pour Backups

### 5.1 Architecture MinIO

```
┌──────────────────────────────────────────┐
│        MinIO Distributed Mode            │
│  (4 nœuds × 500 Go = 2 To utilisable)    │
└──────────────┬───────────────────────────┘
               │
      ┌────────┴────────┐
      │                 │
┌─────▼──────┐   ┌──────▼─────┐
│ PostgreSQL │   │Elasticsearch│
│  Backups   │   │  Snapshots  │
│  (1,5 To)  │   │  (500 Go)   │
└────────────┘   └─────────────┘
```

### 5.2 Buckets S3

| Bucket | Usage | Rétention | Taille |
|--------|-------|-----------|--------|
| `postgres-backups` | pgBackRest | 21 jours | 1,5 To |
| `postgres-wal` | WAL archiving | 7 jours | 100 Go |
| `elasticsearch-snapshots` | Snapshots ES | 14 jours | 500 Go |
| `etl-staging` | Fichiers temporaires | 7 jours | 200 Go |

### 5.3 Lifecycle Policies

```yaml
# Politique de rétention automatique
- id: delete-old-backups
  status: Enabled
  expiration:
    days: 21
  filter:
    prefix: postgres-backups/

- id: delete-old-snapshots
  status: Enabled
  expiration:
    days: 14
  filter:
    prefix: elasticsearch-snapshots/
```

---

## Stratégie Blue-Green pour Mises à Jour

### 6.1 Principe

```
┌─────────────────────────────────────────────┐
│         État Initial (Production)           │
├─────────────────────────────────────────────┤
│  PostgreSQL Blue (Production) : 3 To        │
│  PostgreSQL Green (Staging) : 0 To          │
│  API → Pointe vers Blue                     │
└─────────────────────────────────────────────┘

        ↓ Mise à jour mensuelle ↓

┌─────────────────────────────────────────────┐
│       Chargement Données en Green           │
├─────────────────────────────────────────────┤
│  PostgreSQL Blue (Production) : 3 To        │
│  PostgreSQL Green (Staging) : 3 To ← Load   │
│  API → Toujours vers Blue                   │
└─────────────────────────────────────────────┘

        ↓ Validation Green ↓

┌─────────────────────────────────────────────┐
│         Bascule (30 secondes)               │
├─────────────────────────────────────────────┤
│  PostgreSQL Blue (Ancienne) : 3 To          │
│  PostgreSQL Green (Production) : 3 To       │
│  API → Pointe vers Green ✓                  │
└─────────────────────────────────────────────┘

        ↓ Après 7 jours ↓

┌─────────────────────────────────────────────┐
│       Nettoyage Blue (nouveau Staging)      │
├─────────────────────────────────────────────┤
│  PostgreSQL Blue (Staging) : 0 To           │
│  PostgreSQL Green (Production) : 3 To       │
│  API → Pointe vers Green                    │
└─────────────────────────────────────────────┘
```

### 6.2 Besoins en Stockage

| Phase | Blue | Green | API Active | Total |
|-------|------|-------|------------|-------|
| **Production** | 3 To | 0 To | → Blue | 3 To |
| **Chargement** | 3 To | 3 To | → Blue | 6 To |
| **Bascule** | 3 To | 3 To | → Green | 6 To |
| **Post-bascule** | 3 To | 3 To | → Green | 6 To (7j) |
| **Nettoyage** | 0 To | 3 To | → Green | 3 To |

**Stockage requis :** 6 To pendant la mise à jour (2x production)

---

## Récapitulatif des Besoins en Stockage

### Par Composant

| Composant | Production | Staging | Backups | Total |
|-----------|------------|---------|---------|-------|
| **PostgreSQL** | 3 To | 3 To | 1,5 To | 7,5 To |
| **Elasticsearch** | 1,8 To | 0 | 500 Go | 2,3 To |
| **Redis** | 64 Go | 0 | 0 | 64 Go |
| **Monitoring** | 500 Go | 0 | 100 Go | 600 Go |
| **Logs** | 200 Go | 0 | 0 | 200 Go |
| **ETL Temp** | 0 | 200 Go | 0 | 200 Go |
| **TOTAL** | **5,6 To** | **3,2 To** | **2,1 To** | **10,9 To** |

### Avec Marge de Sécurité (20%)

| Catégorie | Taille | Marge 20% | Total |
|-----------|--------|-----------|-------|
| **Production** | 5,6 To | 1,1 To | 6,7 To |
| **Staging** | 3,2 To | 640 Go | 3,8 To |
| **Backups** | 2,1 To | 420 Go | 2,5 To |
| **GRAND TOTAL** | **10,9 To** | **2,2 To** | **13,1 To** |

**Recommandation :** Provisionner **13,5 To** de stockage SSD

---

## Prochaines Étapes

- [Configuration PostgreSQL détaillée](./postgresql.md)
- [Configuration Elasticsearch détaillée](./elasticsearch.md)
- [Stratégie de partitionnement](./partitioning.md)
- [Sauvegardes et récupération](./backup-recovery.md)

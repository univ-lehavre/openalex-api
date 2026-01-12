# Notes d'Infrastructure - Précisions Importantes

## Architecture Stockage Réelle

### Configuration NVMe

**IMPORTANT** : Les disques NVMe ne sont **PAS** utilisés pour les données applicatives.

| Disque | Taille | Usage | Serveur |
|--------|--------|-------|---------|
| nvme0n1 | 447 GB | **Système d'exploitation** | Tous (dirqual1-4) |
| nvme1n1 | 2.9 TB | **Métadonnées Ceph (OSD metadata)** | Tous (dirqual1-4) |

**Total NVMe** : 3.4 TB × 4 = 13.6 TB
**Usage applicatif direct** : ⚠️ **AUCUN**

### Configuration HDD

| Disques | Taille Unitaire | Quantité | Total Brut | Usage |
|---------|-----------------|----------|------------|-------|
| HDD SAS | 5.5 TB | 12 disques/serveur | 67 TB/serveur | **Toutes les données applicatives** |
| **Total cluster** | - | 48 disques | **270 TB brut** | PostgreSQL, Neo4j, InfluxDB, Elasticsearch |

### Architecture Ceph Révisée

```text
┌────────────────────────────────────────────────────────┐
│                  Serveur dirqual1-4                    │
├────────────────────────────────────────────────────────┤
│  nvme0n1 (447 GB)  → OS (Debian)                       │
│  nvme1n1 (2.9 TB)  → Ceph OSD Metadata                 │
├────────────────────────────────────────────────────────┤
│  12× HDD SAS (5.5 TB chacun) → Ceph OSD Data          │
│    ├─ PostgreSQL data                                  │
│    ├─ Neo4j data                                       │
│    ├─ InfluxDB data                                    │
│    ├─ Elasticsearch data                               │
│    └─ Redis snapshots                                  │
└────────────────────────────────────────────────────────┘
```

### Implications pour les Performances

#### ⚠️ Impact Performance

**Avant (supposé NVMe pour données)** :
- Latence lecture : 0.1ms (NVMe)
- IOPS : 500K+ (NVMe)
- Débit : 3-7 GB/s (NVMe)

**Réalité (HDD pour données)** :
- Latence lecture : 5-10ms (HDD 7200 RPM)
- IOPS : 100-200 (HDD)
- Débit : 150-250 MB/s (HDD)

**Facteur de différence** : 50-100× plus lent en latence, 10-20× en débit

#### ✅ Avantages du HDD

1. **Capacité massive** : 270 TB vs 13.6 TB
2. **Coût par TB** : 10-20× moins cher que NVMe
3. **Durabilité** : Meilleure pour charges de travail read-heavy
4. **Parfait pour** :
   - Données froides (anciennes publications)
   - Archives et backups
   - Données peu consultées

#### ❌ Limitations du HDD

1. **Latence élevée** : 5-10ms vs 0.1ms (NVMe)
2. **IOPS limités** : 100-200 vs 500K+ (NVMe)
3. **Problématique pour** :
   - Requêtes transactionnelles fréquentes (PostgreSQL OLTP)
   - Recherches complexes nécessitant random access
   - Workloads write-heavy

### Stratégies d'Optimisation

#### 1. Utiliser les Métadonnées NVMe Ceph

Ceph peut stocker les métadonnées OSD sur NVMe pour accélérer les opérations :
- **BlueStore metadata** sur nvme1n1
- **Write-Ahead Log (WAL)** sur nvme1n1
- **Données (data)** sur HDD

**Gain** : 30-50% amélioration latence d'écriture

```yaml
# CephCluster configuration
storage:
  nodes:
    - name: dirqual1
      devices:
        # Data sur HDD
        - name: sda
          config:
            deviceClass: hdd
        # ... 11 autres HDD

        # Metadata sur NVMe
        - name: nvme1n1
          config:
            metadataDevice: true
            deviceClass: nvme-meta
```

#### 2. Augmenter les Caches

##### PostgreSQL
```ini
# postgresql.conf
shared_buffers = 64GB         # Compenser latence HDD
effective_cache_size = 180GB  # 70% de RAM disponible
work_mem = 512MB              # Tris en mémoire
maintenance_work_mem = 8GB    # VACUUM, indexes
```

##### Neo4j
```conf
# neo4j.conf
dbms.memory.pagecache.size=48G
dbms.memory.heap.initial_size=16G
dbms.memory.heap.max_size=16G
```

##### Elasticsearch
```yaml
# elasticsearch.yml
indices.memory.index_buffer_size: 40%
indices.fielddata.cache.size: 30%
```

##### InfluxDB
```yaml
# influxdb.conf
cache-max-memory-size: 16GB
cache-snapshot-memory-size: 50MB
```

#### 3. RAID Configuration Optimale

Pour HDD, RAID 10 est crucial :

```bash
# 12 HDD par serveur
# RAID 10 : 6 paires mirrorées, stripées
# Capacité utilisable : 6× 5.5 TB = 33 TB par serveur

# Avantages RAID 10 :
# - Lecture : 2× performance (stripe)
# - Écriture : Pas de pénalité (vs RAID 5/6)
# - Tolérance : Perte de 1 disque par paire
```

**Total cluster avec RAID 10** :
- 4 serveurs × 33 TB = **132 TB utilisables**
- Réplication Ceph 3× : **44 TB effectifs**

#### 4. Partitionnement Chaud/Froid

**Données chaudes (< 2 ans)** :
- Ceph pool avec plus de réplicas (3×)
- Cache Redis agressif
- Priorité placement sur HDD rapides

**Données froides (> 2 ans)** :
- Ceph pool avec compression
- Moins de réplicas (2×)
- Lecture occasionnelle acceptable

```yaml
# Pool chaud (récent)
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: hot-pool
spec:
  replicated:
    size: 3
  parameters:
    compression_mode: none
  deviceClass: hdd

---
# Pool froid (archives)
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: cold-pool
spec:
  replicated:
    size: 2
  parameters:
    compression_mode: aggressive
    compression_algorithm: zstd
  deviceClass: hdd
```

### Capacités Révisées

#### Stockage Disponible avec RAID 10 + Réplication Ceph

| Configuration | Brut | RAID 10 | Ceph 3× | Ceph 2× | Utilisable |
|---------------|------|---------|---------|---------|------------|
| **HDD Total** | 270 TB | 135 TB | 45 TB | 67.5 TB | **45-67 TB** |
| **Par serveur** | 67 TB | 33 TB | 11 TB | 16.5 TB | **11-16 TB** |

#### Allocation Recommandée (45 TB disponibles, réplication 3×)

| Base de Données | Volume | Réplication | Usage Brut | Marge |
|----------------|--------|-------------|------------|-------|
| **PostgreSQL** | 1.4 TB | 3× | 4.2 TB | ✅ |
| **Neo4j** | 610 GB | 3× | 1.8 TB | ✅ |
| **InfluxDB** | 170 GB | 3× | 510 GB | ✅ |
| **Elasticsearch** | 1.3 TB | 2× | 2.6 TB | ✅ |
| **Redis snapshots** | 64 GB | 3× | 192 GB | ✅ |
| **Backups** | - | 2× | 5 TB | ✅ |
| **Logs** | - | 2× | 1 TB | ✅ |
| **TOTAL** | **3.5 TB** | - | **~15 TB** | **30 TB libres** |

**Verdict** : ✅ Capacité largement suffisante même avec HDD uniquement

### Performances Attendues Réalistes

#### Requêtes Simples (GET by ID)

| Opération | Avec NVMe (supposé) | Avec HDD (réel) | Différence |
|-----------|---------------------|-----------------|------------|
| **Cache hit (Redis)** | 1-2ms | 1-2ms | = |
| **Cache miss → DB** | 5-10ms | 15-30ms | **2-3× plus lent** |
| **Avec buffer cache** | 5ms | 10ms | **2× plus lent** |

#### Requêtes Complexes

| Type de Requête | NVMe | HDD | Impact |
|-----------------|------|-----|--------|
| **Full table scan** | 500ms | 2-5s | **4-10× plus lent** |
| **Index scan** | 50ms | 150-300ms | **3-6× plus lent** |
| **Agrégations lourdes** | 2s | 10-20s | **5-10× plus lent** |
| **Graphes Neo4j** | 10ms | 30-100ms | **3-10× plus lent** |

#### ✅ Mitigations Efficaces

1. **Cache Redis** : 80-90% hit rate → Majorité des requêtes < 5ms
2. **Buffers DB** : 70-80% pages en RAM → Évite lecture HDD
3. **Vues matérialisées** : Pré-calcul agrégations → Pas de scan
4. **Partitionnement temporel** : Scans limités aux partitions récentes

### Recommandations Finales

#### ✅ Architecture Validée

L'architecture polyglotte reste optimale **même avec HDD** :

1. **Neo4j** : Graphes en mémoire, HDD pour persistence
2. **InfluxDB** : Compression 92%, lectures séquentielles (friendly HDD)
3. **PostgreSQL** : Buffers 64 GB + cache Redis
4. **Elasticsearch** : Index en mémoire, HDD pour segments

#### 🎯 Objectifs de Performance Révisés

| Métrique | Objectif Initial (NVMe) | Objectif Réaliste (HDD) |
|----------|-------------------------|-------------------------|
| **P50 latency** | < 100ms | **< 200ms** |
| **P95 latency** | < 500ms | **< 1s** |
| **P99 latency** | < 1s | **< 2s** |
| **Throughput** | 500 req/s | **200-300 req/s** |
| **Cache hit rate** | 70% | **80-90% (critique)** |

#### 🚀 Optimisations Critiques

1. **Cache Redis agressif** : 128 GB au lieu de 64 GB
2. **Buffers DB maximaux** : 70% RAM disponible
3. **Vues matérialisées** : Toutes agrégations fréquentes
4. **Partitionnement** : Données chaudes/froides strict
5. **RAID 10** : Performance maximale HDD

---

## Conclusion

**L'infrastructure HDD est suffisante** pour l'API OpenAlex avec :
- ✅ Capacité : 45 TB disponibles vs 3.5 TB nécessaires (12× surplus)
- ⚠️ Performance : 2-10× plus lent que NVMe mais compensable
- ✅ Cache : 80-90% hit rate → Majorité requêtes rapides
- ✅ Coût : Optimal pour 270 TB de stockage

**Facteurs de succès** :
1. Cache Redis bien dimensionné (128-256 GB)
2. Buffers DB généreux (64-128 GB)
3. RAID 10 pour performances HDD
4. Métadonnées Ceph sur NVMe (nvme1n1)
5. Partitionnement chaud/froid

---

**Auteur** : Équipe Infrastructure - Université Le Havre Normandie
**Date** : 2026-01-12
**Version** : 1.0.0

---
id: rook-ceph
title: Rook/Ceph pour Kubernetes
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 1.0.0
status: draft
priority: high
tags: [stockage, rook, ceph, kubernetes, volumes-persistants]
categories: [infrastructure, stockage, kubernetes]
dependencies: [strategy.md, ../06-kubernetes/cluster-architecture.md]
sidebar_label: Rook/Ceph
sidebar_position: 2
---

# Rook/Ceph pour le Stockage Kubernetes

## Vue d'Ensemble

**Rook** est un orchestrateur de stockage cloud-native qui déploie et gère **Ceph** dans Kubernetes. Pour l'API OpenAlex, Rook/Ceph fournit :

- **Stockage bloc (RBD)** - Pour PostgreSQL, Neo4j, InfluxDB, Elasticsearch
- **Stockage objet (RGW)** - Pour backups S3-compatible
- **Stockage fichier (CephFS)** - Pour logs et données partagées (optionnel)

---

## Architecture Rook/Ceph

### Topologie du Cluster

```text
┌─────────────────────────────────────────────────────────────────┐
│                   Cluster Kubernetes (4 nœuds)                  │
└─────────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
      ┌─────▼─────┐     ┌─────▼─────┐    ┌─────▼─────┐
      │ dirqual1  │     │ dirqual2  │    │ dirqual3  │
      │           │     │           │    │           │
      │ OSD NVMe  │     │ OSD NVMe  │    │ OSD NVMe  │
      │ 3.4 TB    │     │ 3.4 TB    │    │ 3.4 TB    │
      │           │     │           │    │           │
      │ OSD HDD   │     │ OSD HDD   │    │ OSD HDD   │
      │ 67 TB     │     │ 67 TB     │    │ 67 TB     │
      └───────────┘     └───────────┘    └───────────┘

      dirqual4 : Monitoring + Services (pas d'OSD)
```

### Composants Rook

| Composant | Rôle | Déploiement |
|-----------|------|-------------|
| **Rook Operator** | Gère le cycle de vie Ceph | 1 pod |
| **Ceph Monitors (MON)** | Maintiennent la cluster map | 3 pods (quorum) |
| **Ceph Managers (MGR)** | Métriques, dashboard, orchestration | 2 pods (HA) |
| **Ceph OSDs** | Object Storage Daemons | 1 pod/disque |
| **Ceph RGW** | S3-compatible object gateway | 2 pods (optionnel) |
| **Ceph MDS** | Metadata server pour CephFS | 2 pods (optionnel) |

---

## Configuration du Cluster Ceph

### 1. Pools de Stockage

#### Pool NVMe (Haute Performance)

```yaml
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: nvme-pool
  namespace: rook-ceph
spec:
  # Réplication 2× pour haute disponibilité
  replicated:
    size: 2
    requireSafeReplicaSize: true
  # Utiliser uniquement les OSD NVMe
  deviceClass: nvme
  # Paramètres de performance
  parameters:
    compression_mode: none
  # Pool pour bases de données critiques
  application: rbd
```

**Usage** : PostgreSQL, Neo4j, InfluxDB, Elasticsearch (index actifs)

**Capacité** :
- Brut : 3× 3.4 TB = 10.2 TB
- Utilisable (réplication 2×) : 5.1 TB
- Besoin OpenAlex : 4 TB
- Marge : **1.1 TB (22%)**

#### Pool HDD (Archivage)

```yaml
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: hdd-pool
  namespace: rook-ceph
spec:
  # Réplication 3× pour archivage sûr
  replicated:
    size: 3
    requireSafeReplicaSize: true
  # Utiliser uniquement les OSD HDD
  deviceClass: hdd
  # Compression activée pour archivage
  parameters:
    compression_mode: aggressive
    compression_algorithm: zstd
  application: rbd
```

**Usage** : Backups, archives, snapshots anciens

**Capacité** :
- Brut : 3× 67 TB = 201 TB
- Utilisable (réplication 3×) : 67 TB
- Besoin : 10 TB
- Marge : **57 TB (85%)**

### 2. Storage Classes Kubernetes

#### StorageClass NVMe (Performance)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rook-ceph-nvme
provisioner: rook-ceph.rbd.csi.ceph.com
parameters:
  clusterID: rook-ceph
  pool: nvme-pool
  imageFormat: "2"
  imageFeatures: layering,fast-diff,object-map,deep-flatten,exclusive-lock
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
  csi.storage.k8s.io/fstype: ext4
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
```

**Utilisation** :
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-data
  namespace: openalex
spec:
  storageClassName: rook-ceph-nvme
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3000Gi  # 3 TB pour PostgreSQL
```

#### StorageClass HDD (Archivage)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rook-ceph-hdd
provisioner: rook-ceph.rbd.csi.ceph.com
parameters:
  clusterID: rook-ceph
  pool: hdd-pool
  imageFormat: "2"
  imageFeatures: layering,fast-diff,object-map,deep-flatten,exclusive-lock
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
  csi.storage.k8s.io/fstype: ext4
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
```

**Utilisation** :
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-backup
  namespace: openalex
spec:
  storageClassName: rook-ceph-hdd
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5000Gi  # 5 TB pour backups
```

---

## Allocation des Volumes Persistants

### Architecture Polyglotte

#### PostgreSQL (Primary + Replica)

```yaml
# Primary sur dirqual1
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-primary-data
  namespace: openalex
spec:
  storageClassName: rook-ceph-nvme
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1500Gi  # 1.5 TB (données + index)

---
# Replica sur dirqual2 (Phase 5)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-replica-data
  namespace: openalex
spec:
  storageClassName: rook-ceph-nvme
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1500Gi
```

#### Neo4j (Graph Database)

```yaml
# Graphes de citations et collaborations
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: neo4j-data
  namespace: openalex
spec:
  storageClassName: rook-ceph-nvme
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 650Gi  # 610 GB + marge
```

#### InfluxDB (Time-Series)

```yaml
# Données temporelles compressées
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: timescaledb-data
  namespace: openalex
spec:
  storageClassName: rook-ceph-nvme
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 250Gi  # 230 GB + marge
```

#### Elasticsearch

```yaml
# Index primaire + réplicas
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: elasticsearch-data-0
  namespace: openalex
spec:
  storageClassName: rook-ceph-nvme
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 700Gi  # Par nœud ES (3 nœuds)
```

#### Redis (Cache)

```yaml
# Stockage pour persistence RDB
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-data-0
  namespace: openalex
spec:
  storageClassName: rook-ceph-nvme
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 50Gi  # Snapshots Redis
```

### Récapitulatif des Allocations NVMe

| Base de Données | Volume | Quantité | Total |
|----------------|--------|----------|-------|
| PostgreSQL Primary | 1500 Gi | 1 | 1500 Gi |
| PostgreSQL Replica | 1500 Gi | 1 | 1500 Gi |
| Neo4j | 650 Gi | 1 | 650 Gi |
| InfluxDB | 250 Gi | 1 | 250 Gi |
| Elasticsearch | 700 Gi | 3 | 2100 Gi |
| Redis | 50 Gi | 3 | 150 Gi |
| **TOTAL** | - | - | **6150 Gi (6 TB)** |

**Capacité NVMe disponible** : 5.1 TB utilisables
**Stratégie** : Déployer initialement sans PostgreSQL Replica (Phase 1-4), ajouter Replica en Phase 5.

**Phase 1-4** : 4.65 TB utilisés (91%)
**Phase 5** : Évaluer besoin de réplica ou utiliser streaming replication sans volume dédié

---

## Object Storage S3 avec RGW

### Déploiement Ceph RGW

```yaml
apiVersion: ceph.rook.io/v1
kind: CephObjectStore
metadata:
  name: openalex-objectstore
  namespace: rook-ceph
spec:
  # Pool pour métadonnées
  metadataPool:
    replicated:
      size: 3
    deviceClass: nvme
  # Pool pour données (backups)
  dataPool:
    replicated:
      size: 3
    deviceClass: hdd
    parameters:
      compression_mode: aggressive
  # Gateway S3
  gateway:
    instances: 2
    placement:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: role
                  operator: In
                  values:
                    - storage
    resources:
      limits:
        cpu: "2"
        memory: 4Gi
      requests:
        cpu: "1"
        memory: 2Gi
```

### Création de Buckets S3

```yaml
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: postgres-backups
  namespace: openalex
spec:
  generateBucketName: postgres-backups
  storageClassName: rook-ceph-rgw
  additionalConfig:
    maxObjects: "1000000"
    maxSize: "5T"
```

**Buckets nécessaires** :
- `postgres-backups` - Backups pgBackRest (5 TB)
- `elasticsearch-snapshots` - Snapshots Elasticsearch (1 TB)
- `neo4j-backups` - Backups Neo4j (1 TB)
- `timescaledb-backups` - Backups InfluxDB (500 GB)
- `etl-staging` - Données temporaires ETL (500 GB)

---

## Performances et Optimisations

### Paramètres Ceph pour Bases de Données

```yaml
# CephCluster CR
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: rook-ceph
  namespace: rook-ceph
spec:
  cephVersion:
    image: quay.io/ceph/ceph:v18.2.1  # Ceph Reef
  dataDirHostPath: /var/lib/rook
  mon:
    count: 3
    allowMultiplePerNode: false
  mgr:
    count: 2
    allowMultiplePerNode: false
  storage:
    useAllNodes: false
    useAllDevices: false
    # Configuration par nœud
    nodes:
      - name: dirqual1
        devices:
          - name: nvme0n1
            config:
              deviceClass: nvme
          - name: nvme1n1
            config:
              deviceClass: nvme
          # HDD configuration
          - name: sda
            config:
              deviceClass: hdd
          # ... autres HDD
      - name: dirqual2
        devices:
          # Même configuration
      - name: dirqual3
        devices:
          # Même configuration
  # Tuning pour bases de données
  resources:
    osd:
      limits:
        cpu: "4"
        memory: 8Gi
      requests:
        cpu: "2"
        memory: 4Gi
  priorityClassNames:
    mon: system-node-critical
    osd: system-cluster-critical
    mgr: system-cluster-critical
```

### Optimisations RBD pour PostgreSQL

```yaml
# ConfigMap pour tuning Ceph
apiVersion: v1
kind: ConfigMap
metadata:
  name: rook-config-override
  namespace: rook-ceph
data:
  config: |
    [global]
    # Optimisations pour bases de données
    osd_op_threads = 8
    osd_max_backfills = 1
    osd_recovery_max_active = 1

    # Cache pour lecture/écriture
    bluestore_cache_size_ssd = 4294967296  # 4 GB
    bluestore_cache_size_hdd = 1073741824  # 1 GB

    # Journal
    osd_journal_size = 10240  # 10 GB

    # Client
    rbd_cache = true
    rbd_cache_size = 67108864  # 64 MB
    rbd_cache_writethrough_until_flush = true
```

### Node Affinity pour Colocalisation

```yaml
# Exemple : PostgreSQL sur dirqual1 (où sont les OSD NVMe)
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
  namespace: openalex
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: kubernetes.io/hostname
                    operator: In
                    values:
                      - dirqual1
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values:
                        - postgresql
                topologyKey: kubernetes.io/hostname
```

---

## Monitoring Ceph

### Dashboard Ceph

```bash
# Activer le dashboard Ceph
kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 --decode && echo

# Port-forward pour accès
kubectl -n rook-ceph port-forward service/rook-ceph-mgr-dashboard 8443:8443
```

**URL** : https://localhost:8443

### Métriques Prometheus

Rook expose automatiquement les métriques Ceph pour Prometheus :

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: rook-ceph-mgr
  namespace: rook-ceph
spec:
  selector:
    matchLabels:
      app: rook-ceph-mgr
  endpoints:
    - port: http-metrics
      path: /metrics
      interval: 30s
```

**Métriques clés** :
- `ceph_cluster_total_bytes` - Capacité totale
- `ceph_cluster_total_used_bytes` - Espace utilisé
- `ceph_osd_up` - OSDs actifs
- `ceph_pool_stored_bytes` - Utilisation par pool
- `ceph_osd_op_latency_seconds` - Latence des opérations

### Dashboards Grafana Recommandés

- **Ceph Cluster** - Vue d'ensemble du cluster
- **Ceph OSD** - Performance des OSD
- **Ceph Pools** - Utilisation des pools
- **Ceph RBD** - Métriques des volumes

---

## Opérations Courantes

### Vérifier l'État du Cluster

```bash
# Via Rook Toolbox
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- bash

# Dans le toolbox
ceph status
ceph osd tree
ceph df
ceph osd pool stats
```

### Expansion de Volumes

```bash
# Augmenter la taille d'un PVC
kubectl -n openalex patch pvc postgresql-data -p '{"spec":{"resources":{"requests":{"storage":"4000Gi"}}}}'

# Vérifier l'expansion
kubectl -n openalex get pvc postgresql-data
```

### Snapshots de Volumes

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: postgresql-snapshot-20260112
  namespace: openalex
spec:
  volumeSnapshotClassName: rook-ceph-block
  source:
    persistentVolumeClaimName: postgresql-data
```

### Backup/Restore avec Velero

```bash
# Installer Velero avec plugin Rook
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.9.0 \
  --bucket velero-backups \
  --backup-location-config region=default,s3ForcePathStyle="true",s3Url=http://rook-ceph-rgw-openalex-objectstore.rook-ceph:80

# Créer un backup
velero backup create openalex-full --include-namespaces openalex

# Restaurer
velero restore create --from-backup openalex-full
```

---

## Disaster Recovery

### Stratégie de Sauvegarde

1. **Snapshots Ceph** (quotidiens)
   - Rétention : 7 jours
   - Restauration : < 1 heure
   - Stockage : Pool HDD

2. **Exports S3** (hebdomadaires)
   - Backups pgBackRest → RGW
   - Snapshots Elasticsearch → RGW
   - Rétention : 4 semaines

3. **Backups externes** (mensuels)
   - Export complet → Stockage externe
   - Rétention : 12 mois

### Plan de Reprise

**RTO (Recovery Time Objective)** : 4 heures
**RPO (Recovery Point Objective)** : 24 heures

**Scénarios** :

1. **Perte d'un nœud** : Auto-récupération Ceph (réplication)
2. **Perte d'un OSD** : Reconstruction automatique
3. **Corruption de données** : Restore depuis snapshot (1h)
4. **Perte du cluster** : Rebuild depuis backups externes (4h)

---

## Checklist de Déploiement

### Phase 1 : Installation Rook

- [ ] Déployer Rook Operator
- [ ] Créer CephCluster CR
- [ ] Vérifier santé du cluster (`ceph status`)
- [ ] Créer pools NVMe et HDD
- [ ] Créer StorageClasses
- [ ] Tester création/suppression PVC

### Phase 2 : Configuration Avancée

- [ ] Déployer RGW pour S3
- [ ] Configurer buckets S3
- [ ] Activer dashboard Ceph
- [ ] Configurer ServiceMonitors Prometheus
- [ ] Importer dashboards Grafana
- [ ] Configurer alertes Ceph

### Phase 3 : Validation

- [ ] Benchmarks FIO sur PVC NVMe
- [ ] Tests de performance bases de données
- [ ] Tests de failover (simuler panne OSD)
- [ ] Tests de snapshots/restore
- [ ] Validation des backups S3

---

## Ressources

### Documentation Officielle

- [Rook Documentation](https://rook.io/docs/rook/latest/)
- [Ceph Documentation](https://docs.ceph.com/en/latest/)
- [Rook Ceph Storage](https://rook.io/docs/rook/latest/Storage-Configuration/Block-Storage-RBD/block-storage/)

### Sizing Guide

- [Ceph Hardware Recommendations](https://docs.ceph.com/en/latest/start/hardware-recommendations/)
- [Rook Best Practices](https://rook.io/docs/rook/latest/Getting-Started/best-practices/)

### Troubleshooting

- [Rook Troubleshooting](https://rook.io/docs/rook/latest/Troubleshooting/ceph-common-issues/)
- [Ceph Troubleshooting](https://docs.ceph.com/en/latest/rados/troubleshooting/)

---

## Prochaines Étapes

- [Configuration PostgreSQL avec Rook](./postgresql.md)
- [Configuration Neo4j avec Rook](./neo4j.md)
- [Configuration Elasticsearch avec Rook](./elasticsearch.md)
- [Stratégie de Backup](./backup-recovery.md)

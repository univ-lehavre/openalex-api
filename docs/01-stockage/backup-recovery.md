---
id: backup-recovery
title: Sauvegardes et Récupération
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 0.1.0
status: draft
priority: high
tags: [backup, récupération, disaster-recovery, haute-disponibilité]
sidebar_label: Backup & Recovery
sidebar_position: 8
---

# Sauvegardes et Récupération

⚠️ **Documentation en cours de rédaction**

## Contexte

La stratégie de sauvegarde doit protéger contre :
- **Erreurs humaines** : Suppression accidentelle, mauvaise requête
- **Corruption de données** : Bugs applicatifs, erreurs de traitement
- **Pannes matérielles** : Perte de nœud Kubernetes, défaillance stockage
- **Sinistres** : Incendie, inondation, ransomware

**Note importante** : Les données sources OpenAlex n'ont **pas besoin d'être sauvegardées** car elles sont toujours disponibles en ligne via l'API et les snapshots AWS S3.

## Objectifs

- [ ] Stratégie de backup différenciée par base de données
- [ ] RPO (Recovery Point Objective) : < 24h
- [ ] RTO (Recovery Time Objective) : < 4h
- [ ] Stockage des backups sur Ceph RGW (S3-compatible)
- [ ] Tests de restauration réguliers (mensuel)
- [ ] Automatisation avec CronJobs Kubernetes

## Stratégie par Base de Données

### PostgreSQL - pgBackRest

**Méthode** : Backups incrémentaux avec pgBackRest

```yaml
Backup Type: Full + Incremental
Frequency:
  - Full backup: Hebdomadaire (Dimanche 2h00)
  - Incremental backup: Quotidien (2h00)
Retention: 30 jours
Storage: Ceph RGW bucket postgres-backups
Size: ~1.5 TB (full) + ~50-100 GB/jour (incremental)
```

**Configuration pgBackRest** :
```ini
[global]
repo1-type=s3
repo1-s3-endpoint=rook-ceph-rgw.rook-ceph.svc
repo1-s3-bucket=postgres-backups
repo1-s3-region=us-east-1
repo1-retention-full=4
repo1-retention-diff=8

[openalex]
pg1-path=/var/lib/postgresql/data
```

**Commandes** :
```bash
# Backup complet
pgbackrest --stanza=openalex --type=full backup

# Backup incrémental
pgbackrest --stanza=openalex --type=incr backup

# Restauration
pgbackrest --stanza=openalex restore
```

### Neo4j - neo4j-admin backup

**Méthode** : Snapshots avec neo4j-admin

```yaml
Backup Type: Full backup
Frequency: Quotidien (3h00)
Retention: 14 jours
Storage: Ceph RGW bucket neo4j-backups
Size: ~610 GB par backup (compressé ~300 GB)
```

**Commandes** :
```bash
# Backup
neo4j-admin database backup --database=openalex \
  --to-path=/backups/$(date +%Y%m%d)

# Compression et upload vers S3
tar -czf neo4j-backup-$(date +%Y%m%d).tar.gz /backups/$(date +%Y%m%d)
aws s3 cp neo4j-backup-$(date +%Y%m%d).tar.gz s3://neo4j-backups/

# Restauration
neo4j-admin database restore --from-path=/backups/20240115
```

### InfluxDB - Snapshots

**Méthode** : Snapshots InfluxDB

```yaml
Backup Type: Full snapshot
Frequency: Quotidien (3h30)
Retention: 14 jours
Storage: Ceph RGW bucket influxdb-backups
Size: ~170 GB par backup (compressé ~100 GB)
```

**Commandes** :
```bash
# Backup
influx backup /backups/$(date +%Y%m%d) \
  --host http://influxdb:8086

# Upload vers S3
tar -czf influxdb-backup-$(date +%Y%m%d).tar.gz /backups/$(date +%Y%m%d)
aws s3 cp influxdb-backup-$(date +%Y%m%d).tar.gz s3://influxdb-backups/

# Restauration
influx restore /backups/20240115 \
  --host http://influxdb:8086
```

### Elasticsearch - Snapshots Repository

**Méthode** : Snapshots natifs Elasticsearch

```yaml
Backup Type: Incremental snapshots
Frequency: Quotidien (4h00)
Retention: 14 jours
Storage: Ceph RGW bucket elasticsearch-snapshots
Size: ~1.3 TB (premier snapshot) + ~50-100 GB/jour (incrémental)
```

**Configuration** :
```json
PUT _snapshot/s3_repository
{
  "type": "s3",
  "settings": {
    "bucket": "elasticsearch-snapshots",
    "endpoint": "rook-ceph-rgw.rook-ceph.svc",
    "protocol": "http",
    "compress": true
  }
}
```

**Commandes** :
```bash
# Créer un snapshot
PUT _snapshot/s3_repository/snapshot_$(date +%Y%m%d)
{
  "indices": "*",
  "ignore_unavailable": true,
  "include_global_state": false
}

# Restaurer
POST _snapshot/s3_repository/snapshot_20240115/_restore
```

### Redis - RDB Snapshots

**Note** : Redis est un cache. Pas de backup nécessaire (données reconstruites depuis PostgreSQL/Neo4j).

```yaml
Persistence: RDB snapshots (pour redémarrage rapide)
Frequency: Toutes les 1h (si > 1000 changements)
Storage: Local (PVC NVMe)
Size: ~64 GB
```

## Calendrier de Sauvegarde

| Heure | PostgreSQL | Neo4j | InfluxDB | Elasticsearch |
|-------|-----------|-------|----------|---------------|
| 02:00 | ✅ Incr/Full | - | - | - |
| 03:00 | - | ✅ Full | - | - |
| 03:30 | - | - | ✅ Full | - |
| 04:00 | - | - | - | ✅ Snapshot |

**Total espace backup (par jour)** :
- PostgreSQL: 50-100 GB (incrémental)
- Neo4j: 300 GB (compressé)
- InfluxDB: 100 GB (compressé)
- Elasticsearch: 50-100 GB (incrémental)
- **Total** : ~500-600 GB/jour

**Rétention 30 jours** : ~15-18 TB sur Ceph RGW

## Procédures de Restauration

### Restauration PostgreSQL (RTO: 2-3h)

```bash
# 1. Arrêter PostgreSQL
kubectl scale statefulset postgres --replicas=0

# 2. Restaurer avec pgBackRest
pgbackrest --stanza=openalex --type=time \
  --target="2024-01-15 14:30:00" restore

# 3. Redémarrer PostgreSQL
kubectl scale statefulset postgres --replicas=1

# 4. Vérifier
psql -c "SELECT COUNT(*) FROM works;"
```

### Restauration Neo4j (RTO: 1-2h)

```bash
# 1. Arrêter Neo4j
kubectl scale statefulset neo4j --replicas=0

# 2. Télécharger le backup
aws s3 cp s3://neo4j-backups/neo4j-backup-20240115.tar.gz .
tar -xzf neo4j-backup-20240115.tar.gz

# 3. Restaurer
neo4j-admin database restore --from-path=/backups/20240115

# 4. Redémarrer Neo4j
kubectl scale statefulset neo4j --replicas=1
```

### Restauration Complète (RTO: 4h)

1. Restaurer PostgreSQL (2-3h)
2. Restaurer Neo4j en parallèle (1-2h)
3. Restaurer InfluxDB en parallèle (30min)
4. Restaurer Elasticsearch en parallèle (1h)
5. Reconstruire Redis cache (automatique)

**Total** : ~4h (parallélisation)

## Tests de Restauration

```yaml
Fréquence: Mensuel (premier dimanche du mois)
Environnement: Cluster de test dédié
Procédure:
  1. Restaurer tous les backups sur cluster test
  2. Vérifier l'intégrité des données
  3. Tester les requêtes API
  4. Mesurer les temps de restauration (RTO)
  5. Documenter les anomalies
```

## Automatisation avec Kubernetes CronJobs

```yaml
# Example: CronJob PostgreSQL Backup
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
spec:
  schedule: "0 2 * * *"  # Tous les jours à 2h00
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: pgbackrest
            image: pgbackrest/pgbackrest:latest
            command: ["/bin/sh", "-c"]
            args:
              - pgbackrest --stanza=openalex --type=incr backup
            env:
              - name: PGBACKREST_REPO1_S3_ENDPOINT
                value: rook-ceph-rgw.rook-ceph.svc
          restartPolicy: OnFailure
```

## Prochaines Étapes

1. Implémenter les CronJobs Kubernetes pour chaque base
2. Configurer Ceph RGW et créer les buckets S3
3. Tester la procédure complète de backup/restore
4. Automatiser les tests de restauration mensuels
5. Documenter les procédures d'urgence

## Références

- [Configuration Rook/Ceph](./rook-ceph.md)
- [Stratégie de stockage globale](./strategy.md)
- [Plan de reprise après sinistre](../09-operations/disaster-recovery.md)

---

**Statut** : 📝 Brouillon - À compléter avec CronJobs, scripts de restauration, et runbook

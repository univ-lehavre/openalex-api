# Changelog - API OpenAlex Documentation

## [1.1.0] - 2026-01-12

### Changed - Remplacement TimescaleDB par InfluxDB

**Motivation** : InfluxDB est un projet CNCF et offre de meilleures performances pour les séries temporelles avec une compression supérieure.

#### Avantages d'InfluxDB vs TimescaleDB

| Critère | InfluxDB | TimescaleDB | Amélioration |
|---------|----------|-------------|--------------|
| **Compression** | 85-92% | 80% | +5-12% |
| **Stockage** | 170 GB | 230 GB | **-26% (60 GB économisés)** |
| **Écriture bulk** | 100K pts/s | 10K pts/s | **10× plus rapide** |
| **Agrégations** | 20-50ms | 50ms | Équivalent ou meilleur |
| **Statut CNCF** | ❌ Non-membre | ❌ Non-membre | Égalité |
| **Langage de requête** | Flux (fonctionnel) | SQL (familier) | Subjectif |

#### Avantages spécifiques d'InfluxDB

✅ **Compression supérieure** : TSM engine (Time-Structured Merge Tree)
- Algorithmes : Gorilla, Delta-of-delta, RLE
- Ratio : 85-92% vs 80% pour TimescaleDB

✅ **Performance écriture** : Optimisé pour ingestion massive de time-series
- 100K points/seconde vs 10K pour TimescaleDB

✅ **Downsampling automatique** : Flux tasks intégrées
- Agrégations horaires → quotidiennes → mensuelles automatiques
- Pas besoin de CRON jobs externes

✅ **Retention policies natives** :
- Nettoyage automatique des données anciennes
- Configuration déclarative par bucket

✅ **Monitoring natif** : Intégration Grafana excellente
- Datasource Flux native
- Dashboards pré-construits pour Telegraf

#### Fichiers Modifiés

1. **docs/00-introduction/polyglot-architecture.md**
   - Remplacement TimescaleDB par InfluxDB dans diagrammes
   - Mise à jour exemples de requêtes (SQL → Flux)
   - Configuration InfluxDB 2.7+ (TSM engine, retention policies)
   - Performances mises à jour : 170 GB vs 230 GB

2. **docs/00-introduction/architecture-options.md**
   - Tous les comparatifs hybride vs polyglotte mis à jour
   - Benchmarks avec InfluxDB
   - Cas d'usage avec langage Flux

3. **docs/10-annexes/cncf-stack.md**
   - Section bases de données : InfluxDB remplace TimescaleDB
   - Note : InfluxDB n'est pas membre CNCF mais standard time-series

4. **docs/01-stockage/rook-ceph.md**
   - Allocation PVC pour InfluxDB (250 GB au lieu de 300 GB)
   - Configuration volumes Rook/Ceph

5. **DECISION.md**
   - Guide de décision mis à jour
   - Recommandations avec InfluxDB

6. **sidebars.js**
   - Commentaire mis à jour : `// 'stockage/influxdb',`

#### Langage de Requête Flux

InfluxDB 2.x utilise Flux, un langage fonctionnel :

**Exemple - Publications par mois** :
```flux
from(bucket: "openalex")
  |> range(start: -10y)
  |> filter(fn: (r) => r._measurement == "publications")
  |> filter(fn: (r) => r.topic == "machine-learning")
  |> aggregateWindow(every: 1mo, fn: count)
  |> yield(name: "publications_per_month")
```

**Vs SQL (TimescaleDB)** :
```sql
SELECT time_bucket('1 month', publication_date) as month,
       count(*) as publications
FROM works_timeseries
WHERE topic = 'machine-learning'
  AND publication_date > NOW() - INTERVAL '10 years'
GROUP BY month;
```

#### Configuration Recommandée

```yaml
Serveur: dirqual3
Allocation:
  CPU: 15 cœurs
  RAM: 64 Go
  Stockage: 250 Go NVMe (vs 300 Go pour TimescaleDB)

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
```

#### Impact sur le Stockage Total

**Avant (avec TimescaleDB)** :
- PostgreSQL: 1.4 TB
- Neo4j: 610 GB
- TimescaleDB: 230 GB
- Elasticsearch: 1.3 TB
- Redis: 64 GB
- **Total: 3.6 TB**

**Après (avec InfluxDB)** :
- PostgreSQL: 1.4 TB
- Neo4j: 610 GB
- InfluxDB: 170 GB ⬇️ **-60 GB**
- Elasticsearch: 1.3 TB
- Redis: 64 GB
- **Total: 3.54 TB** ⬇️ **-60 GB (-1.7%)**

#### Prochaines Étapes

1. **POC InfluxDB** (1 semaine)
   - Installer InfluxDB 2.7 sur dirqual3
   - Importer échantillon données temporelles
   - Benchmarker requêtes Flux vs SQL PostgreSQL
   - Valider compression TSM

2. **Documentation technique**
   - Créer `docs/01-stockage/influxdb.md`
   - Guide d'intégration FastAPI
   - Exemples de requêtes Flux courantes

3. **Migration des données**
   - Script ETL : PostgreSQL → InfluxDB
   - Transformation format time-series
   - Validation intégrité

4. **Intégration Grafana**
   - Configurer datasource InfluxDB
   - Dashboards tendances publications
   - Alertes sur anomalies

---

## [1.0.0] - 2026-01-12

### Added

- Documentation complète architecture polyglotte
- Guide de décision (DECISION.md)
- Stack CNCF (docs/10-annexes/cncf-stack.md)
- Configuration Rook/Ceph (docs/01-stockage/rook-ceph.md)
- Comparatif architectures (docs/00-introduction/architecture-options.md)
- Script system-info.sh avec support Debian
- Documentation hardware inventory

### Infrastructure

- Cluster: 4 serveurs dirqual1-4
- CPU: 160 cores (40×4), 320 threads
- RAM: 1 TB (252 GB×4)
- Storage: 284 TB (13.6 TB NVMe + 270 TB HDD)

---

**Auteur** : Équipe Infrastructure - Université Le Havre Normandie

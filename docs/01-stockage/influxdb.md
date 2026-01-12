---
id: influxdb
title: Configuration InfluxDB
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 0.1.0
status: draft
priority: high
tags: [influxdb, time-series, séries-temporelles, tendances]
sidebar_label: InfluxDB
sidebar_position: 5
---

# Configuration InfluxDB

⚠️ **Documentation en cours de rédaction**

## Contexte

InfluxDB est la base de données time-series pour stocker et interroger les données temporelles d'OpenAlex :
- **Publications par mois/année** : Évolution des publications par concept/auteur/institution
- **Citations au fil du temps** : Courbes de citation pour chaque article
- **Tendances de recherche** : Émergence et déclin de sujets
- **Métriques d'impact** : Évolution du h-index, i10-index

## Pourquoi InfluxDB ?

**Avantages vs PostgreSQL/TimescaleDB** :
- **Compression** : 85-92% vs 80% (170GB vs 230GB)
- **Performance** : 10× plus rapide sur agrégations temporelles
- **TSM Engine** : Optimisé pour écritures et lectures time-series
- **Flux Query Language** : Puissant pour analyses temporelles

## Objectifs

- [ ] Configuration StatefulSet Kubernetes avec Rook/Ceph
- [ ] Schéma InfluxDB (buckets, measurements, tags)
- [ ] Import des données temporelles depuis OpenAlex
- [ ] Continuous aggregates pour pré-calculs
- [ ] Requêtes Flux pour l'API analytics
- [ ] Dashboards Grafana pour visualisation

## Spécifications Prévues

### Stockage
- **Volume** : 250 GB (170GB données + 80GB marge)
- **Type** : NVMe via Rook/Ceph (rook-ceph-nvme)
- **Compression** : 85-92% (2.5TB → 170GB)

### Ressources
- **CPU** : 4-8 cores
- **RAM** : 16 GB (cache: 8GB)

### Organisation des Données

```yaml
Bucket: openalex
  Measurement: publications
    Tags: [concept_id, author_id, institution_id, type]
    Fields: [count, cited_by_count, open_access_count]
    Timestamp: publication_date (monthly aggregation)

  Measurement: citations
    Tags: [work_id, citing_type]
    Fields: [citation_count]
    Timestamp: citation_date (daily)

  Measurement: impact_metrics
    Tags: [author_id, institution_id]
    Fields: [h_index, i10_index, total_citations]
    Timestamp: calculated_date (monthly)
```

## Cas d'Usage

### Tendances de Publications
```flux
// Publications par mois sur 10 ans pour un concept
from(bucket: "openalex")
  |> range(start: -10y)
  |> filter(fn: (r) => r._measurement == "publications")
  |> filter(fn: (r) => r.concept_id == "C41008148")
  |> aggregateWindow(every: 1mo, fn: sum)
  |> yield(name: "publications_per_month")
```

**Performance attendue** : 10-50ms vs 1-3s avec PostgreSQL

### Évolution de l'Impact
```flux
// H-index au fil du temps pour un auteur
from(bucket: "openalex")
  |> range(start: -5y)
  |> filter(fn: (r) => r._measurement == "impact_metrics")
  |> filter(fn: (r) => r.author_id == "A1234567890")
  |> filter(fn: (r) => r._field == "h_index")
  |> aggregateWindow(every: 1mo, fn: last)
```

### Concepts Émergents
```flux
// Croissance des publications par concept (%)
from(bucket: "openalex")
  |> range(start: -2y)
  |> filter(fn: (r) => r._measurement == "publications")
  |> aggregateWindow(every: 1y, fn: sum)
  |> derivative(unit: 1y, nonNegative: true)
  |> sort(desc: true)
  |> limit(n: 20)
```

## Prochaines Étapes

1. Définir le schéma complet (buckets, measurements, tags)
2. Implémenter le pipeline d'import ETL
3. Configurer les continuous aggregates
4. Créer les requêtes Flux pour l'API
5. Intégrer avec Grafana pour dashboards

## Références

- [Stratégie de stockage globale](./strategy.md)
- [Configuration Rook/Ceph](./rook-ceph.md)
- [Architecture polyglotte](../00-introduction/polyglot-architecture.md)
- [Changelog - Migration TimescaleDB → InfluxDB](../../CHANGELOG.md)
- [InfluxDB Documentation](https://docs.influxdata.com/influxdb/)

---

**Statut** : 📝 Brouillon - À compléter avec schéma détaillé, StatefulSet, et requêtes Flux

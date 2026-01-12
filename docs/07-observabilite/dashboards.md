---
id: dashboards
title: Dashboards Grafana
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 0.1.0
status: draft
priority: medium
tags: [grafana, dashboards, visualisation]
sidebar_label: Dashboards
sidebar_position: 2
---

# Dashboards Grafana

⚠️ **Documentation en cours de rédaction**

## Dashboards Prévus

### 1. Cluster Kubernetes Overview
- Nœuds CPU/RAM/Disk
- Pods running/pending/failed
- Network I/O
- PVC usage

### 2. Bases de Données Performance
- PostgreSQL: Queries/s, cache hit ratio, connections
- Neo4j: Query latency, heap usage, page cache
- InfluxDB: Write rate, compaction time
- Elasticsearch: Indexing rate, search latency, JVM heap

### 3. API Performance
- Request rate par endpoint
- Response time (P50/P95/P99)
- Error rate breakdown
- Cache hit ratio

### 4. ETL Pipeline
- Job status (success/failed)
- Processing time
- Records processed
- Data quality metrics

## Prochaines Étapes

- [ ] Créer dashboards JSON pour Grafana
- [ ] Configurer variables et filters
- [ ] Ajouter annotations pour deployments

## Références

- [Stack Monitoring](./monitoring-stack.md)
- [Métriques de succès](../00-introduction/success-metrics.md)

---

**Statut** : 📝 Brouillon - À compléter avec dashboards JSON et captures d'écran

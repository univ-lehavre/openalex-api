---
id: cluster-architecture
title: Architecture du Cluster Kubernetes
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 0.1.0
status: draft
priority: high
tags: [kubernetes, architecture, cluster]
sidebar_label: Architecture Cluster
sidebar_position: 1
---

# Architecture du Cluster Kubernetes

⚠️ **Documentation en cours de rédaction**

## Contexte

Le cluster Kubernetes OpenAlex est déployé sur 4 serveurs dirqual1-4 avec Rook/Ceph pour le stockage distribué.

## Topologie

```text
┌──────────────────────────────────────────────────────┐
│           Cluster Kubernetes (4 nœuds)               │
├──────────────────────────────────────────────────────┤
│                                                      │
│  dirqual1: Control Plane + Worker                   │
│    - PostgreSQL Primary                              │
│    - Neo4j                                           │
│    - Redis (master)                                  │
│                                                      │
│  dirqual2: Worker                                    │
│    - InfluxDB                                        │
│    - Elasticsearch node 1                            │
│    - Redis (replica)                                 │
│                                                      │
│  dirqual3: Worker                                    │
│    - Elasticsearch node 2                            │
│    - FastAPI (replicas 3-4)                          │
│                                                      │
│  dirqual4: Worker                                    │
│    - Elasticsearch node 3                            │
│    - Airflow (ETL)                                   │
│                                                      │
└──────────────────────────────────────────────────────┘
```

## Namespaces

- `openalex` : Bases de données et API
- `rook-ceph` : Stockage Ceph
- `monitoring` : Prometheus, Grafana, Loki
- `etl` : Airflow et jobs ETL

## Prochaines Étapes

- [ ] Documenter la configuration kubeadm
- [ ] Définir les resource limits par pod
- [ ] Configurer les affinités et anti-affinités
- [ ] Planifier la haute disponibilité

## Références

- [Inventaire matériel](./hardware-inventory.md)
- [Configuration Rook/Ceph](../01-stockage/rook-ceph.md)
- [Stack CNCF](../10-annexes/cncf-stack.md)

---

**Statut** : 📝 Brouillon - À compléter avec manifests Kubernetes

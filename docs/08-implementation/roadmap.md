---
id: roadmap
title: Roadmap d'Implémentation
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 0.1.0
status: draft
priority: high
tags: [roadmap, planification, phases]
sidebar_label: Roadmap
sidebar_position: 1
---

# Roadmap d'Implémentation

⚠️ **Documentation en cours de rédaction**

## Vue d'Ensemble

L'implémentation de l'API OpenAlex suit une approche progressive en 6 phases sur 5-6 mois.

## Phase 1 : Fondations (Semaines 1-4)

### Objectifs
- Cluster Kubernetes opérationnel
- Rook/Ceph déployé et testé
- Monitoring de base (Prometheus/Grafana)

### Livrables
- [ ] Cluster K8s 4 nœuds
- [ ] Rook/Ceph pools NVMe et HDD
- [ ] Stack monitoring de base
- [ ] Documentation opérationnelle

## Phase 2 : PostgreSQL + Elasticsearch (Semaines 5-8)

### Objectifs
- PostgreSQL avec schéma complet
- Elasticsearch avec mappings
- Import de 10% des données (test)

### Livrables
- [ ] PostgreSQL StatefulSet + partitionnement
- [ ] Elasticsearch cluster 3 nœuds
- [ ] Pipeline ETL de test
- [ ] 25M articles importés

## Phase 3 : API REST Basique (Semaines 9-14)

### Objectifs
- API FastAPI fonctionnelle
- Endpoints CRUD pour tous les types
- Redis cache intégré
- Tests et documentation

### Livrables
- [ ] FastAPI avec tous les endpoints
- [ ] Documentation OpenAPI
- [ ] Tests d'intégration
- [ ] API accessible publiquement

## Phase 4 : Neo4j + Graphes (Semaines 15-18)

### Objectifs
- Neo4j avec 2B relations de citations
- Endpoints API pour requêtes de graphes
- Benchmarks de performance

### Livrables
- [ ] Neo4j StatefulSet
- [ ] Import graphe complet
- [ ] Endpoints citations/coauthors
- [ ] Comparaison perf vs PostgreSQL

## Phase 5 : InfluxDB + Analytics (Semaines 19-22)

### Objectifs
- InfluxDB avec données temporelles
- Endpoints analytics et tendances
- Dashboards Grafana

### Livrables
- [ ] InfluxDB StatefulSet
- [ ] Import time-series data
- [ ] Endpoints trends
- [ ] Dashboards analytics

## Phase 6 : Production (Semaines 23-24)

### Objectifs
- Import complet des données (100%)
- Tests de charge et optimisation
- Documentation complète
- Formation équipe

### Livrables
- [ ] 250M articles + 2B relations
- [ ] Tests de charge validés
- [ ] Runbook opérationnel
- [ ] API en production

## Timeline Visuelle

```text
Mois 1      Mois 2      Mois 3      Mois 4      Mois 5      Mois 6
├─────────┬─────────┬─────────┬─────────┬─────────┬─────────┤
│ Phase 1 │ Phase 2 │ Phase 3     │ Phase 4 │ Phase 5 │ P6  │
│  K8s +  │  PG +   │  API REST   │  Neo4j  │ InfluxDB│Prod │
│  Rook   │   ES    │  basique    │ Graphe  │Analytics│     │
└─────────┴─────────┴─────────────┴─────────┴─────────┴─────┘
```

## Prochaines Étapes

- [ ] Valider la roadmap avec l'équipe
- [ ] Affecter les ressources par phase
- [ ] Définir les critères de succès par phase
- [ ] Planifier les revues de phase

## Références

- [Phase 1: Fondations](./phase-1-foundations.md)
- [Architecture polyglotte](../00-introduction/polyglot-architecture.md)
- [Métriques de succès](../00-introduction/success-metrics.md)

---

**Statut** : 📝 Brouillon - À compléter avec planning détaillé et critères de validation

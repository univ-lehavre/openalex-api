---
id: monitoring-stack
title: Stack de Monitoring - Prometheus/Grafana/Loki
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 0.1.0
status: draft
priority: high
tags: [monitoring, prometheus, grafana, loki, observabilité]
sidebar_label: Stack Monitoring
sidebar_position: 1
---

# Stack de Monitoring - Prometheus/Grafana/Loki

⚠️ **Documentation en cours de rédaction**

## Contexte

La stack d'observabilité CNCF (Prometheus + Grafana + Loki) fournit une visibilité complète sur l'infrastructure et les applications OpenAlex.

## Composants

### Prometheus
- **Rôle** : Collecte et stockage des métriques
- **Cibles** : Kubernetes nodes, pods, bases de données, API
- **Rétention** : 30 jours (métriques haute résolution)

### Grafana
- **Rôle** : Visualisation et dashboards
- **Dashboards** : Cluster K8s, bases de données, API, ETL
- **Alerting** : Notifications Slack/Email

### Loki
- **Rôle** : Agrégation et indexation des logs
- **Sources** : Tous les pods Kubernetes
- **Rétention** : 14 jours

## Métriques Clés

### Infrastructure
- CPU/RAM/Disk par nœud
- IOPS et latence Ceph
- Network throughput

### Bases de Données
- Query latency (P50, P95, P99)
- Connections pool usage
- Cache hit ratio

### API
- Request rate (req/s)
- Response time par endpoint
- Error rate (4xx, 5xx)

## Prochaines Étapes

- [ ] Déployer Prometheus Operator sur Kubernetes
- [ ] Configurer ServiceMonitors pour toutes les bases
- [ ] Créer dashboards Grafana
- [ ] Configurer rules d'alerting
- [ ] Déployer Loki et Promtail

## Références

- [Stack CNCF](../10-annexes/cncf-stack.md)
- [Métriques clés](./key-metrics.md)

---

**Statut** : 📝 Brouillon - À compléter avec configurations Prometheus et Grafana

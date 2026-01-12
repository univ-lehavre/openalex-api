---
id: alerting
title: Règles d'Alerting
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 0.1.0
status: draft
priority: high
tags: [alerting, prometheus, incidents]
sidebar_label: Alerting
sidebar_position: 3
---

# Règles d'Alerting

⚠️ **Documentation en cours de rédaction**

## Règles Critiques (P0)

### Infrastructure
- **NodeDown** : Nœud Kubernetes injoignable > 5min
- **DiskFull** : Espace disque < 10%
- **MemoryPressure** : RAM usage > 90%

### Bases de Données
- **DatabaseDown** : Base de données injoignable > 2min
- **HighQueryLatency** : P95 > 2s pendant 10min
- **LowCacheHitRate** : Cache hit rate < 70%

### API
- **HighErrorRate** : Error rate > 5% pendant 5min
- **APIDown** : API injoignable > 2min

## Canaux de Notification

- **Slack** : #openalex-alerts
- **Email** : ops-team@univ-lehavre.fr
- **PagerDuty** : Pour alertes P0

## Prochaines Étapes

- [ ] Définir toutes les règles d'alerting Prometheus
- [ ] Configurer Alertmanager
- [ ] Intégrer Slack et Email
- [ ] Documenter procédures d'escalade

## Références

- [Stack Monitoring](./monitoring-stack.md)
- [Runbook opérationnel](../09-operations/runbook.md)

---

**Statut** : 📝 Brouillon - À compléter avec règles Prometheus et runbook

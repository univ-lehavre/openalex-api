---
id: success-metrics
title: Métriques de Succès
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 1.0.0
status: draft
priority: high
tags: [métriques, kpi, performance, qualité, sla]
categories: [stratégie, performance]
dependencies: [00-introduction/overview.md]
sidebar_label: Métriques de Succès
sidebar_position: 3
---

# Métriques de Succès du Projet

## Vue d'Ensemble

Ce document définit les **indicateurs clés de performance (KPI)** et les **critères de succès** pour l'API OpenAlex. Ces métriques serviront à évaluer la réussite du projet et à guider les décisions d'optimisation.

## Catégories de Métriques

1. **Performance** - Temps de réponse et débit
2. **Disponibilité** - Uptime et résilience
3. **Qualité des Données** - Intégrité et complétude
4. **Opérations** - Efficacité des processus
5. **Utilisation** - Adoption et satisfaction utilisateur

---

## 1. Métriques de Performance

### 1.1 Latence des Requêtes API

| Métrique | Objectif | Mesure | Critique |
|----------|----------|--------|----------|
| **P50 (médiane)** | < 200ms | 50% des requêtes | ⚠️ Moyen |
| **P95** | < 500ms | 95% des requêtes | 🔴 Élevé |
| **P99** | < 1000ms | 99% des requêtes | ⚠️ Moyen |
| **P99.9** | < 3000ms | 99,9% des requêtes | 🟢 Faible |

**Méthode de mesure :**
```
Prometheus: histogram_quantile(0.95, http_request_duration_seconds)
```

**Ventilation par type de requête :**
- Recherche plein texte : < 100ms (P95)
- Requêtes structurées : < 200ms (P95)
- Requêtes de graphes : < 500ms (P95)
- Analytics : < 1000ms (P95)

### 1.2 Débit (Throughput)

| Métrique | Objectif | Capacité | Critique |
|----------|----------|----------|----------|
| **Requêtes/seconde** | 100-500 req/s | Soutenu | 🔴 Élevé |
| **Concurrence max** | 500 utilisateurs | Simultanés | ⚠️ Moyen |
| **Pics de charge** | 1000 req/s | 30 secondes | 🟢 Faible |

**Test de charge :**
```bash
# Commande k6 pour test de charge
k6 run --vus 500 --duration 10m load-test.js
```

### 1.3 Performance des Bases de Données

**PostgreSQL :**
- Temps de réponse moyen : < 50ms (P95)
- Connexions actives : < 80% du pool
- Cache hit rate : > 95%
- Index scan ratio : > 99%

**Elasticsearch :**
- Search latency : < 50ms (P95)
- Indexing rate : > 10 000 docs/s
- JVM heap usage : < 75%
- Query cache hit rate : > 80%

**Redis :**
- Hit rate : > 80%
- Latency : < 1ms (P99)
- Memory usage : < 90%

---

## 2. Métriques de Disponibilité

### 2.1 Uptime

| Service | SLA | Downtime Annuel Max | Critique |
|---------|-----|---------------------|----------|
| **API** | 99,9% | 8,7 heures | 🔴 Élevé |
| **PostgreSQL** | 99,9% | 8,7 heures | 🔴 Élevé |
| **Elasticsearch** | 99,5% | 43,8 heures | ⚠️ Moyen |
| **Redis** | 99,5% | 43,8 heures | 🟢 Faible |

**Calcul :**
```
Uptime % = (Total Time - Downtime) / Total Time × 100

99,9% = 525 960 min - 526 min / 525 960 min = 8,76 heures/an
```

### 2.2 Fenêtres de Maintenance

| Type | Fréquence | Durée Max | Impact |
|------|-----------|-----------|--------|
| **Mises à jour mensuelles** | 1x/mois | < 1 minute | Downtime planifié |
| **Maintenance PostgreSQL** | Trimestrielle | < 30 minutes | Hors heures |
| **Mise à jour Kubernetes** | Trimestrielle | 0 (rolling) | Aucun |

### 2.3 Recovery Time Objective (RTO)

| Scénario | RTO | Procédure |
|----------|-----|-----------|
| **Crash d'un pod API** | < 30s | Auto-restart K8s |
| **Crash PostgreSQL primary** | < 5min | Failover vers replica |
| **Corruption Elasticsearch** | < 30min | Restore depuis snapshot |
| **Perte complète cluster** | < 2h | Restore depuis backups |

### 2.4 Recovery Point Objective (RPO)

| Donnée | RPO | Mécanisme |
|--------|-----|-----------|
| **PostgreSQL data** | < 6h | WAL archiving + backups |
| **Elasticsearch index** | < 24h | Snapshots quotidiens |
| **Cache Redis** | N/A | Données volatiles |

---

## 3. Métriques de Qualité des Données

### 3.1 Intégrité

| Métrique | Objectif | Validation | Critique |
|----------|----------|------------|----------|
| **Entités importées** | 100% | Vs snapshot OpenAlex | 🔴 Élevé |
| **Relations valides** | 100% | Contraintes FK | 🔴 Élevé |
| **Erreurs de validation** | < 0,01% | Pipeline ETL | ⚠️ Moyen |
| **Doublons** | 0 | Contraintes UNIQUE | 🔴 Élevé |

### 3.2 Complétude

| Entité | Champs Requis | Complétude | Critique |
|--------|---------------|------------|----------|
| **Works** | id, title, year | 100% | 🔴 Élevé |
| **Authors** | id, display_name | 100% | 🔴 Élevé |
| **Abstracts** | abstract_text | > 60% | 🟢 Faible |
| **Citations** | citing_id, cited_id | 100% | 🔴 Élevé |

### 3.3 Fraîcheur des Données

| Métrique | Objectif | Mesure |
|----------|----------|--------|
| **Âge des données** | < 31 jours | Dernier snapshot |
| **Succès de sync** | 100% | Pipeline ETL |
| **Détection de drift** | < 1% | Validation post-import |

**Vérification :**
```sql
-- Âge des données les plus récentes
SELECT MAX(updated_date) as last_update,
       NOW() - MAX(updated_date) as age
FROM works;
```

---

## 4. Métriques Opérationnelles

### 4.1 Pipeline ETL

| Métrique | Objectif | Mesure | Critique |
|----------|----------|--------|----------|
| **Durée totale** | < 48h | Airflow DAG | ⚠️ Moyen |
| **Taux de réussite** | 100% | Tasks success | 🔴 Élevé |
| **Interventions manuelles** | < 2/mois | Runbook | ⚠️ Moyen |
| **Rollback nécessaires** | 0 | Validations | 🔴 Élevé |

### 4.2 Sauvegardes

| Métrique | Objectif | Fréquence | Critique |
|----------|----------|-----------|----------|
| **Succès backups PostgreSQL** | > 99,5% | Quotidien | 🔴 Élevé |
| **Succès snapshots ES** | > 99% | Quotidien | ⚠️ Moyen |
| **Tests de restore** | 100% | Trimestriel | 🔴 Élevé |
| **Durée de backup** | < 4h | Incrémental | 🟢 Faible |

**Validation :**
```bash
# Test de restore trimestriel obligatoire
kubectl exec postgresql-restore-test -- pgbackrest restore --stanza=main
```

### 4.3 Incidents

| Métrique | Objectif | Mesure |
|----------|----------|--------|
| **MTBF** (Mean Time Between Failures) | > 720h | 30 jours |
| **MTTR** (Mean Time To Repair) | < 2h | Temps de résolution |
| **Incidents critiques** | < 2/mois | Severity 1 |
| **Post-mortems** | 100% | Incidents S1/S2 |

---

## 5. Métriques d'Utilisation

### 5.1 Adoption

| Métrique | Objectif Mois 3 | Objectif Mois 12 | Mesure |
|----------|----------------|------------------|--------|
| **Utilisateurs actifs** | 50 | 500 | API keys actives |
| **Requêtes/jour** | 50 000 | 500 000 | Logs API |
| **Départements utilisateurs** | 5 | 20 | Registration data |

### 5.2 Patterns d'Usage

| Pattern de Requête | % Attendu | Optimisation |
|-------------------|-----------|--------------|
| **Recherche plein texte** | 40% | Cache 2min |
| **Filtres structurés** | 35% | Cache 5min |
| **Requêtes de graphes** | 15% | Cache 15min |
| **Analytics** | 10% | Cache 1h |

### 5.3 Satisfaction Utilisateur

| Métrique | Objectif | Méthode | Fréquence |
|----------|----------|---------|-----------|
| **NPS** (Net Promoter Score) | > 50 | Sondage | Semestriel |
| **CSAT** (Customer Satisfaction) | > 4/5 | Sondage | Trimestriel |
| **Taux d'erreur utilisateur** | < 5% | Logs 4xx | Continu |
| **Tickets support** | < 10/mois | Helpdesk | Mensuel |

---

## 6. Métriques de Coût

### 6.1 Infrastructure

| Composant | Budget Mensuel | Réel | Écart |
|-----------|----------------|------|-------|
| **Compute** | 5 000 € | À mesurer | - |
| **Storage** | 2 500 € | À mesurer | - |
| **Network** | 1 000 € | À mesurer | - |
| **Monitoring** | 500 € | À mesurer | - |
| **Total** | **9 000 €** | **À mesurer** | **< 10%** |

### 6.2 Coût par Requête

| Métrique | Calcul | Objectif |
|----------|--------|----------|
| **Coût/1M requêtes** | Budget mensuel / Requêtes totales | < 2 € |
| **Coût/utilisateur/mois** | Budget mensuel / Utilisateurs actifs | < 20 € |

---

## 7. Dashboards et Alertes

### 7.1 Dashboard Principal (Grafana)

**Panneaux obligatoires :**
1. Latence P95 par endpoint (ligne)
2. Taux de requêtes par seconde (graphe)
3. Taux d'erreur (5xx) (jauge)
4. Disponibilité services (stat)
5. Utilisation CPU/RAM (heatmap)
6. Cache hit rate (jauge)

### 7.2 Alertes Critiques

| Alerte | Condition | Seuil | Action |
|--------|-----------|-------|--------|
| **API Down** | http_up == 0 | 1min | PagerDuty |
| **Latence P95 élevée** | > 1s | 5min | Slack + Email |
| **Taux d'erreur élevé** | > 5% | 5min | PagerDuty |
| **DB Down** | pg_up == 0 | 1min | PagerDuty |
| **Disque presque plein** | < 10% libre | 10min | Email |

### 7.3 Alertes d'Avertissement

| Alerte | Condition | Seuil | Action |
|--------|-----------|-------|--------|
| **Cache low hit rate** | < 70% | 15min | Slack |
| **Slow queries** | > 1s | 10 occurrences | Email |
| **High memory** | > 85% | 10min | Slack |
| **Backup failed** | Job failed | 1 échec | Email |

---

## 8. Revue des Métriques

### 8.1 Cadence de Revue

| Fréquence | Participants | Objectif |
|-----------|-------------|----------|
| **Quotidien** | Équipe ops | Monitoring santé système |
| **Hebdomadaire** | Équipe tech | Revue performance, incidents |
| **Mensuel** | Management | Revue KPIs, budget, roadmap |
| **Trimestriel** | Parties prenantes | Business review, ajustements |

### 8.2 Rapports Automatiques

**Rapport hebdomadaire (email) :**
- Résumé uptime et incidents
- Top 10 requêtes les plus lentes
- Évolution du nombre d'utilisateurs
- Anomalies détectées

**Rapport mensuel (document) :**
- Toutes les métriques KPI
- Comparaison vs objectifs
- Tendances et prédictions
- Actions d'amélioration

---

## 9. Critères de Réussite par Phase

### Phase 1 : Fondations (Semaines 1-3)

✅ **Critères de passage :**
- Cluster Kubernetes opérationnel (10 nœuds)
- Prometheus/Grafana déployé et accessible
- 3 dashboards créés (cluster, nodes, pods)
- Pipeline CI/CD fonctionnel

### Phase 2 : Base de Données (Semaines 4-7)

✅ **Critères de passage :**
- PostgreSQL + Elasticsearch déployés
- Schémas créés et validés
- 1% du dataset chargé avec succès
- Backups automatiques configurés
- Latence requêtes tests < 100ms

### Phase 3 : API (Semaines 8-11)

✅ **Critères de passage :**
- API fonctionnelle (tous endpoints)
- 4 patterns de requêtes implémentés
- Tests de charge : 100 req/s soutenus
- Cache hit rate > 50%
- Documentation API complète

### Phase 4 : Pipeline ETL (Semaines 12-15)

✅ **Critères de passage :**
- Dataset complet chargé (3 To)
- Pipeline ETL automatisé (Airflow)
- Durée totale < 48h
- Validation 100% des données
- Zero-downtime deployment testé

### Phase 5 : Production (Semaines 16-18)

✅ **Critères de passage :**
- Tests de charge : 500 req/s soutenus
- Latence P95 < 500ms
- Haute disponibilité testée (failover)
- Audit de sécurité passé
- Runbook opérationnel complet

### Phase 6 : Lancement (Semaines 19-20)

✅ **Critères de passage :**
- 50 utilisateurs beta satisfaits (CSAT > 4/5)
- Uptime > 99,5% sur 2 semaines
- Aucun incident critique
- Support utilisateur en place
- Lancement public réussi

---

## 10. Amélioration Continue

### 10.1 Processus d'Optimisation

**Cycle mensuel :**
1. **Analyse** des métriques de performance
2. **Identification** des goulots d'étranglement
3. **Priorisation** des optimisations
4. **Implémentation** des améliorations
5. **Validation** de l'impact

### 10.2 Objectifs Évolutifs

| Trimestre | Objectif Performance | Objectif Utilisation |
|-----------|---------------------|---------------------|
| **Q1 2026** | P95 < 500ms | 50 utilisateurs |
| **Q2 2026** | P95 < 400ms | 200 utilisateurs |
| **Q3 2026** | P95 < 300ms | 500 utilisateurs |
| **Q4 2026** | P95 < 250ms | 1000 utilisateurs |

### 10.3 Innovation

**Expérimentations à mener :**
- Mise en cache prédictif (ML)
- Compression des réponses (gzip, brotli)
- GraphQL en complément de REST
- Real-time search avec WebSockets

---

## Conclusion

Ces métriques constituent le **cadre de mesure du succès** de l'API OpenAlex. Elles doivent être :
- ✅ **Mesurées en continu** via Prometheus/Grafana
- ✅ **Revues régulièrement** par l'équipe
- ✅ **Ajustées** selon l'évolution des besoins
- ✅ **Communiquées** aux parties prenantes

**Prochaines étapes :**
- [Configuration du monitoring](../07-observabilite/monitoring-stack.md)
- [Dashboards Grafana](../07-observabilite/dashboards.md)
- [Règles d'alerting](../07-observabilite/alerting.md)

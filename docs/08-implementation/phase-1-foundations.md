---
id: phase-1-foundations
title: Phase 1 - Fondations Infrastructure
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 0.1.0
status: draft
priority: high
tags: [implémentation, kubernetes, infrastructure, phase-1]
sidebar_label: Phase 1 - Fondations
sidebar_position: 2
---

# Phase 1 - Fondations Infrastructure

⚠️ **Documentation en cours de rédaction**

## Objectifs de la Phase 1

Établir les fondations infrastructure nécessaires pour déployer les bases de données et l'API OpenAlex.

**Durée** : 4 semaines
**Équipe** : 1 personne

## Semaine 1 : Cluster Kubernetes

### Tâches
- [ ] Installer Kubernetes sur les 4 serveurs dirqual1-4
- [ ] Configurer kubeadm avec control plane sur dirqual1
- [ ] Vérifier la connectivité réseau entre nœuds
- [ ] Tester le déploiement d'un pod de test
- [ ] Configurer kubectl en local

### Critères de Succès
- Cluster 4 nœuds opérationnel
- Tous les nœuds en état "Ready"
- Capacité à déployer des pods sur tous les nœuds

### Commandes
```bash
# Installation K8s (sur chaque nœud)
sudo apt-get update
sudo apt-get install -y kubeadm kubelet kubectl

# Init cluster (dirqual1)
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Join workers (dirqual2-4)
sudo kubeadm join <master-ip>:6443 --token <token>
```

## Semaine 2 : Rook/Ceph

### Tâches
- [ ] Déployer Rook Operator
- [ ] Créer CephCluster avec 4 OSD
- [ ] Configurer pools NVMe et HDD
- [ ] Créer StorageClasses
- [ ] Tester provisioning PVC

### Critères de Succès
- Ceph cluster healthy
- Pools NVMe (5.1TB) et HDD (270TB) créés
- PVC provisionné automatiquement

### Manifests
```yaml
# rook-operator.yaml
kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/deploy/examples/operator.yaml

# ceph-cluster.yaml
kubectl apply -f cluster.yaml
```

## Semaine 3 : Monitoring Stack

### Tâches
- [ ] Déployer Prometheus Operator
- [ ] Configurer Prometheus Server
- [ ] Déployer Grafana
- [ ] Importer dashboards Kubernetes
- [ ] Déployer Loki et Promtail

### Critères de Succès
- Prometheus collecte métriques cluster
- Grafana accessible via ingress
- Logs centralisés dans Loki

## Semaine 4 : Networking & Security

### Tâches
- [ ] Déployer Ingress Controller (Nginx)
- [ ] Configurer DNS interne
- [ ] Déployer cert-manager
- [ ] Configurer NetworkPolicies
- [ ] Tests de connectivité

### Critères de Succès
- Ingress fonctionnel avec certificats
- NetworkPolicies appliquées
- DNS interne résout les services

## Livrables de Phase 1

1. ✅ Cluster Kubernetes 4 nœuds opérationnel
2. ✅ Rook/Ceph avec pools NVMe/HDD
3. ✅ Stack monitoring (Prometheus/Grafana/Loki)
4. ✅ Networking et sécurité configurés
5. 📄 Documentation infrastructure complète

## Validation de Phase

### Tests à Réaliser
```bash
# 1. Vérifier état cluster
kubectl get nodes
kubectl get pods --all-namespaces

# 2. Vérifier Ceph
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status

# 3. Test PVC provisioning
kubectl apply -f test-pvc.yaml
kubectl get pvc

# 4. Test Prometheus
curl http://prometheus.monitoring.svc:9090/api/v1/query?query=up
```

### Critères de Passage à Phase 2
- [ ] Tous les nœuds healthy
- [ ] Ceph HEALTH_OK
- [ ] Prometheus collecte métriques
- [ ] PVC provisionné en < 1min

## Prochaines Étapes

Après validation de Phase 1 → [Phase 2: PostgreSQL + Elasticsearch](./phase-2-database.md)

## Références

- [Architecture cluster](../06-kubernetes/cluster-architecture.md)
- [Configuration Rook/Ceph](../01-stockage/rook-ceph.md)
- [Stack monitoring](../07-observabilite/monitoring-stack.md)
- [Roadmap complète](./roadmap.md)

---

**Statut** : 📝 Brouillon - À compléter avec scripts d'installation et checks automatisés

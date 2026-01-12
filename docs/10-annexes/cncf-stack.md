---
id: cncf-stack
title: Stack Technologique CNCF
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 1.0.0
status: draft
priority: high
tags: [cncf, cloud-native, kubernetes, stack-technologique]
categories: [architecture, infrastructure]
dependencies: [technology-stack.md]
sidebar_label: Stack CNCF
sidebar_position: 1
---

# Stack Technologique CNCF pour OpenAlex API

## Principe Directeur

Prioriser les projets **CNCF (Cloud Native Computing Foundation)** pour bénéficier de :
- ✅ Standards cloud-native éprouvés
- ✅ Écosystème mature et intégré
- ✅ Support communautaire large
- ✅ Évolutions coordonnées
- ✅ Sécurité et audits réguliers

**Référence** : [CNCF Landscape](https://landscape.cncf.io/)

---

## Orchestration et Runtime

### Kubernetes (Graduated) ⭐

**Statut CNCF** : Graduated (2018)
**Rôle** : Orchestration de conteneurs

```yaml
Version: 1.28+
Distribution: K3s ou Kubernetes standard
```

**Pourquoi** :
- Standard de facto pour orchestration
- Gestion déclarative des ressources
- Auto-scaling et auto-healing
- Support natif du stockage (CSI)

**Composants clés** :
- `kubelet` - Agent sur chaque nœud
- `kube-apiserver` - API centrale
- `kube-scheduler` - Placement des pods
- `etcd` - Stockage clé-valeur du state

---

## Stockage

### Rook (Graduated) ⭐

**Statut CNCF** : Graduated (2020)
**Rôle** : Orchestration de stockage (Ceph)

```yaml
Version: 1.13+
Backend: Ceph Reef (18.x)
```

**Pourquoi** :
- Intégration native Kubernetes
- Support RBD, CephFS, RGW (S3)
- Réplication automatique
- Snapshots et clones

**Alternatives CNCF** :
- ❌ **Longhorn** (Sandbox) - Moins mature pour grande échelle
- ❌ **OpenEBS** (Sandbox) - Complexité similaire, moins adopté

**Configuration recommandée** :
```yaml
storage:
  pools:
    - name: nvme-pool
      deviceClass: nvme
      replicated:
        size: 2
    - name: hdd-pool
      deviceClass: hdd
      replicated:
        size: 3
```

### Backup et Disaster Recovery

#### Velero (Graduated) ⭐

**Statut CNCF** : Graduated (2020)
**Rôle** : Backup et restore Kubernetes

```yaml
Version: 1.13+
Storage: Rook Ceph RGW (S3-compatible)
```

**Pourquoi** :
- Backup déclaratif (CRDs)
- Snapshots de PVC natifs
- Migration entre clusters
- Disaster recovery

**Stratégie** :
```yaml
# Backup quotidien namespace openalex
schedule: "0 2 * * *"
includedNamespaces:
  - openalex
  - rook-ceph
snapshotVolumes: true
ttl: 168h  # 7 jours
```

---

## Observabilité

### Monitoring

#### Prometheus (Graduated) ⭐

**Statut CNCF** : Graduated (2016)
**Rôle** : Métriques et alerting

```yaml
Version: 2.50+
Rétention: 15 jours (métriques brutes)
Storage: Rook Ceph NVMe
```

**Pourquoi** :
- Standard pour métriques cloud-native
- PromQL pour requêtes puissantes
- Intégration native Kubernetes
- Écosystème d'exporters immense

**Métriques clés** :
- `kube-state-metrics` - État des ressources K8s
- `node-exporter` - Métriques hardware
- `ceph-exporter` (Rook) - Métriques Ceph
- `postgres-exporter` - Métriques PostgreSQL
- `elasticsearch-exporter` - Métriques Elasticsearch

#### Thanos (Incubating)

**Statut CNCF** : Incubating (2019)
**Rôle** : Stockage long terme Prometheus

```yaml
Version: 0.34+
Storage: Rook Ceph RGW (S3)
Rétention: 2 ans
```

**Pourquoi** :
- Stockage illimité (objet storage)
- Agrégation multi-clusters
- Downsampling automatique
- Requêtes globales

**Architecture** :
```text
Prometheus → Thanos Sidecar → Thanos Store → S3 (Ceph RGW)
                                     ↓
                              Thanos Query ← Grafana
```

### Visualisation

#### Grafana (Non-CNCF mais standard de facto)

**Rôle** : Dashboards et visualisation

```yaml
Version: 10.3+
DataSources:
  - Prometheus
  - Thanos
  - Loki
```

**Pourquoi** :
- Standard industrie
- Intégration Prometheus native
- Dashboards as code (JSON)
- Alerting visuel

**Dashboards recommandés** :
- Kubernetes Cluster Monitoring
- Ceph Cluster Overview
- PostgreSQL Database
- Elasticsearch Cluster
- Node Exporter Full

### Logging

#### Loki (Graduated) ⭐

**Statut CNCF** : Graduated (2021)
**Rôle** : Agrégation de logs

```yaml
Version: 2.9+
Storage: Rook Ceph RGW (S3)
Rétention: 30 jours
```

**Pourquoi** :
- "Prometheus pour les logs"
- Indexation par labels (pas full-text)
- Compression efficace
- Requêtes LogQL similaires à PromQL

**Architecture** :
```text
Pods → Promtail (DaemonSet) → Loki → Ceph RGW (S3)
                                  ↓
                              Grafana
```

**Configuration** :
```yaml
# Promtail collecte logs de tous les pods
clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: kubernetes-pods
    kubernetes_sd_configs:
      - role: pod
```

### Tracing (Optionnel)

#### Jaeger (Graduated) ⭐

**Statut CNCF** : Graduated (2019)
**Rôle** : Distributed tracing

```yaml
Version: 1.54+
Storage: Elasticsearch ou Cassandra
```

**Pourquoi** :
- Tracer requêtes API multi-services
- Identifier bottlenecks
- Visualiser dépendances

**Usage** : Optionnel pour Phase 1-4, utile en Phase 5 pour debug avancé

---

## Réseau et Service Mesh

### Ingress Controller

#### Envoy (Graduated) ⭐

**Statut CNCF** : Graduated (2018)
**Rôle** : Proxy L7 et ingress

**Implémentations** :
- **Contour** (Graduated, 2021) - Simple, lightweight
- **Istio** (Graduated, 2023) - Service mesh complet

**Recommandation** : **Contour** pour simplicité

```yaml
apiVersion: projectcontour.io/v1
kind: HTTPProxy
metadata:
  name: openalex-api
  namespace: openalex
spec:
  virtualhost:
    fqdn: api.openalex.univ-lehavre.fr
  routes:
    - services:
        - name: fastapi
          port: 8000
      rateLimitPolicy:
        global:
          descriptors:
            - entries:
                - remoteAddress: {}
          rateLimit:
            requests: 100
            unit: second
```

**Pourquoi Contour** :
- Léger (vs Istio très complexe)
- Configuration déclarative (HTTPProxy CRD)
- Rate limiting natif
- TLS automatique (cert-manager)

### TLS et Certificats

#### cert-manager (Graduated) ⭐

**Statut CNCF** : Graduated (2020)
**Rôle** : Gestion automatique des certificats

```yaml
Version: 1.14+
Issuer: Let's Encrypt (ACME)
```

**Pourquoi** :
- Renouvellement automatique
- Support multi-issuer
- Intégration Contour/Ingress

**Configuration** :
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@univ-lehavre.fr
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: contour
```

### DNS et Service Discovery

#### CoreDNS (Graduated) ⭐

**Statut CNCF** : Graduated (2017)
**Rôle** : DNS interne Kubernetes

```yaml
Version: Inclus dans K8s
Plugin: kubernetes, forward, cache
```

**Pourquoi** :
- DNS natif Kubernetes
- Résolution service.namespace.svc.cluster.local
- Cache DNS efficace

---

## CI/CD et Déploiement

### GitOps

#### Flux (Graduated) ⭐

**Statut CNCF** : Graduated (2022)
**Rôle** : GitOps pour Kubernetes

```yaml
Version: 2.2+
Repository: Git (GitHub/GitLab)
```

**Pourquoi** :
- Déclaratif : Git = source de vérité
- Reconciliation automatique
- Drift detection
- Multi-tenancy

**Workflow** :
```text
Git Push → Flux détecte changement → Apply manifests K8s → Reconciliation
```

**Alternative CNCF** :
- **Argo CD** (Graduated, 2022) - UI plus riche, plus complexe

**Recommandation** : **Flux** pour simplicité et intégration Helm

### Build d'Images

#### BuildKit / Kaniko (Non-CNCF)

**Rôle** : Build d'images Docker sans daemon

**Recommandation** : **Kaniko** pour build in-cluster

```yaml
# Build FastAPI image dans K8s
apiVersion: batch/v1
kind: Job
metadata:
  name: fastapi-build
spec:
  template:
    spec:
      containers:
        - name: kaniko
          image: gcr.io/kaniko-project/executor:latest
          args:
            - --dockerfile=Dockerfile
            - --context=git://github.com/univ-lehavre/openalex-api
            - --destination=registry.local/fastapi:latest
```

### Registry

#### Harbor (Graduated) ⭐

**Statut CNCF** : Graduated (2018)
**Rôle** : Registry Docker privé

```yaml
Version: 2.10+
Storage: Rook Ceph RGW (S3)
```

**Pourquoi** :
- Scan de vulnérabilités (Trivy intégré)
- Réplication multi-site
- Garbage collection
- RBAC avancé

---

## Sécurité

### Policy Engine

#### Open Policy Agent (OPA) (Graduated) ⭐

**Statut CNCF** : Graduated (2021)
**Rôle** : Policy as code

```yaml
Version: 0.61+
Integration: Gatekeeper (admission controller)
```

**Pourquoi** :
- Policies déclaratives (Rego)
- Admission control Kubernetes
- Prévenir configurations non-conformes

**Exemple de policy** :
```rego
# Interdire images sans tag ou avec :latest
package kubernetes.admission

deny[msg] {
  input.request.kind.kind == "Pod"
  image := input.request.object.spec.containers[_].image
  not contains(image, ":")
  msg := sprintf("Image %v doit avoir un tag explicite", [image])
}
```

### Scan de Vulnérabilités

#### Trivy (Non-CNCF mais intégration Harbor)

**Rôle** : Scan de vulnérabilités images et K8s

```yaml
Version: 0.49+
Integration: Harbor, CI/CD
```

**Pourquoi** :
- Scan images Docker
- Scan manifests K8s
- Scan dépendances (pip, npm)
- Rapports CVE

### Secrets Management

#### External Secrets Operator (Incubating)

**Statut CNCF** : Incubating (2023)
**Rôle** : Synchronisation secrets externes → K8s

```yaml
Version: 0.9+
Backends:
  - Kubernetes Secrets (sealed-secrets)
  - HashiCorp Vault
```

**Pourquoi** :
- Centralisation secrets
- Rotation automatique
- Audit trail

**Alternative simple** : **SealedSecrets** (Bitnami)

---

## Stack Recommandée pour OpenAlex

### Composants Core (Obligatoires)

| Composant | Projet CNCF | Statut | Priorité |
|-----------|-------------|--------|----------|
| **Orchestration** | Kubernetes | Graduated | 🔴 P0 |
| **Stockage** | Rook/Ceph | Graduated | 🔴 P0 |
| **Monitoring** | Prometheus | Graduated | 🔴 P0 |
| **Logging** | Loki | Graduated | 🔴 P0 |
| **Backup** | Velero | Graduated | 🟡 P1 |
| **Ingress** | Contour (Envoy) | Graduated | 🔴 P0 |
| **TLS** | cert-manager | Graduated | 🔴 P0 |

### Composants Avancés (Recommandés)

| Composant | Projet CNCF | Statut | Priorité |
|-----------|-------------|--------|----------|
| **GitOps** | Flux | Graduated | 🟡 P1 |
| **Registry** | Harbor | Graduated | 🟡 P1 |
| **Metrics LT** | Thanos | Incubating | 🟢 P2 |
| **Policy** | OPA/Gatekeeper | Graduated | 🟢 P2 |
| **Secrets** | External Secrets | Incubating | 🟢 P2 |

### Composants Optionnels (Phase 5+)

| Composant | Projet CNCF | Statut | Priorité |
|-----------|-------------|--------|----------|
| **Tracing** | Jaeger | Graduated | ⚪ P3 |
| **Service Mesh** | Istio | Graduated | ⚪ P3 |
| **Chaos Eng** | Chaos Mesh | Incubating | ⚪ P3 |

---

## Architecture Globale CNCF

```text
┌─────────────────────────────────────────────────────────────────┐
│                         Utilisateurs                            │
└────────────────────────┬────────────────────────────────────────┘
                         │
                  ┌──────▼──────┐
                  │  Contour    │ (Ingress + Rate Limiting)
                  │  + cert-mgr │ (TLS auto)
                  └──────┬──────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────▼────┐    ┌─────▼────┐    ┌────▼────┐
    │ FastAPI │    │FastAPI   │    │ FastAPI │
    │  Pod 1  │    │  Pod 2   │    │  Pod 3  │
    └────┬────┘    └─────┬────┘    └────┬────┘
         │               │               │
         └───────────────┼───────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
   ┌────▼───┐      ┌─────▼────┐     ┌────▼────┐
   │  PG    │      │ Neo4j    │     │   ES    │
   │(StatefulSet)  │(StatefulSet)   │(StatefulSet)
   └────┬───┘      └─────┬────┘     └────┬────┘
        │                │                │
        └────────────────┼────────────────┘
                         │
                   ┌─────▼─────┐
                   │ Rook Ceph │
                   │  Storage  │
                   └─────┬─────┘
                         │
          ┌──────────────┼──────────────┐
          │              │              │
     ┌────▼────┐   ┌─────▼────┐   ┌────▼────┐
     │  OSD    │   │  OSD     │   │  OSD    │
     │ dirqual1│   │ dirqual2 │   │ dirqual3│
     └─────────┘   └──────────┘   └─────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      Observabilité (Monitoring)                 │
├─────────────────────────────────────────────────────────────────┤
│ Prometheus → Thanos → S3 (Long-term)                           │
│ Loki → S3 (Logs)                                                │
│ Grafana (Dashboards)                                            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      Gestion (Operations)                       │
├─────────────────────────────────────────────────────────────────┤
│ Flux (GitOps) → Git Repository                                  │
│ Velero (Backup) → S3                                            │
│ OPA/Gatekeeper (Policy)                                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Timeline de Déploiement CNCF

### Phase 1 : Fondations (Mois 1)

```yaml
Deploy:
  - Kubernetes cluster (K3s ou kubeadm)
  - Rook/Ceph (pools NVMe + HDD)
  - CoreDNS (inclus K8s)
  - Contour ingress
  - cert-manager

Validate:
  - Cluster healthy
  - Stockage provisionné
  - HTTPS fonctionnel
```

### Phase 2 : Observabilité (Mois 2)

```yaml
Deploy:
  - Prometheus + exporters
  - Loki + Promtail
  - Grafana
  - Dashboards de base

Validate:
  - Métriques collectées
  - Logs centralisés
  - Dashboards accessibles
```

### Phase 3 : Bases de Données (Mois 3-4)

```yaml
Deploy:
  - PostgreSQL StatefulSet
  - Neo4j StatefulSet
  - InfluxDB StatefulSet
  - Elasticsearch StatefulSet
  - Redis Cluster

Validate:
  - PVC provisionnés (Rook)
  - Métriques exportées (Prometheus)
  - Logs collectés (Loki)
```

### Phase 4 : API et ETL (Mois 5-6)

```yaml
Deploy:
  - FastAPI Deployment
  - Airflow (ETL)
  - Harbor (registry)

Validate:
  - API accessible via Contour
  - Rate limiting actif
  - Images scannées (Trivy)
```

### Phase 5 : Production (Mois 7-8)

```yaml
Deploy:
  - Flux GitOps
  - Velero backups
  - OPA/Gatekeeper policies
  - Thanos (long-term metrics)

Validate:
  - Déploiement GitOps fonctionnel
  - Backups quotidiens
  - Policies appliquées
  - Métriques historiques
```

---

## Conformité CNCF

### Graduated Projects ✅

Projets utilisés avec statut **Graduated** (production-ready) :

- ✅ Kubernetes
- ✅ Prometheus
- ✅ Envoy (via Contour)
- ✅ Rook
- ✅ Loki
- ✅ Flux
- ✅ cert-manager
- ✅ Harbor
- ✅ OPA
- ✅ Jaeger (optionnel)

### Incubating Projects 🔄

Projets utilisés avec statut **Incubating** (stables mais évoluent) :

- 🔄 Thanos
- 🔄 External Secrets

### Non-CNCF mais Standards 📦

Quelques composants hors CNCF mais standards cloud-native :

- 📦 **Grafana** - Standard de facto pour visualisation
- 📦 **Kaniko** - Build in-cluster sans daemon
- 📦 **Trivy** - Scan de vulnérabilités (intégré Harbor)

---

## Ressources

### Documentation CNCF

- [CNCF Landscape](https://landscape.cncf.io/)
- [CNCF Projects](https://www.cncf.io/projects/)
- [CNCF Maturity Levels](https://www.cncf.io/projects/maturity-levels/)

### Guides d'Implémentation

- [Kubernetes Production Best Practices](https://kubernetes.io/docs/setup/best-practices/)
- [Rook Production Guide](https://rook.io/docs/rook/latest/Getting-Started/best-practices/)
- [Prometheus Operator Guide](https://prometheus-operator.dev/)

### Formations

- [CNCF Kubernetes Certification (CKA)](https://www.cncf.io/certification/cka/)
- [CNCF Kubernetes Security (CKS)](https://www.cncf.io/certification/cks/)

---

## Prochaines Étapes

1. [Déploiement Kubernetes](../06-kubernetes/cluster-architecture.md)
2. [Configuration Rook/Ceph](../01-stockage/rook-ceph.md)
3. [Stack Monitoring Prometheus/Loki](../07-observabilite/monitoring-stack.md)
4. [GitOps avec Flux](../08-implementation/phase-1-foundations.md)

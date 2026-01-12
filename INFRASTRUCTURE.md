# Infrastructure Disponible - Cluster dirqual1-4

## 🎯 Résumé Exécutif

Votre infrastructure de **4 serveurs identiques** dépasse très largement les besoins du projet OpenAlex et offre une capacité de croissance exceptionnelle.

### Comparaison Besoins vs Disponible

| Ressource | Besoin OpenAlex | Disponible | Surplus |
|-----------|-----------------|------------|---------|
| **CPU Cœurs** | 32+ | **160** | **5×** |
| **CPU Threads** | 64+ | **320** | **5×** |
| **RAM** | 256 Go | **1 To** | **4×** |
| **SSD Rapide** | 13,5 To | **13,6 To** | ✅ **Parfait** |
| **Stockage Total** | 15 To | **284 To** | **19×** |

**Verdict** : ✅ Infrastructure **largement suffisante** pour héberger OpenAlex et bien plus.

---

## 📊 Spécifications Détaillées par Serveur

### Configuration Identique (dirqual1, dirqual2, dirqual3, dirqual4)

```yaml
CPU:
  Modèle: Intel Xeon Silver 4316 @ 2.30-3.40GHz
  Sockets: 2 processeurs
  Cœurs physiques: 40 (20 × 2)
  Threads (vCPUs): 80
  Cache L3: 60 MiB
  Architecture: NUMA 2 nœuds

Mémoire:
  Capacité: 252 Go (~256 Go)
  Type: DDR4 ECC
  Configuration: NUMA réparti

Stockage:
  NVMe SSD:
    - nvme0n1: 447 Go (système)
    - nvme1n1: 2,9 To (données)
    Total: 3,35 To

  HDD SAS:
    - 12 disques de 5,5 To chacun
    Total: 66 To (67,6 To réels)

Réseau:
  OS: Debian
  Virtualisation: VT-x activé
```

### Totaux du Cluster (4 serveurs)

```yaml
Puissance de calcul:
  CPU Physiques: 160 cœurs
  CPU Logiques: 320 threads
  Processeurs: 8× Intel Xeon Silver 4316

Mémoire:
  Total: 1 To (1 008 Go)
  Disponible: ~996 Go

Stockage:
  NVMe SSD: 13,6 To (haute performance)
  HDD SAS: 270 To (stockage masse)
  Total: 284 To
```

---

## 🏗️ Architecture Recommandée

### Répartition des Rôles

#### 🗄️ Serveurs Base de Données (dirqual1-2)

**dirqual1** - PostgreSQL Primary
```yaml
Rôle: Base de données principale
CPU: 40 cœurs / 80 threads
RAM: 252 Go
Stockage:
  NVMe: 3,4 To → PostgreSQL (3 To données + index)
  HDD RAID10: 33 To → Backups quotidiens

Configuration PostgreSQL:
  shared_buffers: 64 Go
  effective_cache_size: 189 Go
  max_worker_processes: 40
  max_parallel_workers: 40
```

**dirqual2** - PostgreSQL Replica + Staging
```yaml
Rôle: Réplication + Blue-Green déploiement
CPU: 40 cœurs / 80 threads
RAM: 252 Go
Stockage:
  NVMe: 3,4 To → Replica + Staging
  HDD RAID10: 33 To → Archives + exports OpenAlex
```

#### 🔍 Serveur Recherche (dirqual3)

**dirqual3** - Elasticsearch + Redis
```yaml
Rôle: Recherche plein texte et cache
CPU: 40 cœurs / 80 threads
RAM: 252 Go
Stockage:
  NVMe: 3,4 To → Elasticsearch (2 To) + Redis (100 Go)
  HDD RAID10: 33 To → Snapshots + logs historiques

Configuration Elasticsearch:
  Heap Size: 31 Go (50% des 64 Go alloués)
  Shards: 5 primaires, 1 replica
  Index: Works + Authors
```

#### ⚙️ Serveur Services (dirqual4)

**dirqual4** - API + Monitoring + CI/CD
```yaml
Rôle: Services applicatifs et infrastructure
CPU: 40 cœurs / 80 threads
RAM: 252 Go
Stockage:
  NVMe: 3,4 To → FastAPI + Monitoring + CI/CD
  HDD RAID10: 33 To → Disaster Recovery + snapshots

Services:
  - FastAPI (pods multiples)
  - Prometheus + Grafana + Loki
  - GitLab CI/CD
  - ETL temporaire
  - Réserve: 2 To NVMe disponible
```

---

## 💾 Configuration Stockage RAID

### RAID 10 Recommandé (Performance + Redondance)

**Par serveur** :
```bash
# 12 disques de 5,5 To en RAID 10
Capacité brute: 66 To
Capacité utilisable: 33 To (50% overhead)
Performance:
  - Lecture: Excellente (striping)
  - Écriture: Excellente (mirroring)
Tolérance aux pannes: Jusqu'à 6 disques (1 par miroir)

# Commande création RAID
mdadm --create /dev/md0 --level=10 --raid-devices=12 \
  /dev/sd{a,b,c,d,e,f,g,h,i,j,k,l}

# Format XFS (optimal pour PostgreSQL)
mkfs.xfs -f /dev/md0
```

**Total cluster** :
- 132 To utilisables (33 To × 4)
- 270 To bruts
- Haute performance lecture/écriture

---

## 📈 Capacité de Croissance

### Ce que vous pouvez héberger

| Projet | Volume | Faisabilité |
|--------|--------|-------------|
| **OpenAlex complet** | 3 To | ✅ Facile (10% capacité NVMe) |
| **10× OpenAlex** | 30 To | ✅ Possible (NVMe + HDD) |
| **Dev + Staging + Prod** | 9 To | ✅ Facile (3× environnements) |
| **20 ans de backups** | 60 To | ✅ Possible (HDD RAID) |
| **Projets additionnels** | Variable | ✅ Large marge disponible |

### Scénarios d'utilisation

#### Scénario 1: OpenAlex uniquement
```
Utilisation:
  NVMe: 13,5 To / 13,6 To (99%)
  HDD: 30 To / 132 To (23%)

Réserve disponible:
  HDD: 102 To pour expansion future
```

#### Scénario 2: Multi-tenant (3 projets)
```
Projet 1 (OpenAlex): 13,5 To
Projet 2 (autre dataset): 10 To
Projet 3 (R&D): 5 To
Backups: 40 To

Total utilisé: 68,5 To / 145,6 To (47%)
Réserve: 77 To disponible
```

#### Scénario 3: OpenAlex + ML/AI
```
OpenAlex: 13,5 To
Modèles ML: 20 To
Datasets training: 30 To
Résultats: 15 To

Total: 78,5 To / 145,6 To (54%)
Réserve: 67 To
```

---

## 🔧 Scripts d'Inventaire

### Vérification rapide de tous les serveurs

```bash
#!/bin/bash
# check-cluster.sh - Vérification rapide du cluster

echo "=== INVENTAIRE CLUSTER dirqual1-4 ==="
echo ""

for server in dirqual{1..4}; do
  echo "=== $server ==="
  ssh $server './scripts/system-info.sh --json' | jq '{
    cpu: .cpu.physical_cores,
    ram_gb: .memory.total_gb,
    nvme_to: (.storage.nvme_gb / 1024),
    hdd_to: (.storage.hdd_gb / 1024)
  }'
  echo ""
done

echo "=== TOTAUX CLUSTER ==="
echo "CPU: 160 cœurs physiques"
echo "RAM: 1 To"
echo "NVMe: 13,6 To"
echo "HDD: 270 To"
```

### Export CSV pour documentation

```bash
# Générer rapport CSV complet
echo "Hostname,CPU_Cores,CPU_Threads,RAM_GB,NVMe_TB,HDD_TB,Total_TB" > cluster-inventory.csv

for server in dirqual{1..4}; do
  ssh $server './scripts/system-info.sh --csv' | tail -1 >> cluster-inventory.csv
done

# Afficher tableau formaté
column -t -s',' cluster-inventory.csv
```

---

## ✅ Checklist de Préparation

### Avant déploiement Kubernetes

- [ ] Vérifier connectivité réseau entre les 4 serveurs
- [ ] Configurer RAID 10 sur les 12 HDD de chaque serveur
- [ ] Installer Kubernetes sur tous les nœuds
- [ ] Configurer storage classes pour NVMe et HDD
- [ ] Tester failover entre dirqual1 et dirqual2
- [ ] Configurer monitoring (node-exporter sur chaque serveur)
- [ ] Valider NUMA affinity pour PostgreSQL
- [ ] Configurer Huge Pages (32768 pages de 2 Mo)

### Tests de performance

- [ ] Benchmark disques NVMe (fio)
- [ ] Benchmark RAID 10 (fio)
- [ ] Test réseau inter-serveurs (iperf3)
- [ ] Test CPU (sysbench)
- [ ] Test RAM (memtest)
- [ ] Test PostgreSQL (pgbench)
- [ ] Test Elasticsearch (esrally)

---

## 📞 Contacts et Support

### Scripts disponibles

- `scripts/system-info.sh` - Inventaire matériel automatique
- `scripts/README.md` - Documentation des scripts
- `scripts/DEBIAN_FIXES.md` - Corrections Debian spécifiques

### Documentation

- [Inventaire matériel détaillé](docs/06-kubernetes/hardware-inventory.md)
- [Stratégie de stockage](docs/01-stockage/strategy.md)
- [Vue d'ensemble du projet](docs/00-introduction/overview.md)

---

**Dernière mise à jour** : 2026-01-12
**Infrastructure vérifiée** : dirqual1, dirqual2, dirqual3, dirqual4
**Status** : ✅ Prête pour déploiement OpenAlex
**Équipe** : Infrastructure - Université Le Havre Normandie

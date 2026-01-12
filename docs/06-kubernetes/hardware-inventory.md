---
id: hardware-inventory
title: Inventaire Matériel du Cluster
author: Équipe Infrastructure - Université Le Havre Normandie
date: 2026-01-12
version: 1.0.0
status: approved
priority: high
tags: [kubernetes, hardware, infrastructure, inventory]
categories: [infrastructure, technique]
dependencies: []
sidebar_label: Inventaire Matériel
sidebar_position: 1
---

# Inventaire Matériel du Cluster Kubernetes

## Vue d'Ensemble

Le cluster Kubernetes pour l'API OpenAlex est composé de **4 serveurs physiques identiques** de haute performance, situés à l'Université Le Havre Normandie.

## Spécifications par Serveur

### Configuration Standard (dirqual1-4)

Chaque serveur dispose de :

#### Processeurs (CPU)
- **Modèle** : Intel Xeon Silver 4316 @ 2.30GHz
- **Sockets** : 2 processeurs physiques
- **Cœurs par socket** : 20 cœurs
- **Total cœurs physiques** : 40 cœurs
- **Threads par cœur** : 2 (Hyper-Threading activé)
- **Total threads (vCPUs)** : 80 threads
- **Fréquence**:
  - Base : 2.30 GHz
  - Turbo : jusqu'à 3.40 GHz
  - Min (économie) : 800 MHz
- **Cache L3** : 60 MiB (30 MiB par socket)
- **Architecture NUMA** : 2 nœuds

#### Mémoire (RAM)
- **Capacité totale** : 252 Go (≈ 256 Go)
- **Type** : DDR4 ECC (probable)
- **Configuration** : Répartie sur 2 nœuds NUMA
- **Disponible au démarrage** : ~249 Go

#### Stockage

##### NVMe SSD (Haute Performance)
- **nvme0n1** : 447 Go (système d'exploitation)
  - Partitionnement LVM :
    - `/` : 23,3 Go
    - `/var` : 9,3 Go
    - `/home` : 410,7 Go
    - `/tmp` : 1,9 Go
    - `/boot` : 488 Mo
    - `/boot/efi` : 512 Mo
    - swap : 976 Mo
- **nvme1n1** : 2,9 To (données chaudes)
- **Total NVMe** : 3,35 To

##### HDD SAS (Stockage Masse)
- **12 disques** : sda à sdl
- **Capacité unitaire** : 5,5 To chacun
- **Total HDD** : 66 To (67,6 To réels)
- **Type** : Disques rotationnels (HDD)
- **Usage prévu** : RAID, backups, archives

##### Capacité Totale par Serveur
- **Total brut** : 71 To
- **NVMe SSD** : 3,4 To (haute performance)
- **HDD** : 67,6 To (stockage masse)

## Totaux du Cluster (4 serveurs)

### Puissance de Calcul

```
CPU :
  - Cœurs physiques : 160 (40 × 4)
  - Threads (vCPUs) : 320 (80 × 4)
  - Modèle : 8× Intel Xeon Silver 4316

RAM :
  - Capacité totale : 1 To (252 Go × 4)
  - Disponible : ~996 Go
```

### Capacité de Stockage

```
Stockage Total : 284 To

NVMe SSD (Haute Performance) :
  - 13,6 To (3,4 To × 4)
  - Usage : PostgreSQL, Elasticsearch, données chaudes

HDD SAS (Stockage Masse) :
  - 270 To (67,6 To × 4)
  - Usage : Backups, archives, données froides
```

## Architecture NUMA

Chaque serveur dispose de **2 nœuds NUMA** :

```
Nœud NUMA 0 : vCPUs 0-19, 40-59 (Socket 1)
Nœud NUMA 1 : vCPUs 20-39, 60-79 (Socket 2)
```

Cette configuration permet :
- **Affinité mémoire** pour PostgreSQL
- **Isolation des workloads** critiques
- **Performance optimale** pour bases de données

## Détails Techniques

### Virtualisation
- **VT-x** : Activé
- **Support** : VM et conteneurs

### Réseau
- **Hostname** : dirqual1, dirqual2, dirqual3, dirqual4
- **OS** : Debian (version à confirmer)
- **Kernel** : Linux récent avec support NUMA

### Disques - Détails

#### Configuration Actuelle
Tous les disques HDD (sda-sdl) sont actuellement **non formatés** et disponibles pour configuration.

#### Configuration Recommandée

**Option 1 : RAID 10 (Performance + Redondance)**
```bash
# Par serveur : 33 To utilisables (50% overhead)
# Cluster : 132 To utilisables
# Tolérance : Jusqu'à 6 disques par serveur
mdadm --create /dev/md0 --level=10 --raid-devices=12 \
  /dev/sd{a,b,c,d,e,f,g,h,i,j,k,l}
```

**Option 2 : RAID 6 (Maximum d'espace)**
```bash
# Par serveur : 55 To utilisables (2 disques parité)
# Cluster : 220 To utilisables
# Tolérance : Jusqu'à 2 disques par serveur
mdadm --create /dev/md0 --level=6 --raid-devices=12 \
  /dev/sd{a,b,c,d,e,f,g,h,i,j,k,l}
```

## Allocation des Ressources

### Par Type de Nœud

#### Nœuds PostgreSQL (2 serveurs)
```yaml
Serveurs : dirqual1, dirqual2
CPU : 80 cœurs physiques, 160 threads
RAM : 504 Go
Stockage :
  - NVMe : 6,8 To (données PostgreSQL)
  - HDD RAID10 : 66 To (backups)
```

#### Nœuds Elasticsearch (1 serveur)
```yaml
Serveur : dirqual3
CPU : 40 cœurs physiques, 80 threads
RAM : 252 Go
Stockage :
  - NVMe : 3,4 To (index Elasticsearch)
  - HDD RAID10 : 33 To (snapshots)
```

#### Nœud Services (1 serveur)
```yaml
Serveur : dirqual4
CPU : 40 cœurs physiques, 80 threads
RAM : 252 Go
Stockage :
  - NVMe : 3,4 To (API, monitoring, CI/CD)
  - HDD RAID10 : 33 To (logs, métriques)
```

## Comparaison avec Besoins Projet

| Besoin | Requis | Disponible | Statut |
|--------|--------|------------|--------|
| **CPU Cœurs** | 32+ | **160** | ✅ 5× surplus |
| **CPU Threads** | 64+ | **320** | ✅ 5× surplus |
| **RAM** | 256 Go | **1 To** | ✅ 4× surplus |
| **SSD Rapide** | 3-5 To | **13,6 To** | ✅ 3× surplus |
| **Stockage Total** | 10 To | **284 To** | ✅ 28× surplus |

**Conclusion** : L'infrastructure disponible dépasse **largement** les besoins du projet OpenAlex.

## Capacité de Croissance

Avec cette infrastructure, le cluster peut supporter :

- **10× le volume OpenAlex** (30 To de données)
- **Plusieurs projets simultanés** (multi-tenant)
- **Expansion future** sans changement matériel
- **Environnements multiples** (dev, staging, prod)

## Scripts de Vérification

### Inventaire Automatique

```bash
# Sur chaque serveur
./scripts/system-info.sh --json > inventory-$(hostname).json

# Export CSV pour tous les serveurs
for server in dirqual{1..4}; do
  ssh $server './system-info.sh --csv'
done > cluster-inventory.csv
```

### Monitoring en Temps Réel

```bash
# CPU par serveur
for server in dirqual{1..4}; do
  echo "=== $server ==="
  ssh $server 'lscpu | grep -E "^CPU\(s\)|^Model name"'
done

# Mémoire par serveur
for server in dirqual{1..4}; do
  echo "=== $server ==="
  ssh $server 'free -h | grep "^Mem:"'
done

# Stockage par serveur
for server in dirqual{1..4}; do
  echo "=== $server ==="
  ssh $server 'lsblk -d | grep -E "^(sd|nvme)"'
done
```

## Notes de Configuration

### Optimisations Recommandées

1. **Huge Pages** pour PostgreSQL
```bash
# 64 Go de shared_buffers = 32768 huge pages de 2 Mo
vm.nr_hugepages = 32768
```

2. **Tuning Réseau** pour haute performance
```bash
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
```

3. **Limites Systèmes** pour PostgreSQL/Elasticsearch
```bash
# /etc/security/limits.conf
postgres  soft  nofile  65536
postgres  hard  nofile  65536
elasticsearch  soft  nofile  65536
elasticsearch  hard  nofile  65536
```

## Maintenance

### Surveillance Matérielle

- **SMART monitoring** pour disques
- **Température** CPU/disques
- **État RAID** (après configuration)
- **Métriques NUMA** pour optimisation

### Cycle de Vie

- **Garantie** : À vérifier auprès du service informatique
- **Maintenance préventive** : Trimestrielle
- **Tests de basculement** : Mensuels

---

**Dernière vérification** : 2026-01-12
**Script utilisé** : [system-info.sh](../../scripts/system-info.sh)
**Serveurs inventoriés** : dirqual1, dirqual2, dirqual3, dirqual4

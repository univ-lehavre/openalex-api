# Scripts Utilitaires

Collection de scripts bash pour la gestion et le monitoring de l'infrastructure API OpenAlex.

## 📊 system-info.sh

Script de récupération des informations système (CPU, mémoire, stockage).

### 🎯 Utilisation

```bash
# Affichage texte avec couleurs
./scripts/system-info.sh

# Export JSON
./scripts/system-info.sh --json

# Export CSV
./scripts/system-info.sh --csv

# Sauvegarder dans un fichier
./scripts/system-info.sh --json > system-$(hostname)-$(date +%Y%m%d).json
```

### 📋 Informations Récupérées

#### CPU
- Modèle du processeur
- Nombre de cœurs physiques
- Nombre de threads (vCPUs/cœurs logiques)

#### Mémoire
- Capacité totale (Go et Mo)
- Mémoire disponible
- Mémoire utilisée

#### Stockage
- Détection automatique du type de disque :
  - **NVMe SSD** - Disques NVMe haute performance
  - **SSD** - Disques SSD SATA
  - **HDD** - Disques durs mécaniques
- Capacité par type
- Capacité totale

### 💻 Compatibilité

✅ **Linux** (Debian, Ubuntu, CentOS, RHEL, etc.)
- Utilise `lscpu`, `/proc/cpuinfo`, `/proc/meminfo`, `lsblk`
- Détection automatique du type de disque via `/sys/block/*/queue/rotational`

✅ **macOS**
- Utilise `sysctl`, `vm_stat`, `diskutil`
- Détection des SSD via attribut "Solid State"

### 📦 Dépendances

#### Linux (Debian/Ubuntu)
```bash
# Outils généralement préinstallés
sudo apt-get install util-linux coreutils

# Pour une détection optimale du stockage
sudo apt-get install lsblk
```

#### macOS
Aucune dépendance - outils système natifs

### 📤 Formats d'Export

#### JSON
```json
{
  "timestamp": "2026-01-12T14:55:58Z",
  "hostname": "node-k8s-01",
  "os": "Linux",
  "cpu": {
    "model": "Intel(R) Xeon(R) CPU E5-2680 v4 @ 2.40GHz",
    "physical_cores": 28,
    "threads": 56
  },
  "memory": {
    "total_gb": 256.00,
    "total_mb": 262144,
    "available_gb": 128.50,
    "used_gb": 127.50
  },
  "storage": {
    "nvme_gb": 2000,
    "ssd_gb": 1000,
    "hdd_gb": 4000,
    "total_gb": 7000
  }
}
```

#### CSV
```csv
Timestamp,Hostname,OS,CPU_Model,CPU_Physical_Cores,CPU_Threads,Memory_Total_GB,Memory_Available_GB,Memory_Used_GB,Storage_NVMe_GB,Storage_SSD_GB,Storage_HDD_GB,Storage_Total_GB
2026-01-12T14:55:58Z,node-k8s-01,Linux,"Intel Xeon E5-2680",28,56,256.00,128.50,127.50,2000,1000,4000,7000
```

### 🚀 Cas d'Usage

#### 1. Inventaire du Cluster Kubernetes

Récupérer les informations de tous les nœuds :

```bash
#!/bin/bash
# inventory-cluster.sh

nodes=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')

for node in $nodes; do
    echo "Scanning $node..."
    kubectl exec -n kube-system "$(kubectl get pods -n kube-system -l component=kube-proxy --field-selector spec.nodeName=$node -o jsonpath='{.items[0].metadata.name}')" -- bash -c "$(cat scripts/system-info.sh)" -- --json > "inventory-$node.json"
done
```

#### 2. Vérification des Prérequis

Vérifier que les nœuds ont les ressources minimales :

```bash
#!/bin/bash
# check-requirements.sh

# Exigences pour cluster OpenAlex
MIN_CPU_CORES=32
MIN_MEMORY_GB=128
MIN_STORAGE_GB=1000

info=$(./scripts/system-info.sh --json)

cpu_cores=$(echo "$info" | jq -r '.cpu.physical_cores')
memory_gb=$(echo "$info" | jq -r '.memory.total_gb' | cut -d'.' -f1)
storage_gb=$(echo "$info" | jq -r '.storage.total_gb')

echo "Vérification des prérequis pour nœud Kubernetes..."
echo ""

if [ "$cpu_cores" -ge "$MIN_CPU_CORES" ]; then
    echo "✅ CPU : $cpu_cores cœurs (>= $MIN_CPU_CORES requis)"
else
    echo "❌ CPU : $cpu_cores cœurs (< $MIN_CPU_CORES requis)"
fi

if [ "$memory_gb" -ge "$MIN_MEMORY_GB" ]; then
    echo "✅ Mémoire : ${memory_gb} Go (>= $MIN_MEMORY_GB Go requis)"
else
    echo "❌ Mémoire : ${memory_gb} Go (< $MIN_MEMORY_GB Go requis)"
fi

if [ "$storage_gb" -ge "$MIN_STORAGE_GB" ]; then
    echo "✅ Stockage : ${storage_gb} Go (>= $MIN_STORAGE_GB Go requis)"
else
    echo "❌ Stockage : ${storage_gb} Go (< $MIN_STORAGE_GB Go requis)"
fi
```

#### 3. Monitoring et Alertes

Intégrer avec Prometheus :

```bash
#!/bin/bash
# prometheus-exporter.sh

while true; do
    info=$(./scripts/system-info.sh --json)

    # Exporter les métriques au format Prometheus
    cpu_cores=$(echo "$info" | jq -r '.cpu.physical_cores')
    memory_total=$(echo "$info" | jq -r '.memory.total_gb')
    storage_total=$(echo "$info" | jq -r '.storage.total_gb')

    cat > /var/lib/node_exporter/textfile_collector/system_inventory.prom <<EOF
# HELP system_cpu_cores Number of physical CPU cores
# TYPE system_cpu_cores gauge
system_cpu_cores{hostname="$(hostname)"} $cpu_cores

# HELP system_memory_total_gb Total memory in GB
# TYPE system_memory_total_gb gauge
system_memory_total_gb{hostname="$(hostname)"} $memory_total

# HELP system_storage_total_gb Total storage in GB
# TYPE system_storage_total_gb gauge
system_storage_total_gb{hostname="$(hostname)"} $storage_total
EOF

    sleep 300  # Refresh toutes les 5 minutes
done
```

#### 4. Rapport d'Infrastructure

Générer un rapport pour toute l'infrastructure :

```bash
#!/bin/bash
# generate-infra-report.sh

output_dir="reports/infrastructure-$(date +%Y%m%d)"
mkdir -p "$output_dir"

# Entête CSV
echo "Timestamp,Hostname,OS,CPU_Model,CPU_Physical_Cores,CPU_Threads,Memory_Total_GB,Memory_Available_GB,Memory_Used_GB,Storage_NVMe_GB,Storage_SSD_GB,Storage_HDD_GB,Storage_Total_GB" > "$output_dir/cluster-inventory.csv"

# Scanner chaque serveur
for server in node-{01..10}; do
    echo "Scanning $server..."
    ssh "$server" 'bash -s' < scripts/system-info.sh -- --csv | tail -1 >> "$output_dir/cluster-inventory.csv"
done

echo "✅ Rapport généré : $output_dir/cluster-inventory.csv"
```

### 🔍 Débogage

Activer le mode verbose pour le débogage :

```bash
# Ajouter set -x au début du script
bash -x ./scripts/system-info.sh
```

### 📝 Notes Spécifiques Debian

Sur Debian, le script utilise :

- **lscpu** - Informations CPU détaillées
- **/proc/cpuinfo** - Fallback si lscpu indisponible
- **/proc/meminfo** - Informations mémoire
- **lsblk** - Liste et type des disques
- **/sys/block/*/queue/rotational** - Détection SSD vs HDD
  - `0` = SSD (pas de rotation)
  - `1` = HDD (rotation mécanique)

### ⚙️ Configuration des Nœuds Kubernetes

Pour le cluster OpenAlex (10 nœuds), voici les profils attendus :

#### Nœuds Base de Données (4 nœuds)
```
CPU : 64 cœurs physiques
RAM : 256 Go
Stockage : 2 To NVMe SSD
```

#### Nœuds API (3 nœuds)
```
CPU : 16 cœurs physiques
RAM : 64 Go
Stockage : 256 Go SSD
```

#### Nœuds ETL (2 nœuds)
```
CPU : 32 cœurs physiques
RAM : 128 Go
Stockage : 512 Go SSD
```

#### Nœud Système (1 nœud)
```
CPU : 8 cœurs physiques
RAM : 32 Go
Stockage : 256 Go SSD
```

### 📊 Total Cluster

En exécutant le script sur tous les nœuds :

```bash
# Agréger les résultats
for i in {1..10}; do
    ./scripts/system-info.sh --json > node-$i.json
done

# Calculer totaux avec jq
total_cores=$(jq -s 'map(.cpu.physical_cores) | add' node-*.json)
total_memory=$(jq -s 'map(.memory.total_gb) | add' node-*.json)
total_storage=$(jq -s 'map(.storage.total_gb) | add' node-*.json)

echo "Total Cluster:"
echo "  CPU Cores: $total_cores"
echo "  Memory: ${total_memory} Go"
echo "  Storage: ${total_storage} Go"
```

Devrait afficher :
```
Total Cluster:
  CPU Cores: 376
  Memory: 1536.00 Go (1.5 To)
  Storage: 13500 Go (13.5 To)
```

### 🔒 Permissions

Le script nécessite des permissions de lecture sur :
- `/proc/cpuinfo`
- `/proc/meminfo`
- `/sys/block/*/queue/rotational`

Aucun privilège root n'est requis.

### 🐛 Troubleshooting

**Erreur : "lsblk: command not found"**
```bash
sudo apt-get install util-linux
```

**Erreur : "numfmt: command not found"**
```bash
sudo apt-get install coreutils
```

**Disques non détectés**
```bash
# Vérifier que les disques sont visibles
lsblk -d

# Vérifier les permissions
ls -la /sys/block/
```

---

**Auteur** : Équipe Infrastructure - Université Le Havre Normandie
**Version** : 1.0.0
**Date** : 2026-01-12

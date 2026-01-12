# Corrections pour Debian

## 🐛 Problèmes Résolus

### Version 2.0 - Optimisations Debian/Linux

Cette version corrige plusieurs problèmes de compatibilité avec Debian et autres distributions Linux.

## 📋 Corrections Principales

### 1. Utilisation de `bc` pour les Calculs Décimaux

**Problème** : `awk` avec `BEGIN` ne fonctionne pas de manière cohérente sur toutes les distributions.

**Solution** :
```bash
# ❌ Avant (ne fonctionnait pas sur Debian)
total_gb=$(awk "BEGIN {printf \"%.2f\", $total_mb/1024}")

# ✅ Après (fonctionne partout)
total_gb=$(printf "%.2f" "$(echo "scale=2; $total_mb/1024" | bc)")
```

**Dépendance** : Nécessite `bc` (Basic Calculator)
```bash
sudo apt-get install bc
```

### 2. Détection Robuste des Informations CPU

**Problème** : `lscpu` peut avoir des sorties différentes selon les versions.

**Solution** :
```bash
# Utilise grep -i pour ignorer la casse
cpu_model=$(lscpu | grep -i "Model name" | cut -d':' -f2 | sed 's/^[ \t]*//')

# Valeurs par défaut si vides
physical_cores=${physical_cores:-1}
sockets=${sockets:-1}
threads_per_core=${threads_per_core:-1}

# Fallback amélioré avec /proc/cpuinfo
if [[ -z "$cpu_model" ]]; then
    cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d':' -f2 | sed 's/^[ \t]*//')
fi
```

### 3. Gestion de `MemAvailable` Absente

**Problème** : `MemAvailable` n'existe que sur Linux kernel 3.14+.

**Solution** :
```bash
# Fallback sur MemFree si MemAvailable n'existe pas
if grep -q "MemAvailable" /proc/meminfo; then
    available_kb=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')
else
    available_kb=$(grep "MemFree" /proc/meminfo | awk '{print $2}')
fi
```

### 4. Conversion de Taille Améliorée

**Problème** : `numfmt` n'est pas toujours disponible.

**Solution** : Fonction `convert_to_gb` personnalisée
```bash
convert_to_gb() {
    local size="$1"
    local value unit

    # Extraire valeur et unité
    value=$(echo "$size" | grep -oE '[0-9.]+')
    unit=$(echo "$size" | grep -oE '[A-Z]+')

    case "$unit" in
        K|KB)   echo "$(echo "scale=2; $value / 1024 / 1024" | bc)" ;;
        M|MB)   echo "$(echo "scale=2; $value / 1024" | bc)" ;;
        G|GB)   echo "$(echo "scale=2; $value" | bc)" ;;
        T|TB)   echo "$(echo "scale=2; $value * 1024" | bc)" ;;
        P|PB)   echo "$(echo "scale=2; $value * 1024 * 1024" | bc)" ;;
        *)      echo "0" ;;
    esac
}
```

### 5. Détection Améliorée des Disques

**Problème** : Filtrage trop restrictif avec `grep disk`.

**Solution** :
```bash
# ❌ Avant (manquait des disques)
lsblk -ndo NAME,SIZE,TYPE | grep disk

# ✅ Après (capture tous les types de disques)
lsblk -ndo NAME,SIZE | grep -E '^(sd|nvme|vd|hd)'
```

**Patterns de disques supportés** :
- `sd*` - Disques SCSI/SATA (ex: sda, sdb)
- `nvme*` - Disques NVMe (ex: nvme0n1, nvme1n1)
- `vd*` - Disques virtuels (ex: vda sur KVM)
- `hd*` - Disques IDE anciens (ex: hda)

### 6. Vérification des Permissions

**Problème** : Accès refusé à `/sys/block/*/queue/rotational`.

**Solution** :
```bash
# Vérifier l'existence avant lecture
if [[ -f "/sys/block/$device/queue/rotational" ]]; then
    rotational=$(cat "/sys/block/$device/queue/rotational" 2>/dev/null || echo "1")
else
    rotational="1"  # Assume HDD par défaut
fi
```

### 7. Gestion des Erreurs Silencieuses

**Problème** : Erreurs non capturées avec `set -euo pipefail`.

**Solution** :
```bash
# Redirection des erreurs vers stderr
print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

# Valeurs par défaut pour toutes les variables
CPU_MODEL=""
CPU_PHYSICAL_CORES=0
CPU_THREADS=0
# ... etc
```

### 8. Test de Disponibilité de `bc`

**Problème** : Script plante si `bc` n'est pas installé.

**Solution** :
```bash
# Vérification au début du script
if ! command -v bc &> /dev/null; then
    echo "Erreur: 'bc' n'est pas installé. Installation requise : apt-get install bc" >&2
    exit 1
fi
```

## 🧪 Tests sur Debian

### Installation des Dépendances

```bash
# Sur Debian/Ubuntu
sudo apt-get update
sudo apt-get install -y \
    bc \
    coreutils \
    util-linux \
    lsblk
```

### Test de Base

```bash
# Test en mode texte
./scripts/system-info.sh

# Devrait afficher :
# ✓ Modèle CPU: Intel(R) Xeon(R) CPU...
# ✓ Cœurs physiques: 32
# ✓ Threads (vCPUs): 64
# ✓ Mémoire totale: 256.00 Go
# ✓ Total NVMe SSD: 2000 Go
```

### Test JSON

```bash
./scripts/system-info.sh --json | jq .
```

Devrait retourner un JSON valide sans erreurs.

### Test CSV

```bash
./scripts/system-info.sh --csv
```

Devrait retourner une ligne CSV valide.

## 🔍 Debugging sur Debian

### Mode Verbose

```bash
# Activer le mode debug
bash -x ./scripts/system-info.sh 2>&1 | tee debug.log
```

### Vérifications Manuelles

```bash
# 1. Vérifier lscpu
lscpu

# 2. Vérifier /proc/cpuinfo
cat /proc/cpuinfo

# 3. Vérifier /proc/meminfo
cat /proc/meminfo

# 4. Vérifier lsblk
lsblk -ndo NAME,SIZE

# 5. Vérifier rotational
for disk in /sys/block/sd*/queue/rotational; do
    echo "$disk: $(cat $disk 2>/dev/null)"
done

# 6. Tester bc
echo "scale=2; 1024/1024" | bc
```

## 📊 Exemples de Sortie Debian

### Serveur avec 2 SSD + 1 HDD

```
INFORMATIONS CPU
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Modèle CPU: Intel(R) Xeon(R) CPU E5-2680 v4 @ 2.40GHz
✓ Cœurs physiques: 28
✓ Threads (vCPUs): 56

INFORMATIONS MÉMOIRE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Mémoire totale: 256.00 Go (262144 Mo)
✓ Mémoire disponible: 200.50 Go (205312 Mo)
✓ Mémoire utilisée: 55.50 Go (56832 Mo)

INFORMATIONS STOCKAGE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Disques détectés :

  • /dev/nvme0n1 : 2.0T (NVMe SSD)
  • /dev/sda : 1.0T (SSD)
  • /dev/sdb : 4.0T (HDD)

✓ Total NVMe SSD: 2048 Go
✓ Total SSD: 1024 Go
✓ Total HDD: 4096 Go
✓ Capacité totale: 7168 Go
```

### Export JSON

```json
{
  "timestamp": "2026-01-12T15:30:00Z",
  "hostname": "node-k8s-db-01",
  "os": "Linux",
  "cpu": {
    "model": "Intel(R) Xeon(R) CPU E5-2680 v4 @ 2.40GHz",
    "physical_cores": 28,
    "threads": 56
  },
  "memory": {
    "total_gb": 256.00,
    "total_mb": 262144,
    "available_gb": 200.50,
    "used_gb": 55.50
  },
  "storage": {
    "nvme_gb": 2048,
    "ssd_gb": 1024,
    "hdd_gb": 4096,
    "total_gb": 7168
  }
}
```

## 🚨 Erreurs Connues et Solutions

### 1. `bc: command not found`

**Solution** :
```bash
sudo apt-get install bc
```

### 2. `lsblk: command not found`

**Solution** :
```bash
sudo apt-get install util-linux
```

### 3. Disques non détectés

**Cause** : Permissions insuffisantes ou pattern de disque non reconnu.

**Solution** :
```bash
# Lister tous les disques disponibles
lsblk -d

# Vérifier le pattern
ls -la /sys/block/

# Si disques virtuals (vda, vdb)
lsblk -ndo NAME,SIZE | grep -E '^(sd|nvme|vd|hd)'
```

### 4. Valeurs 0 pour le stockage

**Cause** : Conversion de taille échouée.

**Debug** :
```bash
# Tester la fonction convert_to_gb
echo "scale=2; 1024 / 1024" | bc

# Vérifier la sortie lsblk
lsblk -ndo NAME,SIZE
```

### 5. `/sys/block/.../rotational` introuvable

**Cause** : Disques virtuels ou système de fichiers particulier.

**Solution** : Le script assume HDD par défaut (valeur sécuritaire).

## ✅ Checklist de Validation Debian

Avant de déployer sur vos nœuds Kubernetes :

- [ ] `bc` installé
- [ ] `lsblk` disponible
- [ ] Test en mode texte réussi
- [ ] Test JSON valide
- [ ] Test CSV valide
- [ ] Tous les disques détectés correctement
- [ ] Types de disques corrects (NVMe/SSD/HDD)
- [ ] Valeurs CPU cohérentes
- [ ] Valeurs mémoire cohérentes

## 📝 Notes de Version

**Version 1.0** (commit 74da560)
- Version initiale, problèmes sur Debian

**Version 2.0** (ce commit)
- ✅ Utilisation de `bc` pour calculs décimaux
- ✅ Détection CPU robuste avec fallbacks
- ✅ Gestion de `MemAvailable` absente
- ✅ Fonction `convert_to_gb` personnalisée
- ✅ Détection étendue des disques (sd, nvme, vd, hd)
- ✅ Gestion des erreurs améliorée
- ✅ Vérification des dépendances
- ✅ Testé sur Debian 11/12

---

**Testé sur** :
- ✅ Debian 11 (Bullseye)
- ✅ Debian 12 (Bookworm)
- ✅ Ubuntu 20.04/22.04
- ✅ macOS (développement)

**Auteur** : Équipe Infrastructure - Université Le Havre Normandie

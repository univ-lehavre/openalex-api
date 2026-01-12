#!/usr/bin/env bash
#
# Script de récupération des informations système
# Optimisé pour Debian/Linux, compatible macOS
# Usage: ./system-info.sh [--json|--csv]
#

set -euo pipefail

# Couleurs pour l'affichage
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Variables globales
CPU_MODEL=""
CPU_PHYSICAL_CORES=0
CPU_THREADS=0
MEM_TOTAL_GB=0
MEM_TOTAL_MB=0
MEM_AVAILABLE_GB=0
MEM_USED_GB=0
STORAGE_NVME_GB=0
STORAGE_SSD_GB=0
STORAGE_HDD_GB=0
STORAGE_TOTAL_GB=0

# Détection de l'OS
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "Linux";;
        Darwin*)    echo "macOS";;
        *)          echo "Unknown";;
    esac
}

OS=$(detect_os)

# Fonction d'affichage avec couleur
print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_info() {
    echo -e "${GREEN}✓${NC} $1: ${YELLOW}$2${NC}"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

# =============================================================================
# INFORMATIONS CPU
# =============================================================================

get_cpu_info() {
    print_header "INFORMATIONS CPU"

    if [[ "$OS" == "Linux" ]]; then
        # Linux - utilise lscpu et /proc/cpuinfo
        if command -v lscpu &> /dev/null; then
            cpu_model=$(lscpu | grep -i "Model name" | cut -d':' -f2 | sed 's/^[ \t]*//')

            # Gestion des cas où certaines valeurs peuvent être absentes
            physical_cores=$(lscpu | grep -i "^Core(s) per socket:" | awk '{print $NF}')
            sockets=$(lscpu | grep -i "^Socket(s):" | awk '{print $NF}')
            threads_per_core=$(lscpu | grep -i "^Thread(s) per core:" | awk '{print $NF}')

            # Valeurs par défaut si vides
            physical_cores=${physical_cores:-1}
            sockets=${sockets:-1}
            threads_per_core=${threads_per_core:-1}

            total_physical_cores=$((physical_cores * sockets))
            total_threads=$((total_physical_cores * threads_per_core))
        else
            # Fallback avec /proc/cpuinfo
            cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d':' -f2 | sed 's/^[ \t]*//')
            total_threads=$(grep -c "^processor" /proc/cpuinfo)

            # Essayer de déterminer les cœurs physiques
            physical_cores=$(grep -m1 "cpu cores" /proc/cpuinfo | awk '{print $NF}')
            if [[ -z "$physical_cores" ]]; then
                # Si pas de "cpu cores", compter les physical id uniques
                physical_cores=$(grep "physical id" /proc/cpuinfo | sort -u | wc -l)
                if [[ $physical_cores -eq 0 ]]; then
                    physical_cores=1
                fi
            fi
            total_physical_cores=$physical_cores
        fi

        # Valeur par défaut pour cpu_model si vide
        cpu_model=${cpu_model:-"Unknown CPU"}

        print_info "Modèle CPU" "$cpu_model"
        print_info "Cœurs physiques" "$total_physical_cores"
        print_info "Threads (vCPUs)" "$total_threads"

        # Export variables pour JSON/CSV
        CPU_MODEL="$cpu_model"
        CPU_PHYSICAL_CORES="$total_physical_cores"
        CPU_THREADS="$total_threads"

    elif [[ "$OS" == "macOS" ]]; then
        # macOS - utilise sysctl
        cpu_model=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown CPU")
        physical_cores=$(sysctl -n hw.physicalcpu 2>/dev/null || echo "1")
        logical_cores=$(sysctl -n hw.logicalcpu 2>/dev/null || echo "1")

        print_info "Modèle CPU" "$cpu_model"
        print_info "Cœurs physiques" "$physical_cores"
        print_info "Cœurs logiques (threads)" "$logical_cores"

        # Export variables
        CPU_MODEL="$cpu_model"
        CPU_PHYSICAL_CORES="$physical_cores"
        CPU_THREADS="$logical_cores"
    fi
}

# =============================================================================
# INFORMATIONS MÉMOIRE
# =============================================================================

get_memory_info() {
    print_header "INFORMATIONS MÉMOIRE"

    if [[ "$OS" == "Linux" ]]; then
        # Linux - lecture de /proc/meminfo
        total_kb=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        total_mb=$((total_kb / 1024))
        total_gb=$(printf "%.2f" "$(echo "scale=2; $total_mb/1024" | bc)")

        # MemAvailable n'existe pas sur tous les noyaux, fallback sur MemFree
        if grep -q "MemAvailable" /proc/meminfo; then
            available_kb=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')
        else
            available_kb=$(grep "MemFree" /proc/meminfo | awk '{print $2}')
        fi
        available_mb=$((available_kb / 1024))
        available_gb=$(printf "%.2f" "$(echo "scale=2; $available_mb/1024" | bc)")

        used_mb=$((total_mb - available_mb))
        used_gb=$(printf "%.2f" "$(echo "scale=2; $used_mb/1024" | bc)")

        print_info "Mémoire totale" "${total_gb} Go (${total_mb} Mo)"
        print_info "Mémoire disponible" "${available_gb} Go (${available_mb} Mo)"
        print_info "Mémoire utilisée" "${used_gb} Go (${used_mb} Mo)"

        # Export variables
        MEM_TOTAL_GB="$total_gb"
        MEM_TOTAL_MB="$total_mb"
        MEM_AVAILABLE_GB="$available_gb"
        MEM_USED_GB="$used_gb"

    elif [[ "$OS" == "macOS" ]]; then
        # macOS - utilise sysctl et vm_stat
        total_bytes=$(sysctl -n hw.memsize)
        total_mb=$((total_bytes / 1024 / 1024))
        total_gb=$(printf "%.2f" "$(echo "scale=2; $total_mb/1024" | bc)")

        # vm_stat pour mémoire utilisée/disponible
        page_size=$(sysctl -n hw.pagesize || echo "4096")

        pages_free=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
        pages_active=$(vm_stat | grep "Pages active" | awk '{print $3}' | tr -d '.')
        pages_inactive=$(vm_stat | grep "Pages inactive" | awk '{print $3}' | tr -d '.')
        pages_wired=$(vm_stat | grep "Pages wired down" | awk '{print $4}' | tr -d '.')

        free_mb=$(((pages_free * page_size) / 1024 / 1024))
        used_mb=$(((pages_active + pages_inactive + pages_wired) * page_size / 1024 / 1024))

        free_gb=$(printf "%.2f" "$(echo "scale=2; $free_mb/1024" | bc)")
        used_gb=$(printf "%.2f" "$(echo "scale=2; $used_mb/1024" | bc)")

        print_info "Mémoire totale" "${total_gb} Go (${total_mb} Mo)"
        print_info "Mémoire disponible" "${free_gb} Go (${free_mb} Mo)"
        print_info "Mémoire utilisée" "${used_gb} Go (${used_mb} Mo)"

        # Export variables
        MEM_TOTAL_GB="$total_gb"
        MEM_TOTAL_MB="$total_mb"
        MEM_AVAILABLE_GB="$free_gb"
        MEM_USED_GB="$used_gb"
    fi
}

# =============================================================================
# INFORMATIONS STOCKAGE
# =============================================================================

# Fonction pour convertir taille humaine en Go
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

get_storage_info() {
    print_header "INFORMATIONS STOCKAGE"

    if [[ "$OS" == "Linux" ]]; then
        echo -e "\n${YELLOW}Disques détectés :${NC}\n"

        # Variables pour agrégation
        local total_ssd_gb=0
        local total_hdd_gb=0
        local total_nvme_gb=0

        # Vérifier si lsblk est disponible
        if command -v lsblk &> /dev/null; then
            # Lister tous les disques (pas les partitions)
            while IFS= read -r line; do
                device=$(echo "$line" | awk '{print $1}')
                size=$(echo "$line" | awk '{print $2}')

                # Convertir la taille en Go
                size_gb=$(convert_to_gb "$size")

                # Ignorer les tailles nulles ou invalides
                if [[ $(echo "$size_gb > 0" | bc) -eq 1 ]]; then
                    # Déterminer si SSD ou HDD
                    rotational="1"
                    if [[ -f "/sys/block/$device/queue/rotational" ]]; then
                        rotational=$(cat "/sys/block/$device/queue/rotational" 2>/dev/null || echo "1")
                    fi

                    # Déterminer le type
                    if [[ "$device" == nvme* ]]; then
                        disk_type="NVMe SSD"
                        total_nvme_gb=$(echo "$total_nvme_gb + $size_gb" | bc)
                    elif [[ "$rotational" == "0" ]]; then
                        disk_type="SSD"
                        total_ssd_gb=$(echo "$total_ssd_gb + $size_gb" | bc)
                    else
                        disk_type="HDD"
                        total_hdd_gb=$(echo "$total_hdd_gb + $size_gb" | bc)
                    fi

                    echo -e "  ${GREEN}•${NC} /dev/$device : $size ($disk_type)"
                fi
            done < <(lsblk -ndo NAME,SIZE | grep -E '^(sd|nvme|vd|hd)')
        else
            print_error "lsblk n'est pas disponible - installation requise"
            return 1
        fi

        # Arrondir les totaux
        total_nvme_gb=$(printf "%.0f" "$total_nvme_gb")
        total_ssd_gb=$(printf "%.0f" "$total_ssd_gb")
        total_hdd_gb=$(printf "%.0f" "$total_hdd_gb")
        total_storage=$(echo "$total_nvme_gb + $total_ssd_gb + $total_hdd_gb" | bc)

        echo ""
        print_info "Total NVMe SSD" "${total_nvme_gb} Go"
        print_info "Total SSD" "${total_ssd_gb} Go"
        print_info "Total HDD" "${total_hdd_gb} Go"
        print_info "Capacité totale" "${total_storage} Go"

        # Export variables
        STORAGE_NVME_GB="$total_nvme_gb"
        STORAGE_SSD_GB="$total_ssd_gb"
        STORAGE_HDD_GB="$total_hdd_gb"
        STORAGE_TOTAL_GB="$total_storage"

    elif [[ "$OS" == "macOS" ]]; then
        echo -e "\n${YELLOW}Disques détectés :${NC}\n"

        local total_ssd_gb=0
        local total_hdd_gb=0

        # Lister tous les disques physiques
        while IFS= read -r disk; do
            # Extraire les infos du disque
            disk_info=$(diskutil info "$disk" 2>/dev/null)

            disk_name=$(echo "$disk_info" | grep "Device / Media Name:" | cut -d':' -f2 | xargs)
            disk_size=$(echo "$disk_info" | grep "Disk Size:" | cut -d':' -f2 | awk '{print $1, $2}' | xargs)
            solid_state=$(echo "$disk_info" | grep "Solid State:" | cut -d':' -f2 | xargs)

            # Convertir taille en Go
            size_gb=$(convert_to_gb "$disk_size")

            # Déterminer le type
            if [[ "$solid_state" == "Yes" ]]; then
                disk_type="SSD"
                total_ssd_gb=$(echo "$total_ssd_gb + $size_gb" | bc)
            else
                disk_type="HDD"
                total_hdd_gb=$(echo "$total_hdd_gb + $size_gb" | bc)
            fi

            echo -e "  ${GREEN}•${NC} $disk : $disk_size ($disk_type) - $disk_name"

        done < <(diskutil list | grep "^/dev/disk" | awk '{print $1}')

        # Arrondir les totaux
        total_ssd_gb=$(printf "%.0f" "$total_ssd_gb")
        total_hdd_gb=$(printf "%.0f" "$total_hdd_gb")
        total_storage=$(echo "$total_ssd_gb + $total_hdd_gb" | bc)

        echo ""
        print_info "Total SSD" "${total_ssd_gb} Go"
        print_info "Total HDD" "${total_hdd_gb} Go"
        print_info "Capacité totale" "${total_storage} Go"

        # Export variables
        STORAGE_NVME_GB="0"
        STORAGE_SSD_GB="$total_ssd_gb"
        STORAGE_HDD_GB="$total_hdd_gb"
        STORAGE_TOTAL_GB="$total_storage"
    fi
}

# =============================================================================
# EXPORT FORMATS
# =============================================================================

export_json() {
    cat <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "hostname": "$(hostname)",
  "os": "$OS",
  "cpu": {
    "model": "$CPU_MODEL",
    "physical_cores": $CPU_PHYSICAL_CORES,
    "threads": $CPU_THREADS
  },
  "memory": {
    "total_gb": $MEM_TOTAL_GB,
    "total_mb": $MEM_TOTAL_MB,
    "available_gb": $MEM_AVAILABLE_GB,
    "used_gb": $MEM_USED_GB
  },
  "storage": {
    "nvme_gb": $STORAGE_NVME_GB,
    "ssd_gb": $STORAGE_SSD_GB,
    "hdd_gb": $STORAGE_HDD_GB,
    "total_gb": $STORAGE_TOTAL_GB
  }
}
EOF
}

export_csv() {
    cat <<EOF
Timestamp,Hostname,OS,CPU_Model,CPU_Physical_Cores,CPU_Threads,Memory_Total_GB,Memory_Available_GB,Memory_Used_GB,Storage_NVMe_GB,Storage_SSD_GB,Storage_HDD_GB,Storage_Total_GB
$(date -u +"%Y-%m-%dT%H:%M:%SZ"),$(hostname),$OS,"$CPU_MODEL",$CPU_PHYSICAL_CORES,$CPU_THREADS,$MEM_TOTAL_GB,$MEM_AVAILABLE_GB,$MEM_USED_GB,$STORAGE_NVME_GB,$STORAGE_SSD_GB,$STORAGE_HDD_GB,$STORAGE_TOTAL_GB
EOF
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    local output_format="${1:-text}"

    # Vérifier la disponibilité de bc (requis pour calculs décimaux)
    if ! command -v bc &> /dev/null; then
        echo "Erreur: 'bc' n'est pas installé. Installation requise : apt-get install bc" >&2
        exit 1
    fi

    if [[ "$output_format" == "--json" ]]; then
        # Mode JSON - pas d'affichage coloré, juste récupération des données
        get_cpu_info > /dev/null
        get_memory_info > /dev/null
        get_storage_info > /dev/null
        export_json
    elif [[ "$output_format" == "--csv" ]]; then
        # Mode CSV
        get_cpu_info > /dev/null
        get_memory_info > /dev/null
        get_storage_info > /dev/null
        export_csv
    else
        # Mode texte avec affichage coloré
        echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║${NC}     ${YELLOW}INFORMATIONS SYSTÈME - $(hostname)${NC}     ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC}     ${YELLOW}OS: $OS${NC}                                   ${BLUE}║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"

        get_cpu_info
        get_memory_info
        get_storage_info

        echo -e "\n${GREEN}✓ Scan terminé${NC}\n"
        echo -e "${BLUE}💡 Astuce :${NC} Utilisez ${YELLOW}--json${NC} ou ${YELLOW}--csv${NC} pour exporter les données"
        echo -e "   Exemple : ${YELLOW}./system-info.sh --json > system.json${NC}\n"
    fi
}

# Exécution
main "$@"

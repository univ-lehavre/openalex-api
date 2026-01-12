#!/usr/bin/env bash
#
# Script de récupération des informations système
# Compatible : Linux, macOS
# Usage: ./system-info.sh [--json|--csv]
#

set -euo pipefail

# Couleurs pour l'affichage
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

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
    echo -e "${RED}✗${NC} $1"
}

# =============================================================================
# INFORMATIONS CPU
# =============================================================================

get_cpu_info() {
    print_header "INFORMATIONS CPU"

    if [[ "$OS" == "Linux" ]]; then
        # Linux - utilise lscpu et /proc/cpuinfo
        if command -v lscpu &> /dev/null; then
            cpu_model=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
            physical_cores=$(lscpu | grep "^Core(s) per socket:" | awk '{print $4}')
            sockets=$(lscpu | grep "^Socket(s):" | awk '{print $2}')
            threads_per_core=$(lscpu | grep "^Thread(s) per core:" | awk '{print $4}')

            total_physical_cores=$((physical_cores * sockets))
            total_threads=$((total_physical_cores * threads_per_core))
        else
            # Fallback avec /proc/cpuinfo
            cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
            total_threads=$(grep -c "^processor" /proc/cpuinfo)
            physical_cores=$(grep "^cpu cores" /proc/cpuinfo | head -1 | awk '{print $4}')
            total_physical_cores=$physical_cores
        fi

        print_info "Modèle CPU" "$cpu_model"
        print_info "Cœurs physiques" "$total_physical_cores"
        print_info "Threads (vCPUs)" "$total_threads"

        # Export variables pour JSON/CSV
        CPU_MODEL="$cpu_model"
        CPU_PHYSICAL_CORES="$total_physical_cores"
        CPU_THREADS="$total_threads"

    elif [[ "$OS" == "macOS" ]]; then
        # macOS - utilise sysctl
        cpu_model=$(sysctl -n machdep.cpu.brand_string)
        physical_cores=$(sysctl -n hw.physicalcpu)
        logical_cores=$(sysctl -n hw.logicalcpu)

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
        total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        total_mb=$((total_kb / 1024))
        total_gb=$(awk "BEGIN {printf \"%.2f\", $total_mb/1024}")

        available_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        available_mb=$((available_kb / 1024))
        available_gb=$(awk "BEGIN {printf \"%.2f\", $available_mb/1024}")

        used_mb=$((total_mb - available_mb))
        used_gb=$(awk "BEGIN {printf \"%.2f\", $used_mb/1024}")

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
        total_gb=$(awk "BEGIN {printf \"%.2f\", $total_mb/1024}")

        # vm_stat pour mémoire utilisée/disponible
        page_size=$(sysctl -n hw.pagesize)
        vm_stat_output=$(vm_stat)

        pages_free=$(echo "$vm_stat_output" | grep "Pages free" | awk '{print $3}' | tr -d '.')
        pages_active=$(echo "$vm_stat_output" | grep "Pages active" | awk '{print $3}' | tr -d '.')
        pages_inactive=$(echo "$vm_stat_output" | grep "Pages inactive" | awk '{print $3}' | tr -d '.')
        pages_wired=$(echo "$vm_stat_output" | grep "Pages wired down" | awk '{print $4}' | tr -d '.')

        free_mb=$(((pages_free * page_size) / 1024 / 1024))
        used_mb=$(((pages_active + pages_inactive + pages_wired) * page_size / 1024 / 1024))

        free_gb=$(awk "BEGIN {printf \"%.2f\", $free_mb/1024}")
        used_gb=$(awk "BEGIN {printf \"%.2f\", $used_mb/1024}")

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

get_storage_info() {
    print_header "INFORMATIONS STOCKAGE"

    if [[ "$OS" == "Linux" ]]; then
        # Linux - utilise lsblk pour déterminer le type de disque

        # Vérifier si lsblk est disponible
        if ! command -v lsblk &> /dev/null; then
            print_error "lsblk n'est pas disponible"
            return 1
        fi

        echo -e "\n${YELLOW}Disques détectés :${NC}\n"

        # Variables pour agrégation
        total_ssd_gb=0
        total_hdd_gb=0
        total_nvme_gb=0

        # Lister tous les disques (pas les partitions)
        while IFS= read -r line; do
            device=$(echo "$line" | awk '{print $1}')
            size=$(echo "$line" | awk '{print $4}')
            type=$(echo "$line" | awk '{print $6}')

            # Déterminer si SSD ou HDD
            rotational=$(cat /sys/block/"$device"/queue/rotational 2>/dev/null || echo "1")

            # Convertir la taille en Go
            size_gb=$(numfmt --from=iec --to-unit=G "$size" 2>/dev/null || echo "0")

            # Déterminer le type
            if [[ "$device" == nvme* ]]; then
                disk_type="NVMe SSD"
                total_nvme_gb=$(awk "BEGIN {print $total_nvme_gb + $size_gb}")
            elif [[ "$rotational" == "0" ]]; then
                disk_type="SSD"
                total_ssd_gb=$(awk "BEGIN {print $total_ssd_gb + $size_gb}")
            else
                disk_type="HDD"
                total_hdd_gb=$(awk "BEGIN {print $total_hdd_gb + $size_gb}")
            fi

            echo -e "  ${GREEN}•${NC} /dev/$device : $size ($disk_type)"

        done < <(lsblk -ndo NAME,SIZE,TYPE | grep disk)

        echo ""
        print_info "Total NVMe SSD" "${total_nvme_gb} Go"
        print_info "Total SSD" "${total_ssd_gb} Go"
        print_info "Total HDD" "${total_hdd_gb} Go"

        total_storage=$(awk "BEGIN {print $total_nvme_gb + $total_ssd_gb + $total_hdd_gb}")
        print_info "Capacité totale" "${total_storage} Go"

        # Export variables
        STORAGE_NVME_GB="$total_nvme_gb"
        STORAGE_SSD_GB="$total_ssd_gb"
        STORAGE_HDD_GB="$total_hdd_gb"
        STORAGE_TOTAL_GB="$total_storage"

    elif [[ "$OS" == "macOS" ]]; then
        # macOS - utilise diskutil

        echo -e "\n${YELLOW}Disques détectés :${NC}\n"

        total_ssd_gb=0
        total_hdd_gb=0

        # Lister tous les disques physiques
        while IFS= read -r disk; do
            # Extraire les infos du disque
            disk_info=$(diskutil info "$disk" 2>/dev/null)

            disk_name=$(echo "$disk_info" | grep "Device / Media Name:" | cut -d':' -f2 | xargs)
            disk_size=$(echo "$disk_info" | grep "Disk Size:" | cut -d':' -f2 | awk '{print $1, $2}' | xargs)
            protocol=$(echo "$disk_info" | grep "Protocol:" | cut -d':' -f2 | xargs)
            solid_state=$(echo "$disk_info" | grep "Solid State:" | cut -d':' -f2 | xargs)

            # Convertir taille en Go
            size_value=$(echo "$disk_size" | awk '{print $1}')
            size_unit=$(echo "$disk_size" | awk '{print $2}')

            if [[ "$size_unit" == "TB" ]]; then
                size_gb=$(awk "BEGIN {printf \"%.0f\", $size_value * 1024}")
            elif [[ "$size_unit" == "GB" ]]; then
                size_gb=$(awk "BEGIN {printf \"%.0f\", $size_value}")
            else
                size_gb=0
            fi

            # Déterminer le type
            if [[ "$solid_state" == "Yes" ]] || [[ "$protocol" == "PCI-Express" ]]; then
                disk_type="SSD"
                total_ssd_gb=$(awk "BEGIN {print $total_ssd_gb + $size_gb}")
            else
                disk_type="HDD"
                total_hdd_gb=$(awk "BEGIN {print $total_hdd_gb + $size_gb}")
            fi

            echo -e "  ${GREEN}•${NC} $disk : $disk_size ($disk_type) - $disk_name"

        done < <(diskutil list | grep "^/dev/disk" | awk '{print $1}')

        echo ""
        print_info "Total SSD" "${total_ssd_gb} Go"
        print_info "Total HDD" "${total_hdd_gb} Go"

        total_storage=$(awk "BEGIN {print $total_ssd_gb + $total_hdd_gb}")
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

#!/bin/bash
set -e

### ============================================
### BANLIST DOS DATASETS NÃO USADOS
### ============================================
BANLIST=(airlines aws-spot-pricing-market covtype poker-lsn)

### ============================================
### 0. Timestamp
### ============================================
TS=$(date +"%Y-%m-%d_%H-%M")
echo ">> Timestamp: $TS"

### ============================================
### 1. Configuração NUMA
### ============================================
NUMA_NODE=0

# Descobre memória total do nó NUMA (em GB)
NUMA_MEM_GB=$(numactl --hardware | awk "/node $NUMA_NODE size/ {print int(\$4/1024)}")

# Usar no máximo 85% da RAM do nó
MAX_HEAP_GB=$(( NUMA_MEM_GB * 85 / 100 ))

echo ">> NUMA node $NUMA_NODE com ${NUMA_MEM_GB}GB (heap máx: ${MAX_HEAP_GB}GB)"

### ============================================
### 2. Clonar o MOA
### ============================================
cd "$HOME"

if [ ! -d "moa" ]; then
    echo ">> Clonando MOA..."
    git clone https://github.com/pedrobiqua/moa.git
else
    echo ">> MOA já existente"
fi

cd moa
git fetch
git checkout exp/experiments-balancing

### ============================================
### 3. Compilar
### ============================================
echo ">> Compilando MOA..."
mvn clean package -DskipTests

JAR_FILE=$(ls moa/target/*.jar | head -n 1)
echo ">> JAR: $JAR_FILE"

### ============================================
### 4. Diretórios
### ============================================
DATASETS_DIR="$HOME/datasets"
OUTPUT_DIR="$HOME/output"

mkdir -p "$DATASETS_DIR" "$OUTPUT_DIR"

### ============================================
### 5. Processar datasets
### ============================================
echo ">> Iniciando experimentos..."

for arff in "$DATASETS_DIR"/*.arff; do
    [ -e "$arff" ] || break

    base=$(basename "$arff" .arff)

    if printf '%s\n' "${BANLIST[@]}" | grep -q "^$base$"; then
        echo ">> '$base' está na banlist. Pulando."
        continue
    fi

    echo ">> Dataset: $base"

    ### ----------------------------------------
    ### Cálculo dinâmico de RAM
    ### ----------------------------------------
    FILE_SIZE_GB=$(du -BG "$arff" | cut -f1 | tr -d 'G')

    # Heurística: 4x o tamanho do dataset
    HEAP_GB=$(( FILE_SIZE_GB * 4 ))

    # Limites
    [ "$HEAP_GB" -lt 4 ] && HEAP_GB=4
    [ "$HEAP_GB" -gt "$MAX_HEAP_GB" ] && HEAP_GB="$MAX_HEAP_GB"

    echo ">> Dataset ${FILE_SIZE_GB}GB → Heap ${HEAP_GB}GB"

    OUTPUT_MAIN="$OUTPUT_DIR/${base}_insert_search_${TS}.csv"

    TASK="ExperimentoTempos \
        -s (ArffFileStream -f $arff) \
        -o $OUTPUT_MAIN"

    ### ----------------------------------------
    ### Execução Java NUMA-aware
    ### ----------------------------------------
    numactl --cpunodebind=$NUMA_NODE --membind=$NUMA_NODE \
    java \
        -Xms${HEAP_GB}g \
        -Xmx${HEAP_GB}g \
        -XX:+UseG1GC \
        -XX:+AlwaysPreTouch \
        -XX:+UseNUMA \
        -cp "$JAR_FILE" \
        moa.DoTask "$TASK"

    echo ">> Resultado: $OUTPUT_MAIN"
done

echo ">> Finalizado."

#!/bin/bash
set -e

### ESSE SCRIPT USA O JAVA 21 COMO PADRÃO
### BANLIST DOS DATASETS NÃO USADOS
# OK: airlines aws-spot-pricing-market covtype
# pklot_512 poker-lsn tcp-sync tcp_sync_sem_timestamp
BANLIST=(aws-spot-pricing-market pklot_512 tcp-sync) # BLOQUEADOS
# N específico por dataset | USADO NO RAM HOURS
declare -A DATASET_N=(
    [airlines]=10000
    [covtype]=10000
    [poker-lsn]=10000
    [tcp_sync_sem_timestamp]=1000
)

# valor padrão caso não esteja no dicionário
DEFAULT_N=1000


TS=$(date +"%Y-%m-%d_%H-%M")
echo ">> Timestamp: $TS"

NUMA_NODE=0

NUMA_MEM_GB=$(numactl --hardware | awk "/node $NUMA_NODE size/ {print int(\$4/1024)}")
MAX_HEAP_GB=$(( NUMA_MEM_GB * 85 / 100 ))

echo ">> NUMA node $NUMA_NODE com ${NUMA_MEM_GB}GB (heap máx: ${MAX_HEAP_GB}GB)"

cd "$HOME"

# if [ ! -d "moa" ]; then
#     echo ">> Clonando MOA..."
#     git clone https://github.com/pedrobiqua/moa.git
# else
#     echo ">> MOA já existente"
# fi

cd Projetos/moa
git fetch
git checkout exp/experiments-balancing

echo ">> Compilando MOA..."
mvn clean package -DskipTests

JAR_FILE=$(ls moa/target/*.jar | head -n 1)
echo ">> JAR: $JAR_FILE"

DATASETS_DIR="$HOME/Datasets"
OUTPUT_DIR="$HOME/output"

mkdir -p "$DATASETS_DIR" "$OUTPUT_DIR"

echo ">> Iniciando experimentos..."

for arff in "$DATASETS_DIR"/*.arff; do
    [ -e "$arff" ] || break

    base=$(basename "$arff" .arff)

    if printf '%s\n' "${BANLIST[@]}" | grep -q "^$base$"; then
        echo ">> '$base' está na banlist. Pulando."
        continue
    fi

    echo ">> Dataset: $base"
    if [[ -n "${DATASET_N[$base]}" ]]; then
        N_VALUE=${DATASET_N[$base]}
    else
        N_VALUE=$DEFAULT_N
    fi

    # AQUI FAÇO A SEPARAÇÃO DEFININDO O TAMANHO QUE O JAVA VAI ALOCAR DE MIN E MAX
    FILE_SIZE_GB=$(du -BG "$arff" | cut -f1 | tr -d 'G')
    HEAP_GB=$(( FILE_SIZE_GB * 4 ))

    [ "$HEAP_GB" -lt 4 ] && HEAP_GB=4
    [ "$HEAP_GB" -gt "$MAX_HEAP_GB" ] && HEAP_GB="$MAX_HEAP_GB"

    echo ">> Dataset ${FILE_SIZE_GB}GB → Heap ${HEAP_GB}GB"

    OUTPUT_MAIN="$OUTPUT_DIR/${base}_insert_search_${TS}.csv"

    TASK="ExperimentoTempos \
        -s (ArffFileStream -f $arff) \
        -n $N_VALUE \
        -o $OUTPUT_MAIN"

    # CONFIGURAÇÃO APLICADA DO NUMA E PARAMETROS DO JAVA
    numactl --cpunodebind=$NUMA_NODE --membind=$NUMA_NODE \
        java \
        -Xms${HEAP_GB}g \
        -Xmx${HEAP_GB}g \
        -XX:+UseParallelGC \
        -XX:+AlwaysPreTouch \
        -XX:MetaspaceSize=1g \
        -XX:MaxMetaspaceSize=2g \
        -XX:+UseNUMA \
        -cp "$JAR_FILE" \
        moa.DoTask "$TASK"

    echo ">> Resultado: $OUTPUT_MAIN"
done

echo ">> Finalizado."

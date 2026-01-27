#!/usr/bin/env bash

# Autor      : Pedro Bianchini de Quadros <pedro.bianchini@ufpr.br>
# Licença    : GNU/GPL v3.0
# Data       : seg 26 jan 2026 12:17:25 -03
# Experimento: Insert e Search na KDTREE com DADOS SINTETICOS!
# Descrição  : O Experimento realiza a inserção na árvore e depois executa a busca
#              coletando metricas de tempo, altura da árvore e afins

## VARIAVEIS E CONFIGURAÇÕES
TS=$(date +"%Y-%m-%d_%H-%M")
OUTPUT_DIR="$HOME/Output/$TS"
NUM_INSTANCIAS=500000 # Para cada stream sintetica
NUMA_NODE=0
# NUMA_MEM_GB=$(numactl --hardware | awk "/node $NUMA_NODE size/ {print int(\$4/1024)}")
# MAX_HEAP_GB=$(( NUMA_MEM_GB * 85 / 100 ))

echo "NUMA node $NUMA_NODE com ${NUMA_MEM_GB}GB (heap máx: ${MAX_HEAP_GB}GB)"
cd "$HOME"
mkdir -p "$OUTPUT_DIR"

# Clonar o moa e colocar na branch dos experimentos
if [ ! -d "moa" ]; then
    echo ">> Clonando MOA..."
    git clone https://github.com/pedrobiqua/moa.git
else
    echo ">> MOA já existente"
fi

# cd /home/pedro/projects/moa
cd moa
git fetch
git checkout exp/experiments-balancing


## Compilar
echo ">> Compilando MOA..."
mvn clean package -DskipTests

JAR_FILE=$(ls moa/target/*.jar | head -n 1)
echo ">> JAR: $JAR_FILE"

echo ">> Iniciando experimentos..."

## Rodar o experimento com os parametros certos
### Usar a classe com os parametros certos e executar
### No java ele já coloca o nome certinho, é só executar, vou copiar para montar

OUTPUT_MAIN="$OUTPUT_DIR/temp.csv" # Coloco assim, mas no java eu troco o nome

## -e 0 é o experimento de insert e search
## -e 1 é o experimento da janela deslizante
TASK="ExperimentosSKDtree \
    -o $OUTPUT_MAIN \
    -b \
    -t $NUM_INSTANCIAS \
    -e 0
    "

# CONFIGURAÇÃO APLICADA DO NUMA E PARAMETROS DO JAVA
numactl --cpunodebind=$NUMA_NODE --membind=$NUMA_NODE \
    java \
    -XX:+UseParallelGC \
    -XX:+AlwaysPreTouch \
    -XX:MetaspaceSize=1g \
    -XX:MaxMetaspaceSize=2g \
    -XX:+UseNUMA \
    -cp "$JAR_FILE" \
    moa.DoTask "$TASK"
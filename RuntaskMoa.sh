#!/usr/bin/env bash
# Autor      : Pedro Bianchini de Quadros <pedro.bianchini@ufpr.br>
# Licença    : GNU/GPL v3.0
# Data       : qua 04 fev 2026 14:54:18 -03
# Experimento:
# Descrição  : Executa uma Task do MOA

### MODIFICAR DE ACORDO COM O TESTE
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
OUTPUT_DIR="$HOME/Output/$TIMESTAMP"
mkdir -p $OUTPUT_DIR
NUMA_NODE=0

### Pegando do meu repositorio local
# cd /home/pedro/projects/moa

### Pegando do GIT
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

count=`ls -1 moa/target/*.jar 2>/dev/null | wc -l`
if [ ! $count != 0 ]; then
    ## Compilar
    echo ">> Compilando MOA..."
    mvn clean package -DskipTests
fi


JAR_FILE=$(ls moa/target/*.jar | head -n 1)
echo ">> JAR: $JAR_FILE"
echo ">> Iniciando experimentos..."

TASK="ExperimentosKDtreeMOA \
    -o $OUTPUT_DIR/STAGGERG1GComJITAquecendoServer.csv \
    "

numactl --cpunodebind=$NUMA_NODE --membind=$NUMA_NODE \
    java \
    -cp "$JAR_FILE" \
    moa.DoTask "$TASK"

exit 0


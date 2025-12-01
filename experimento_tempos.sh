#!/bin/bash
set -e

### ============================================
### 0. Timestamp | Para organizar os experimentos
### ============================================
TS=$(date +"%Y-%m-%d_%H-%M")
echo ">> Timestamp: $TS"

### ============================================
### 1. Clonar o MOA na HOME
### ============================================
cd "$HOME"

if [ ! -d "moa" ]; then
    echo ">> Clonando MOA..."
    git clone https://github.com/pedrobiqua/moa.git
else
    echo ">> MOA já existente, usando diretório ~/moa"
fi

cd moa
git fetch
git checkout exp/experiments-balancing

### ============================================
### 2. Compilar
### ============================================
echo ">> Compilando o MOA..."
mvn clean package -DskipTests

JAR_FILE=$(ls moa/target/*.jar | head -n 1)

echo ">> JAR encontrado: $JAR_FILE"

### ============================================
### 3. Definir diretórios obrigatórios
### ============================================
DATASETS_DIR="$HOME/datasets"
OUTPUT_DIR="$HOME/output"

mkdir -p "$DATASETS_DIR"
mkdir -p "$OUTPUT_DIR"

BANLIST=(pokerhand)

### ============================================
### 4. Processar datasets
### ============================================
echo ">> Iniciando processamento dos datasets..."

for arff in "$DATASETS_DIR"/*.arff; do
    [ -e "$arff" ] || { echo "Nenhum .arff encontrado em $DATASETS_DIR"; break; }

    base=$(basename "$arff" .arff)

    # Banlist
    if printf '%s\n' "${BANLIST[@]}" | grep -q "^$base$"; then
        echo ">> Dataset '$base' está na banlist. Pulando..."
        continue
    fi

    echo ">> Rodando MOA no dataset: $base"

    OUTPUT_MAIN="$OUTPUT_DIR/${base}_insert_search_${TS}.csv"

    TASK="ExperimentoTempos \
        -s (ArffFileStream -f $arff) \
        -o $OUTPUT_MAIN"

    java -cp "$JAR_FILE" moa.DoTask "$TASK"

    echo "Resultados salvos:"
    echo "    - $OUTPUT_MAIN"
done

echo ">> Finalizado!"

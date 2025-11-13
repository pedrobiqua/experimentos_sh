#!/bin/bash

set -euo pipefail

# === FUNÇÕES AUXILIARES ===
log() { echo "[$(date +"%H:%M:%S")] $*"; }
erro() { echo "[ERRO] $*" >&2; exit 1; }

# === VERIFICA DEPENDÊNCIAS ===
log "Verificando dependências: Java e Maven..."

check_dep() {
  local cmd="$1"
  local nome="$2"
  if ! command -v "$cmd" &>/dev/null; then
    erro "Dependência ausente: $nome ($cmd). Instale antes de continuar."
  fi
  log "$nome encontrado: $(command -v "$cmd")"
}

check_dep "java" "Java"
check_dep "mvn" "Maven"

# Verifica versão do Java (somente 17 ou 21 aceitos)
JAVA_VERSION_RAW=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
JAVA_MAJOR=$(echo "$JAVA_VERSION_RAW" | awk -F. '{print $1}')

log "Versão do Java detectada: $JAVA_VERSION_RAW"

if [[ "$JAVA_MAJOR" != "17" && "$JAVA_MAJOR" != "21" ]]; then
  erro "Versão do Java incompatível: $JAVA_MAJOR. É necessário usar Java 17 ou 21."
fi

log " Versão do Java compatível ($JAVA_MAJOR)"



# === CONFIGURAÇÕES ===
PROJECTS_DIR="~/projects"
PROJETO_DIR="~/projects/moa/moa"
SAIDA_DIR="~/projects/analise_kdtree_dados"
IMG_DIR="$SAIDA_DIR/imagens"
DATA=$(date +"%Y-%m-%d_%H-%M-%S")
ARQUIVO_SAIDA="$SAIDA_DIR/output_$DATA.csv"
CAMINHO_DATASETS="~/projects/moa/moa/src/test/resources/moa/classifiers/data"

GERAR_IMGS=false
GERAR_GRAFICOS=false  # padrão: não gera gráficos

# === TRATAMENTO DE ARGUMENTOS ===
for arg in "$@"; do
  case $arg in
    --gerar_imgs)
      GERAR_IMGS=true
      ;;
    --gerar_graficos)
      GERAR_GRAFICOS=true
      ;;
  esac
done

trap 'erro "O script falhou na linha $LINENO."' ERR

# === EXPANDE CAMINHOS (~ não expande automaticamente em variáveis) ===
PROJECTS_DIR=$(eval echo "$PROJECTS_DIR")
PROJETO_DIR=$(eval echo "$PROJETO_DIR")
SAIDA_DIR=$(eval echo "$SAIDA_DIR")
IMG_DIR=$(eval echo "$IMG_DIR")
ARQUIVO_SAIDA=$(eval echo "$ARQUIVO_SAIDA")
CAMINHO_DATASETS=$(eval echo "$CAMINHO_DATASETS")

# === VERIFICA DIRETÓRIO DO PROJETO ===
if [ ! -d "$PROJETO_DIR" ]; then
  mkdir -p "$PROJECTS_DIR"
  cd "$PROJECTS_DIR"
  log "Projeto MOA não encontrado. Clonando do GitHub..."
  git clone https://github.com/pedrobiqua/moa.git
fi

cd "$PROJETO_DIR"
log "Trocando para branch exp/experiments-balancing..."
git fetch
git checkout exp/experiments-balancing || git checkout -b exp/experiments-balancing origin/exp/experiments-balancing

# === CRIA PASTAS DE SAÍDA ===
mkdir -p "$SAIDA_DIR" "$IMG_DIR"

# === ATIVA AMBIENTE E INSTALA GDOWN ===
echo "🔹 Ativando ambiente pedro_env..."
source ~/anaconda3/etc/profile.d/conda.sh
conda activate pedro_env

echo "📦 Verificando gdown..."
pip install --upgrade gdown

# === BAIXA OS DATASETS ===
declare -A FILES=(
    ["https://drive.google.com/uc?id=1N7h_G8mkKFmSqfb7SHSTs6WZVcpiwNeK"]="aws-spot-pricing-market.tar.gz"
    ["https://drive.google.com/uc?id=12oHdE8ST30r9qhBYTXoJQaTU5rZWdLki"]="pklot_512.tar.gz"
)

log "🔹 Verificando datasets..."
mkdir -p "$CAMINHO_DATASETS"

for URL in "${!FILES[@]}"; do
    FILENAME="${FILES[$URL]}"
    DEST="$CAMINHO_DATASETS/$FILENAME"
    EXTRACTED_NAME="${FILENAME%%.*}"  # nome base (sem .tar.gz, .zip, etc.)

    # Verifica se já existe arquivo ou diretório extraído
    if [ -f "$DEST" ] || [ -d "$CAMINHO_DATASETS/$EXTRACTED_NAME" ]; then
        log "⚙️  Dataset $FILENAME já existe, pulando download."
        continue
    fi

    log "⬇️  Baixando $URL -> $DEST ..."
    gdown "$URL" -O "$DEST" || { log "❌ Falha ao baixar $URL"; exit 1; }

    # Descompacta se necessário
    if [[ "$DEST" == *.tar.gz ]]; then
        log "📦 Extraindo $FILENAME ..."
        tar -xzf "$DEST" -C "$CAMINHO_DATASETS"
    elif [[ "$DEST" == *.zip ]]; then
        log "📦 Extraindo $FILENAME ..."
        unzip -q "$DEST" -d "$CAMINHO_DATASETS"
    fi
done

log "✅ Verificação e preparação dos datasets concluída!"

# === COMPILAÇÃO ===
log "Compilando o projeto..."
mvn -q test-compile

log "Gerando classpath de runtime..."
mvn -q dependency:build-classpath -DincludeScope=runtime -Dmdep.outputFile=cp.txt
CP=$(cat cp.txt):target/classes:target/test-classes

# === EXECUÇÃO DO EXPERIMENTO ===
log "Executando experimento Java..."
java -Xms2G -Xmx6G -cp "$CP" moa.TestKdTree 0 > "$ARQUIVO_SAIDA"

log "Experimento concluído!"
log "Saída CSV: $ARQUIVO_SAIDA"

# === FINAL ===
log "Processo finalizado com sucesso!"
echo
echo "📄 CSV: file://$ARQUIVO_SAIDA"
echo "🖼️ Imagens: file://$IMG_DIR"
echo "📊 Gráficos (se gerados): file://$SAIDA_DIR/graficos"

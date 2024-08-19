#!/bin/sh

# Diretório base onde os temporizadores serão salvos
BASE_DIR="./timers"

# Variáveis globais
ACTIVITY=""
ACTIVITY_DIR=""
FILE=""
ACCU_FILE=""

# Função para atribuir valor à variável global
_set_environment() {
  ACTIVITY="$1"
  ACTIVITY_DIR="$BASE_DIR/$ACTIVITY"
  FILE="$ACTIVITY_DIR/timer_timestamp.txt"
  ACCU_FILE="$ACTIVITY_DIR/timer_accumulated.txt"

  # Cria o diretório da atividade se não existir
  mkdir -p "$ACTIVITY_DIR"

#  printf "ACTIVITY: $ACTIVITY\nACTIVITY_DIR: $ACTIVITY_DIR\nFILE: $FILE\nACCU_FILE: $ACCU_FILE\n"
}

# Função para formatar o tempo
format_time() {
    local total_seconds=$1
    local hours=$(($total_seconds / 3600))
    local minutes=$((($total_seconds % 3600) / 60))
    local seconds=$(($total_seconds % 60))
    echo "$hours hora(s), $minutes minuto(s) e $seconds segundo(s)"
}

# Função que converte hora no formato "hh:MM" para timestamp Unix
get_timestamp_from_time() {
    local time="$1"  # Recebe o horário como parâmetro
    local today=$(date +%Y-%m-%d)  # Data de hoje
    local timestamp

    # Tentar GNU date primeiro
    timestamp=$(date -d "$today $time" +%s 2>/dev/null)

    # Se falhar, tentar BSD date
    if [ -z "$timestamp" ]; then
        timestamp=$(date -j -f "%Y-%m-%d %H:%M" "$today $time" +%s 2>/dev/null)
    fi

    # Checar se o timestamp foi gerado com sucesso
    if [ -z "$timestamp" ]; then
        echo "Erro ao converter a hora para timestamp."
        return 1
    else
        echo $timestamp
    fi
}

# Função para iniciar ou continuar o timer
start_timer() {
    _set_environment "$1"

    local start_time="$2"
    if [ -f "$ACCU_FILE" ]; then
       accumulated_seconds=$(cat "$ACCU_FILE")
       echo "Tempo total acumulado até agora: $(format_time $accumulated_seconds)"
       echo "Se desejar zerar o cronômetro, execute o comando 'stop'"
    else
       echo "0" > "$ACCU_FILE"
    fi

    if [ -z "$start_time" ]; then
        date +%s > "$FILE"
        echo "Cronômetro iniciado às $(date "+%H:%M:%S")"
    else
        timestamp=$(get_timestamp_from_time "$start_time")
        if [ -z "$timestamp" ]; then
            echo "Falha ao obter o timestamp para $start_time."
        else
            echo "$timestamp" > "$FILE"
            echo "Cronômetro programado para iniciar às $start_time"
        fi
    fi
}

# Função para pausar o timer e acumular o tempo
_pause_timer() {
    if [ ! -f "$FILE" ]; then
        echo "Primeiro é necessário iniciar o cronômetro, usando o comando 'start'"
        exit 1
    fi

    start_time=$(cat "$FILE")
    current_time=$(date +%s)
    elapsed_seconds=$((current_time - start_time))

    if [ -f "$ACCU_FILE" ]; then
        accumulated_seconds=$(cat "$ACCU_FILE")
    else
        accumulated_seconds=0
    fi
    new_accumulated_seconds=$((accumulated_seconds + elapsed_seconds))
    echo "$new_accumulated_seconds" > "$ACCU_FILE"
    rm "$FILE"  # Deleta o arquivo de timestamp, para impedir que pause novamente sem antes atualizar o arquivo de timestamp
}

# Função para pausar o timer e acumular o tempo
pause_timer() {
    _set_environment "$1"
    _pause_timer
    echo "Cronômetro pausado às $(date "+%H:%M:%S")"
    echo "Tempo total acumulado até agora: $(format_time $new_accumulated_seconds)"
    echo "Para retomar o tempo de onde parou, execute o comando 'start'"
}

# Função para verificar o tempo total acumulado até agora sem pausar
check_timer() {
    _set_environment "$1"
    if [ ! -f "$FILE" ] && [ -f "$ACCU_FILE" ];then
        total_seconds=$(cat "$ACCU_FILE")
        echo "Tempo total acumulado até agora: $(format_time $total_seconds)"
        exit 1
    fi

    if [ -f "$FILE" ] && [ -f "$ACCU_FILE" ];then
        accumulated_seconds=$(cat "$ACCU_FILE")
        start_time=$(cat "$FILE")
        current_time=$(date +%s)
        elapsed_seconds=$((current_time - start_time))
        total_seconds=$((accumulated_seconds + elapsed_seconds))
        echo "Tempo total acumulado até agora: $(format_time $total_seconds)"
        exit 1
    else
        echo "Primeiro é necessário iniciar o cronômetro, usando o comando 'start'"
        exit 1
    fi
}

# Função para parar o timer e calcular o tempo total passado
stop_timer() {
    _set_environment "$1"
    _pause_timer  # Chama a função de pausar para atualizar o tempo acumulado
    accumulated_seconds=$(cat "$ACCU_FILE")
    echo "Cronômetro parado às $(date "+%H:%M:%S")"
    echo "Tempo total: $(format_time $accumulated_seconds)"
    rm -Rf "$ACTIVITY_DIR"  # Limpa os arquivos para reiniciar o processo
}

# Verifica o primeiro argumento passado para o script
case "$1" in
    start)
        # Verifica se um segundo argumento (hh:MM) foi passado para o comando start
        start_timer "$2" "$3"
        ;;
    pause)
        pause_timer "$2"
        ;;
    check)
        check_timer "$2"
        ;;
    stop)
        stop_timer "$2"
        ;;
    *)
        echo "Uso: $0 {start|pause|check|stop} <nome_da_atividade> [hh:MM para start]"
        exit 1
        ;;
esac

#!/bin/bash

# Caminho do arquivo onde o timestamp e o tempo acumulado serão salvos
FILE=".timer_timestamp.txt"
ACCU_FILE=".timer_accumulated.txt"

# Função para formatar o tempo
format_time() {
    local total_seconds=$1
    local hours=$(($total_seconds / 3600))
    local minutes=$((($total_seconds % 3600) / 60))
    local seconds=$(($total_seconds % 60))
    echo "$hours hora(s), $minutes minuto(s) e $seconds segundo(s)"
}

# Função para iniciar ou continuar o timer
start_timer() {
    if [ -f "$ACCU_FILE" ]; then
       accumulated_seconds=$(cat "$ACCU_FILE")
       echo "Tempo total acumulado até agora: $(format_time $accumulated_seconds)"
       echo "Se desejar zerar o cronômetro, execute o comando 'stop'"
    else
       echo "0" > "$ACCU_FILE"
    fi

    date +%s > "$FILE"
    echo "Cronômetro iniciado às $(date "+%H:%M:%S")"
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
    _pause_timer
    echo "Cronômetro pausado às $(date "+%H:%M:%S")"
    echo "Tempo total acumulado até agora: $(format_time $new_accumulated_seconds)"
    echo "Para retomar o tempo de onde parou, execute o comando 'start'"
}

# Função para verificar o tempo total acumulado até agora sem pausar
check_timer() {
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
    _pause_timer  # Chama a função de pausar para atualizar o tempo acumulado
    accumulated_seconds=$(cat "$ACCU_FILE")
    echo "Cronômetro parado às $(date "+%H:%M:%S")"
    echo "Tempo total: $(format_time $accumulated_seconds)"
    rm "$ACCU_FILE"  # Limpa os arquivos para reiniciar o processo
}

# Verifica o primeiro argumento passado para o script
case "$1" in
    start)
        start_timer
        ;;
    pause)
        pause_timer
        ;;
    check)
        check_timer
        ;;
    stop)
        stop_timer
        ;;
    *)
        echo "Uso: $0 {start|pause|check|stop}"
        exit 1
        ;;
esac

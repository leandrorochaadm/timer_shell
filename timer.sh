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
#    local seconds=$(($total_seconds % 60))

#    local hours_total=$(echo "scale=4; $total_seconds /3600" | bc)
    local minutes_total=$(echo "scale=2; $total_seconds / 60" | bc)
    local money=$(echo "scale=2; $minutes_total * (36.8 / 60)" | bc)

    echo "$hours horas $minutes minutos ou $minutes_total minutos = R$ $money"
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

# Função para pausar todas as atividades ativas
pause_all_other_activities() {
    for dir in "$BASE_DIR"/*; do
        if [ -d "$dir" ] && [ -f "$dir/timer_timestamp.txt" ]; then
            activity_name=$(basename "$dir")
            echo "Pausando atividade: $activity_name"
            _set_environment "$activity_name"
            _pause_timer
        fi
    done
}

# Função para iniciar ou continuar o timer
start_timer() {

    # Pausar todas as outras atividades ativas
    pause_all_other_activities

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
        echo "Atividade $ACTIVITY iniciada às $(date "+%H:%M:%S")"
    else
        timestamp=$(get_timestamp_from_time "$start_time")
        if [ -z "$timestamp" ]; then
            echo "Falha ao obter o timestamp para $start_time."
        else
            echo "$timestamp" > "$FILE"
             echo "Atividade $ACTIVITY iniciada às $start_time"
        fi
    fi
}

# Função para pausar o timer e acumular o tempo
_pause_timer() {
    if [ ! -f "$FILE" ]; then
#        echo "Nenhum cronômetro em execução para a atividade '$ACTIVITY'."
        return  # Sai da função sem interromper o script
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
    echo "Atividade $ACTIVITY finalizada às $(date "+%H:%M:%S")"
    echo "Tempo total: $(format_time $accumulated_seconds)"
    rm -rf "$ACTIVITY_DIR"  # Limpa os arquivos para reiniciar o processo
}

# Função para parar todas as atividades existentes
stop_all_activities() {
    for dir in "$BASE_DIR"/*; do
        if [ -d "$dir" ]; then
            activity_name=$(basename "$dir")
            stop_timer "$activity_name"
            echo "---------------------------"
        fi
    done
}

# Função para parar todas as atividades existentes com confirmação do usuário
confirm_and_stop_all_activities() {
    echo "Você realmente deseja finalizar todas as atividades? (s/n)"
    read -r confirmation
    if [ "$confirmation" = "s" ]; then
        stop_all_activities
        echo "Todas as atividades foram finalizadas."
    else
        echo "Nenhuma atividade foi finalizada."
    fi
}

# Função para parar todas as atividades existentes com confirmação do usuário
confirm_and_stop_activity() {
   _set_environment "$1"
    echo "Você realmente deseja finalizar a atividade $ACTIVITY? (s/n)"
    read -r confirmation
    if [ "$confirmation" = "s" ]; then
        stop_timer $ACTIVITY
#        echo "Todas as atividades foram finalizadas."
    else
        echo "A atividade $ACTIVITY não foi finalizada."
    fi
}

# Função para verificar qual atividade está ativa
active_activity() {
    for dir in "$BASE_DIR"/*; do
        if [ -d "$dir" ] && [ -f "$dir/timer_timestamp.txt" ]; then
            activity_name=$(basename "$dir")
            echo "Atividade ativa: $activity_name"
            return
        fi
    done
    echo "Nenhuma atividade está ativa no momento."
}

# Função para abrir o navegador no link especificado
open_browser() {
    local issue_number="$1"
    local url="https://softohq.atlassian.net/browse/ENDFAAPP-$issue_number"

    # Abrir o navegador
    if command -v xdg-open > /dev/null; then
        xdg-open "$url"  # Para sistemas Linux
    elif command -v open > /dev/null; then
        open "$url"  # Para macOS
    else
        echo "Não foi possível detectar o comando para abrir o navegador."
        exit 1
    fi
}

# Função para listar todas as atividades e seus respectivos tempos acumulados e cronômetros
list_all_activities() {
    local total_time=0

    for dir in "$BASE_DIR"/*; do
        if [ -d "$dir" ]; then
            activity_name=$(basename "$dir")

            _set_environment "$activity_name"

            if [ -f "$ACCU_FILE" ]; then
                accumulated_seconds=$(cat "$ACCU_FILE")
            else
                accumulated_seconds=0
            fi

            if [ -f "$FILE" ]; then
                start_time=$(cat "$FILE")
                current_time=$(date +%s)
                elapsed_seconds=$((current_time - start_time))
                total_seconds=$((accumulated_seconds + elapsed_seconds))
            else
                total_seconds=$accumulated_seconds
            fi

            echo "Atividade: $activity_name | Tempo: $(format_time $total_seconds)"
            echo "---------------------------"

            # Somando o tempo total de todas as atividades
            total_time=$((total_time + total_seconds))
        fi
    done

    # Exibindo o somatório de todas as atividades
    echo "Tempo total de todas as atividades: $(format_time $total_time)"
}



# Verifica o primeiro argumento passado para o script
case "$1" in
    s)
        # Verifica se um segundo argumento (hh:MM) foi passado para o comando start
        start_timer "$2" "$3"
        ;;
    p)
        pause_timer "$2"
        ;;
    c)
        check_timer "$2"
        ;;
    fa)
        confirm_and_stop_all_activities
        ;;
    f)
        confirm_and_stop_activity "$2"
        ;;
    a)
        active_activity
        ;;
    o)
        open_browser "$2"
        ;;
    l)
        list_all_activities
        ;;
    *)
        echo "Uso: $0 {start|pause|check|stop|active|open} <nome_da_atividade> [hh:MM para start]"
        exit 1
        ;;
esac

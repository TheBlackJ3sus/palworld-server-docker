#!/bin/bash

if [[ ! "${PUID}" -eq 0 ]] && [[ ! "${PGID}" -eq 0 ]]; then
    printf "\e[0;32m%s\e[0m\n" "*****EXECUTING USERMOD*****"
    usermod -o -u "${PUID}" steam
    groupmod -o -g "${PGID}" steam
else
    printf "\033[31m%s\n" "Running as root is not supported, please fix your PUID and PGID!"
    exit 1
fi

mkdir -p /palworld/backups
chown -R steam:steam /palworld /home/steam/

# shellcheck disable=SC2317
term_handler() {
    if [ -n "${DISCORD_WEBHOOK_ID}" ] && [ -n "${DISCORD_PRE_SHUTDOWN_MESSAGE}" ]; then
        su steam -c "discord -i $DISCORD_WEBHOOK_ID -c $DISCORD_CONNECT_TIMEOUT -M $DISCORD_MAX_TIMEOUT -m '$DISCORD_PRE_SHUTDOWN_MESSAGE' -l in-progress" &
    fi

    if [ "${RCON_ENABLED,,}" = true ]; then
        rcon-cli save
        rcon-cli "shutdown 1"
    else # Does not save
        kill -SIGTERM "$(pidof PalServer-Linux-Test)"
    fi

    tail --pid="$killpid" -f 2>/dev/null
}

trap 'term_handler' SIGTERM

su steam -c ./start.sh &
# Process ID of su
killpid="$!"
wait "$killpid"

mapfile -t backup_pids < <(pgrep backup)
if [ "${#backup_pids[@]}" -ne 0 ]; then
    echo "Waiting for backup to finish"
    for pid in "${backup_pids[@]}"; do
        tail --pid="$pid" -f 2>/dev/null
    done
fi

mapfile -t restore_pids < <(pgrep restore)
if [ "${#restore_pids[@]}" -ne 0 ]; then
    echo "Waiting for restore to finish"
    for pid in "${restore_pids[@]}"; do
        tail --pid="$pid" -f 2>/dev/null
    done
fi

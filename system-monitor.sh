#!/usr/bin/env bash

set -u

read_cpu() {
    local cpu user nice system idle iowait irq softirq steal guest guest_nice
    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    local idle_all=$((idle + iowait))
    local total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    printf '%s\t%s\n' "$idle_all" "$total"
}

first="$(read_cpu)"
IFS=$'\t' read -r idle1 total1 <<< "$first"
sleep 0.12
second="$(read_cpu)"
IFS=$'\t' read -r idle2 total2 <<< "$second"

delta_total=$((total2 - total1))
delta_idle=$((idle2 - idle1))
if (( delta_total > 0 )); then
    cpu_percent=$(( (100 * (delta_total - delta_idle) + delta_total / 2) / delta_total ))
else
    cpu_percent=0
fi

mem_total="$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo)"
mem_available="$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo)"
mem_total="${mem_total:-0}"
mem_available="${mem_available:-0}"
mem_used=$((mem_total > mem_available ? mem_total - mem_available : 0))

zram_total=0
zram_used=0
if [[ -r /proc/swaps ]]; then
    while read -r name type size used priority; do
        [[ "$name" == /dev/zram* ]] || continue
        zram_total=$((zram_total + size))
        zram_used=$((zram_used + used))
    done < <(tail -n +2 /proc/swaps 2>/dev/null)
fi

# Some systems expose zram but do not currently use it as swap. Still show its
# configured logical size so the compact view does not misleadingly say 0 B.
if (( zram_total == 0 )); then
    for dev in /sys/block/zram*; do
        [[ -d "$dev" ]] || continue
        if [[ -r "$dev/disksize" ]]; then
            bytes="$(cat "$dev/disksize" 2>/dev/null || printf 0)"
            [[ "$bytes" =~ ^[0-9]+$ ]] || bytes=0
            zram_total=$((zram_total + bytes / 1024))
        fi
        if [[ -r "$dev/mm_stat" ]]; then
            read -r orig_data_size _ < "$dev/mm_stat" || true
            [[ "${orig_data_size:-}" =~ ^[0-9]+$ ]] || orig_data_size=0
            zram_used=$((zram_used + orig_data_size / 1024))
        fi
    done
fi

disk_line="$(df -Pk / 2>/dev/null | awk 'NR==2 {print $2 "\t" $3}')"
IFS=$'\t' read -r disk_total disk_used <<< "$disk_line"
disk_total="${disk_total:-0}"
disk_used="${disk_used:-0}"

read -r load1 load5 load15 _ < /proc/loadavg
uptime_seconds="$(awk '{print int($1)}' /proc/uptime)"
cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || printf 1)"
host="$(hostname 2>/dev/null || printf Linux)"

printf 'CPU\t%s\n' "$cpu_percent"
printf 'RAM\t%s\t%s\n' "$mem_used" "$mem_total"
printf 'ZRAM\t%s\t%s\n' "$zram_used" "$zram_total"
printf 'DISK\t%s\t%s\n' "$disk_used" "$disk_total"
printf 'META\t%s\t%s\t%s\t%s\t%s\t%s\n' "$uptime_seconds" "$load1" "$load5" "$load15" "$cores" "$host"

ps -eo pid=,pcpu=,pmem=,comm= --sort=-pcpu 2>/dev/null | head -n 10 | \
    awk '{pid=$1; cpu=$2; mem=$3; $1=$2=$3=""; sub(/^[[:space:]]+/, ""); gsub(/\t/, " "); printf "PROC\t%s\t%s\t%s\t%s\n", pid, cpu, mem, $0}'

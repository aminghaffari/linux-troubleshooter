#!/bin/bash

clear

RED="\033[31m"
YELLOW="\033[33m"
GREEN="\033[32m"
BLUE="\033[34m"
NC="\033[0m"

line() {
  echo "──────────────────────────────────────────────"
}

section() {
  echo
  echo -e "${BLUE}$1${NC}"
  line
}

status() {
  local value="$1"
  local warn="$2"
  local crit="$3"

  if (( $(echo "$value >= $crit" | bc -l) )); then
    echo -e "${RED}CRITICAL${NC}"
  elif (( $(echo "$value >= $warn" | bc -l) )); then
    echo -e "${YELLOW}WARNING${NC}"
  else
    echo -e "${GREEN}OK${NC}"
  fi
}

section "SYSTEM SUMMARY"
printf "%-18s %s\n" "Hostname:" "$(hostname)"
printf "%-18s %s\n" "Date:" "$(date)"
printf "%-18s %s\n" "Uptime:" "$(uptime -p)"
printf "%-18s %s\n" "Kernel:" "$(uname -r)"
printf "%-18s %s\n" "OS:" "$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"

cpu_cores=$(nproc)
load1=$(awk '{print $1}' /proc/loadavg)

section "LOAD AVERAGE"
printf "%-18s %s\n" "CPU Cores:" "$cpu_cores"
printf "%-18s %s\n" "Load 1 min:" "$load1"

if (( $(echo "$load1 > $cpu_cores" | bc -l) )); then
  echo -e "Status: ${RED}HIGH LOAD${NC}"
elif (( $(echo "$load1 > $cpu_cores * 0.7" | bc -l) )); then
  echo -e "Status: ${YELLOW}MEDIUM LOAD${NC}"
else
  echo -e "Status: ${GREEN}OK${NC}"
fi

section "TOP CPU PROCESS"
ps -eo pid,user,%cpu,%mem,etime,lstart,comm --sort=-%cpu | head -n 2 | \
awk 'NR==1{
printf "%-8s %-10s %-7s %-7s %-14s %-25s %s\n","PID","USER","CPU%","MEM%","ELAPSED","STARTED","COMMAND"
}
NR==2{
printf "%-8s %-10s %-7s %-7s %-14s %-25s %s\n",$1,$2,$3,$4,$5,$6" "$7" "$8" "$9" "$10,$11
}'

section "TOP RAM PROCESS"
ps -eo pid,user,%mem,%cpu,etime,lstart,comm --sort=-%mem | head -n 2 | \
awk 'NR==1{
printf "%-8s %-10s %-7s %-7s %-14s %-25s %s\n","PID","USER","MEM%","CPU%","ELAPSED","STARTED","COMMAND"
}
NR==2{
printf "%-8s %-10s %-7s %-7s %-14s %-25s %s\n",$1,$2,$3,$4,$5,$6" "$7" "$8" "$9" "$10,$11
}'

section "MEMORY"
mem_total=$(free -m | awk '/Mem:/ {print $2}')
mem_used=$(free -m | awk '/Mem:/ {print $3}')
mem_available=$(free -m | awk '/Mem:/ {print $7}')
mem_percent=$(awk "BEGIN {printf \"%.1f\", ($mem_used/$mem_total)*100}")

printf "%-18s %s MB\n" "Total:" "$mem_total"
printf "%-18s %s MB\n" "Used:" "$mem_used"
printf "%-18s %s MB\n" "Available:" "$mem_available"
printf "%-18s %s%%\n" "Usage:" "$mem_percent"

if (( $(echo "$mem_percent >= 90" | bc -l) )); then
  echo -e "Status: ${RED}CRITICAL${NC}"
elif (( $(echo "$mem_percent >= 75" | bc -l) )); then
  echo -e "Status: ${YELLOW}WARNING${NC}"
else
  echo -e "Status: ${GREEN}OK${NC}"
fi

section "SWAP"
free -h | awk '/Swap:/ {
printf "%-18s %s\n%-18s %s\n%-18s %s\n", "Swap Total:", $2, "Swap Used:", $3, "Swap Free:", $4
}'

section "DISK USAGE > 80%"
disk_output=$(df -hT -x tmpfs -x devtmpfs | awk 'NR==1 || $6+0 >= 80')
if [ "$(echo "$disk_output" | wc -l)" -le 1 ]; then
  echo -e "${GREEN}No partitions above 80%${NC}"
else
  echo "$disk_output" | column -t
fi

section "FAILED SERVICES"
failed=$(systemctl --failed --no-legend 2>/dev/null)
if [ -z "$failed" ]; then
  echo -e "${GREEN}No failed services${NC}"
else
  echo -e "${RED}Failed services found:${NC}"
  echo "$failed" | awk '{print $1, $2, $3, $4}' | column -t
fi

section "HIGH CPU PROCESSES > 70%"
high_cpu=$(ps -eo pid,user,%cpu,%mem,etime,comm --sort=-%cpu | awk 'NR==1 || $3 >= 70')
if [ "$(echo "$high_cpu" | wc -l)" -le 1 ]; then
  echo -e "${GREEN}No process above 70% CPU${NC}"
else
  echo "$high_cpu" | column -t
fi

section "HIGH RAM PROCESSES > 10%"
high_mem=$(ps -eo pid,user,%mem,%cpu,etime,comm --sort=-%mem | awk 'NR==1 || $3 >= 10')
if [ "$(echo "$high_mem" | wc -l)" -le 1 ]; then
  echo -e "${GREEN}No process above 10% RAM${NC}"
else
  echo "$high_mem" | column -t
fi

section "NETWORK LISTENING PORTS"
ss -tuln 2>/dev/null | head -n 20

section "RECENT CRITICAL LOGS"
logs=$(journalctl -p 3 -n 10 --no-pager 2>/dev/null)
if [ -z "$logs" ]; then
  echo -e "${GREEN}No recent critical logs${NC}"
else
  echo "$logs"
fi

section "OOM / MEMORY KILL EVENTS"
oom=$(journalctl -k --no-pager 2>/dev/null | grep -Ei "out of memory|oom|killed process" | tail -n 10)
if [ -z "$oom" ]; then
  echo -e "${GREEN}No OOM events found${NC}"
else
  echo -e "${RED}OOM events found:${NC}"
  echo "$oom"
fi

section "FINAL HEALTH SUMMARY"

issues=0

if (( $(echo "$load1 > $cpu_cores" | bc -l) )); then
  echo -e "${RED}- Load average is higher than CPU cores${NC}"
  issues=$((issues+1))
fi

if (( $(echo "$mem_percent >= 90" | bc -l) )); then
  echo -e "${RED}- Memory usage is critical${NC}"
  issues=$((issues+1))
elif (( $(echo "$mem_percent >= 75" | bc -l) )); then
  echo -e "${YELLOW}- Memory usage is high${NC}"
  issues=$((issues+1))
fi

if [ "$(echo "$disk_output" | wc -l)" -gt 1 ]; then
  echo -e "${YELLOW}- Some disk partitions are above 80%${NC}"
  issues=$((issues+1))
fi

if [ -n "$failed" ]; then
  echo -e "${RED}- Failed systemd services detected${NC}"
  issues=$((issues+1))
fi

if [ -n "$oom" ]; then
  echo -e "${RED}- OOM killer events detected${NC}"
  issues=$((issues+1))
fi

if [ "$issues" -eq 0 ]; then
  echo -e "${GREEN}System looks healthy based on basic checks${NC}"
else
  echo -e "${YELLOW}Total issues found: $issues${NC}"
fi

echo
line
echo "Report completed"
line


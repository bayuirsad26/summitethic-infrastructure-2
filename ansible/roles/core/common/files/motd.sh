#!/bin/bash
# SummitEthic dynamic MOTD script

# System load
load=$(cat /proc/loadavg | awk '{print $1,$2,$3}')
# Memory usage
mem_total=$(free -m | awk '/^Mem:/{print $2}')
mem_used=$(free -m | awk '/^Mem:/{print $3}')
mem_percent=$(echo "scale=2; $mem_used*100/$mem_total" | bc)
# Disk usage
disk_usage=$(df -h / | awk 'NR==2 {print $5}')
# Uptime
uptime=$(uptime -p)
# Last login
last_login=$(last -n 1 | head -1)

cat << EOF

-------------------------------------------------------------
  SummitEthic Infrastructure - $(hostname)
-------------------------------------------------------------
  System load:   $load
  Memory usage:  $mem_used MB / $mem_total MB ($mem_percent%)
  Disk usage:    $disk_usage
  System uptime: $uptime
  Last login:    $last_login
-------------------------------------------------------------

EOF
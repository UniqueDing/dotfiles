#!/bin/bash

convert_bytes() {
  local bytes=$1
  if [ "$bytes" -lt 0 ]; then
    printf "0B\n"
  elif [ "$bytes" -lt 1024 ]; then
    printf "%.1fB\n" "$bytes"
  elif [ "$bytes" -lt $((1024 * 1024)) ]; then
    printf "%.1fK\n" "$(echo "scale=1; $bytes / 1024" | bc)" # 千字节
  elif [ "$bytes" -lt $((1024 * 1024 * 1024)) ]; then
    printf "%.1fM\n" "$(echo "scale=1; $bytes / (1024 * 1024)" | bc)" # 兆字节
  else
    printf "%.1fG\n" "$(echo "scale=1; $bytes / (1024 * 1024 * 1024)" | bc)" # 千兆字节
  fi
}

print_net() {
  total_recv_rate=$(curl -s http://localhost:61208/api/4/network 2>/dev/null | jq '[.[] | .bytes_recv_rate_per_sec] | add')
  readable_recv_rate=$(convert_bytes "$total_recv_rate")
  echo "$readable_recv_rate"
}

print_net

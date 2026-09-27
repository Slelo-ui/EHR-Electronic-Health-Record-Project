#!/bin/sh
# Adds latency in both directions to every link through the wan service, so a round trip costs
# twice the configured value. Safe to re-run: existing latency is replaced.
set -eu

api=http://wan:8474

add_latency() { # proxy latency_ms jitter_ms
  for stream in upstream downstream; do
    name="latency_$stream"
    curl -fsS -X DELETE "$api/proxies/$1/toxics/$name" >/dev/null 2>&1 || true
    curl -fsS -X POST "$api/proxies/$1/toxics" -H "Content-Type: application/json" \
      -d "{\"name\":\"$name\",\"type\":\"latency\",\"stream\":\"$stream\",\"attributes\":{\"latency\":$2,\"jitter\":$3}}" \
      >/dev/null
  done
  echo "$1: +$2 ms each way (jitter $3 ms)"
}

add_latency internet_to_cloud_app "$INTERNET_LATENCY_MS" "$INTERNET_JITTER_MS"
add_latency wan_cloud_to_onprem_app "$WAN_LATENCY_MS" "$WAN_JITTER_MS"
add_latency wan_replication "$WAN_LATENCY_MS" "$WAN_JITTER_MS"
add_latency wan_backup "$WAN_LATENCY_MS" "$WAN_JITTER_MS"

#!/usr/bin/env bash
set -euo pipefail

PREFIX=${PREFIX:-kostin-01}
GREETING=${GREETING:-labwork}
WAIT=${WAIT:-300}

LB_IP=$(yc load-balancer network-load-balancer get \
  --name "$PREFIX-lb" --format json \
  | jq -r '.listeners[0].address')

if [[ -z "$LB_IP" || "$LB_IP" == "null" ]]; then
  echo "У балансировщика нет внешнего адреса" >&2
  exit 1
fi

echo "==> Ожидание ответов обеих машин: http://$LB_IP"

seen_1=no
seen_2=no

while (( SECONDS < WAIT )); do
  answer=$(curl -s --max-time 3 "http://$LB_IP" || true)

  case "$answer" in
    "$GREETING on $PREFIX-app-1") seen_1=yes ;;
    "$GREETING on $PREFIX-app-2") seen_2=yes ;;
  esac

  if [[ $seen_1 == yes && $seen_2 == yes ]]; then
    break
  fi

  sleep 2
done

if [[ $seen_1 != yes || $seen_2 != yes ]]; then
  echo "Не получены ответы от обеих машин за $WAIT секунд" >&2
  echo "app-1: $seen_1; app-2: $seen_2" >&2
  exit 1
fi

echo "==> Обе машины отвечают. Десять запросов подряд:"

for _ in $(seq 1 10); do
  curl -s --max-time 3 "http://$LB_IP" || echo "Нет ответа"
done

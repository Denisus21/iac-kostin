#!/usr/bin/env bash
set -uo pipefail

PREFIX="${PREFIX:-kostin-01}"
APP_PORT="${APP_PORT:-8003}"
GREETING="${GREETING:-labwork}"

FAILED=0

# Балансировщик отвечает 200 
LB_IP=$(yc load-balancer network-load-balancer get --name "$PREFIX-lb" \
  --format json 2>/dev/null | jq -r '.listeners[0].address // empty')

if [ -z "$LB_IP" ]; then
  echo "✗ балансировщик $PREFIX-lb не найден"
  FAILED=1
else
  CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://$LB_IP/" || echo "000")
  if [ "$CODE" = "200" ]; then
    echo "✓ балансировщик отвечает: 200"
  else
    echo "✗ балансировщик вернул код: $CODE"
    FAILED=1
  fi
fi

# Отвечает больше одной машины 
if [ -n "$LB_IP" ]; then
  HOSTS=$(for i in $(seq 1 10); do
    curl -s --max-time 3 "http://$LB_IP/" | grep -m1 -o "$GREETING on [a-z0-9-]*" || true
  done | sort -u | grep "on")

  COUNT=$(echo "$HOSTS" | grep -c "on" || echo 0)
  if [ "$COUNT" -gt 1 ]; then
    echo "✓ ответили машины:"
    echo "$HOSTS" | sed 's/^/    /'
  else
    echo "✗ ответила только одна машина (распределения нет):"
    echo "$HOSTS" | sed 's/^/    /'
    FAILED=1
  fi
fi

# Сервер приложения доступен с веб-сервера 
WEB1_IP=$(yc compute instance get "$PREFIX-web-1" --format json 2>/dev/null \
  | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address // empty')
APP_INTERNAL_IP=$(yc compute instance get "$PREFIX-app-1" --format json 2>/dev/null \
  | jq -r '.network_interfaces[0].primary_v4_address.address // empty')

if [ -z "$WEB1_IP" ] || [ -z "$APP_INTERNAL_IP" ]; then
  echo "✗ не удалось получить адреса web-1 или app-1"
  FAILED=1
else
  RESULT=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
    student@"$WEB1_IP" "curl -s --max-time 5 http://$APP_INTERNAL_IP:$APP_PORT/ | grep -c '$GREETING'" 2>/dev/null || echo "0")

  if [ "$RESULT" -gt 0 ]; then
    echo "✓ сервер приложения доступен с web-1 по внутреннему адресу"
  else
    echo "✗ сервер приложения недоступен с web-1"
    FAILED=1
  fi
fi

if [ "$FAILED" -eq 0 ]; then
  echo "---"
  echo "Стенд в норме."
  exit 0
else
  echo "---"
  echo "Стенд не в норме."
  exit 1
fi

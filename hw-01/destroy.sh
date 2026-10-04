#!/usr/bin/env bash
set -uo pipefail

PREFIX="${PREFIX:-kostin-01}"

# Балансировщики 
echo "==> удаляю балансировщики с префиксом $PREFIX"
yc load-balancer network-load-balancer list --format json \
  | jq -r ".[] | select(.name | startswith(\"$PREFIX\")) | .name" \
  | while read -r name; do
    [ -n "$name" ] && yc load-balancer network-load-balancer delete "$name"
  done

# Целевые группы 
echo "==> удаляю целевые группы"
yc load-balancer target-group list --format json \
  | jq -r ".[] | select(.name | startswith(\"$PREFIX\")) | .name" \
  | while read -r name; do
    [ -n "$name" ] && yc load-balancer target-group delete "$name"
  done

# Машины 
echo "==> удаляю машины"
yc compute instance list --format json \
  | jq -r ".[] | select(.name | startswith(\"$PREFIX\")) | .name" \
  | while read -r name; do
    [ -n "$name" ] && yc compute instance delete "$name"
  done

# Диски 
echo "==> удаляю диски"
yc compute disk list --format json \
  | jq -r ".[] | select(.name | startswith(\"$PREFIX\")) | .name" \
  | while read -r name; do
    [ -n "$name" ] && yc compute disk delete "$name"
  done

# Отвязать таблицу маршрутизации от подсети 
echo "==> отвязываю таблицу маршрутизации от подсети"
yc vpc subnet update --name "$PREFIX-subnet-a" --route-table-name "" 2>/dev/null || true

# Таблица маршрутизации 
echo "==> удаляю таблицу маршрутизации"
yc vpc route-table list --format json \
  | jq -r ".[] | select(.name | startswith(\"$PREFIX\")) | .name" \
  | while read -r name; do
    [ -n "$name" ] && yc vpc route-table delete "$name"
  done

# NAT-шлюз 
echo "==> удаляю NAT-шлюз"
yc vpc gateway list --format json \
  | jq -r ".[] | select(.name | startswith(\"$PREFIX\")) | .name" \
  | while read -r name; do
    [ -n "$name" ] && yc vpc gateway delete "$name"
  done

# Подсети 
echo "==> удаляю подсети"
yc vpc subnet list --format json \
  | jq -r ".[] | select(.name | startswith(\"$PREFIX\")) | .name" \
  | while read -r name; do
    [ -n "$name" ] && yc vpc subnet delete "$name"
  done

# Сети 
echo "==> удаляю сети"
yc vpc network list --format json \
  | jq -r ".[] | select(.name | startswith(\"$PREFIX\")) | .name" \
  | while read -r name; do
    [ -n "$name" ] && yc vpc network delete "$name"
  done

echo "==> Готово"
yc compute instance list
yc compute disk list
yc vpc network list
yc load-balancer network-load-balancer list
yc vpc address list

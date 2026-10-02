#!/usr/bin/env bash
set -euo pipefail

PREFIX=kostin-01
VM_COUNT=2

echo "==> удаление балансировщика"
yc load-balancer network-load-balancer delete "$PREFIX-lb" || true

echo "==> удаление целевой группы"
yc load-balancer target-group delete "$PREFIX-tg" || true

echo "==> удаление машин"
for i in $(seq 1 "$VM_COUNT"); do
  yc compute instance delete "$PREFIX-app-$i" || true
done

echo "==> удаление диска"
yc compute disk delete "$PREFIX-data" || true

echo "==> удаление подсетей"
yc vpc subnet delete "$PREFIX-subnet-a" || true
yc vpc subnet delete "$PREFIX-subnet-b" || true

echo "==> удаление сети"
yc vpc network delete "$PREFIX-net" || true

echo "==> проверка"
yc compute instance list
yc compute disk list
yc vpc network list
yc load-balancer network-load-balancer list

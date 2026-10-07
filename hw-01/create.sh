#!/usr/bin/env bash
set -euo pipefail

WEB_COUNT="${1:-${WEB_COUNT:-2}}"
DISK_SIZE=15
BOOT_SIZE=15
IMAGE_FAMILY=debian-12

PREFIX="${PREFIX:-kostin-01}"
ZONE_A="${ZONE_A:-ru-central1-a}"
ZONE_B="${ZONE_B:-ru-central1-b}"
CIDR_A="${CIDR_A:-10.11.1.0/24}"
CIDR_B="${CIDR_B:-10.11.2.0/24}"
APP_PORT="${APP_PORT:-8003}"
GREETING="${GREETING:-labwork}"
ENV_NAME="${ENV_NAME:-lab}"

SSH_KEY_PATH="$HOME/.ssh/id_ed25519.pub"

echo "Параметры"
echo "PREFIX=$PREFIX  WEB_COUNT=$WEB_COUNT  APP_PORT=$APP_PORT"
echo "ZONE_A=$ZONE_A  ZONE_B=$ZONE_B"

# Функции проверки существования
exists_network()   { yc vpc network get --name "$1" >/dev/null 2>&1; }
exists_subnet()    { yc vpc subnet get --name "$1" >/dev/null 2>&1; }
exists_gateway()   { yc vpc gateway get --name "$1" >/dev/null 2>&1; }
exists_route_table(){ yc vpc route-table get --name "$1" >/dev/null 2>&1; }
exists_instance()  { yc compute instance get --name "$1" >/dev/null 2>&1; }
exists_target_group(){ yc load-balancer target-group get --name "$1" >/dev/null 2>&1; }
exists_lb()        { yc load-balancer network-load-balancer get --name "$1" >/dev/null 2>&1; }

# Сеть 
if exists_network "$PREFIX-net"; then
  echo "==> сеть $PREFIX-net уже есть"
else
  echo "==> создаю сеть $PREFIX-net"
  yc vpc network create --name "$PREFIX-net"
fi

# Подсети 
if exists_subnet "$PREFIX-subnet-a"; then
  echo "==> подсеть $PREFIX-subnet-a уже есть"
else
  echo "==> создаю подсеть $PREFIX-subnet-a"
  yc vpc subnet create --name "$PREFIX-subnet-a" --network-name "$PREFIX-net" \
    --zone "$ZONE_A" --range "$CIDR_A"
fi

if exists_subnet "$PREFIX-subnet-b"; then
  echo "==> подсеть $PREFIX-subnet-b уже есть"
else
  echo "==> создаю подсеть $PREFIX-subnet-b"
  yc vpc subnet create --name "$PREFIX-subnet-b" --network-name "$PREFIX-net" \
    --zone "$ZONE_B" --range "$CIDR_B"
fi

# NAT-шлюз 
if exists_gateway "$PREFIX-nat"; then
  echo "==> NAT-шлюз $PREFIX-nat уже есть"
else
  echo "==> создаю NAT-шлюз $PREFIX-nat"
  yc vpc gateway create --name "$PREFIX-nat"
fi

GW_ID=$(yc vpc gateway get --name "$PREFIX-nat" --format json | jq -r .id)

# Таблица маршрутизации 
if exists_route_table "$PREFIX-rt"; then
  echo "==> таблица маршрутизации $PREFIX-rt уже есть"
else
  echo "==> создаю таблицу маршрутизации $PREFIX-rt"
  yc vpc route-table create --name "$PREFIX-rt" --network-name "$PREFIX-net" \
    --route "destination=0.0.0.0/0,gateway-id=$GW_ID"
fi

# Привязка таблицы к подсети A (там живёт app-1 без публичного адреса)
echo "==> привязываю таблицу маршрутизации к подсети A"
yc vpc subnet update --name "$PREFIX-subnet-a" --route-table-name "$PREFIX-rt"

# Разворачивание cloud-init 
echo "==> разворачиваю cloud-init"
SSH_KEY=$(cat "$SSH_KEY_PATH")
export APP_PORT GREETING SSH_KEY
envsubst '${APP_PORT} ${GREETING} ${SSH_KEY}' \
  < hw-01/cloud-init.tpl.yaml > hw-01/cloud-init.yaml

# Веб-серверы (распределены по зонам) 
ZONES=("$ZONE_A" "$ZONE_B")
SUBNETS=("$PREFIX-subnet-a" "$PREFIX-subnet-b")

for i in $(seq 1 "$WEB_COUNT"); do
  idx=$(( (i - 1) % ${#ZONES[@]} ))
  NAME="$PREFIX-web-$i"

  if exists_instance "$NAME"; then
    echo "==> машина $NAME уже есть"
    continue
  fi

  echo "==> создаю веб-сервер $NAME"
  yc compute instance create \
    --name "$NAME" \
    --zone "${ZONES[$idx]}" \
    --platform standard-v2 \
    --cores=2 --core-fraction=20 --memory=2 \
    --preemptible \
    --create-boot-disk image-folder-id=standard-images,image-family="$IMAGE_FAMILY",type=network-hdd,size="$BOOT_SIZE" \
    --network-interface subnet-name="${SUBNETS[$idx]}",nat-ip-version=ipv4 \
    --hostname "$NAME" \
    --metadata-from-file user-data=hw-01/cloud-init.yaml
done

# Сервер приложения (без публичного адреса)
APP_NAME="$PREFIX-app-1"
if exists_instance "$APP_NAME"; then
  echo "==> сервер приложения $APP_NAME уже есть"
else
  echo "==> создаю сервер приложения $APP_NAME (без публичного IP)"
  yc compute instance create \
    --name "$APP_NAME" \
    --zone "$ZONE_A" \
    --platform standard-v2 \
    --cores=2 --core-fraction=20 --memory=2 \
    --preemptible \
    --create-boot-disk image-folder-id=standard-images,image-family="$IMAGE_FAMILY",type=network-hdd,size="$BOOT_SIZE" \
    --network-interface subnet-name="$PREFIX-subnet-a" \
    --hostname "$APP_NAME" \
    --metadata-from-file user-data=hw-01/cloud-init.yaml
fi

# Целевая группа: только веб-серверы 
if exists_target_group "$PREFIX-tg"; then
  echo "==> целевая группа $PREFIX-tg уже есть"
else
  echo "==> создаю целевую группу $PREFIX-tg"
  TARGETS=""
  for i in $(seq 1 "$WEB_COUNT"); do
    idx=$(( (i - 1) % ${#ZONES[@]} ))
    IP=$(yc compute instance get "$PREFIX-web-$i" --format json \
      | jq -r '.network_interfaces[0].primary_v4_address.address')
    TARGETS="$TARGETS --target subnet-name=${SUBNETS[$idx]},address=$IP"
  done
  yc load-balancer target-group create --name "$PREFIX-tg" $TARGETS
fi

# Балансировщик 
if exists_lb "$PREFIX-lb"; then
  echo "==> балансировщик $PREFIX-lb уже есть"
else
  echo "==> создаю балансировщик $PREFIX-lb"
  TG_ID=$(yc load-balancer target-group get --name "$PREFIX-tg" --format json | jq -r .id)
  yc load-balancer network-load-balancer create \
    --name "$PREFIX-lb" \
    --region-id ru-central1 \
    --listener name=http,port=80,target-port="$APP_PORT",external-ip-version=ipv4 \
    --target-group target-group-id="$TG_ID",healthcheck-name=http,healthcheck-interval=2s,healthcheck-timeout=1s,healthcheck-unhealthythreshold=2,healthcheck-healthythreshold=2,healthcheck-http-port="$APP_PORT",healthcheck-http-path=/
fi

echo "==> Готово "

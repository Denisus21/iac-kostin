#!/bin/bash
# Практическая работа №1 (вариант 01, Костин)
# Все команды, которыми создавались и удалялись ресурсы.

# Параметры варианта 
export PREFIX=kostin-01
export ZONE=ru-central1-a
export CIDR=10.11.1.0/24
export DISK_SIZE=15

# Сеть и подсеть
yc vpc network create --name "$PREFIX-net"

yc vpc subnet create \
  --name "$PREFIX-subnet" \
  --network-name "$PREFIX-net" \
  --zone "$ZONE" \
  --range "$CIDR"

# Сервисный аккаунт
yc iam service-account create --name "$PREFIX-sa"

yc resource-manager folder add-access-binding "$(yc config get folder-id)" \
  --role editor \
  --subject "serviceAccount:$(yc iam service-account get --name $PREFIX-sa --format json | jq -r .id)"

mkdir -p ~/.yc-keys
yc iam key create --service-account-name "$PREFIX-sa" \
  --output ~/.yc-keys/$PREFIX-key.json

# Машина командой
yc compute instance create \
  --name "$PREFIX-web-1" \
  --zone "$ZONE" \
  --platform standard-v3 \
  --cores=2 --core-fraction=20 --memory=2 \
  --preemptible \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2404-lts,type=network-hdd,size="$DISK_SIZE" \
  --network-interface subnet-name="$PREFIX-subnet",nat-ip-version=ipv4 \
  --hostname "$PREFIX-web-1" \
  --ssh-key ~/.ssh/id_ed25519.pub \
  --labels created-by=cli

# Уборка (в обратном порядке)
yc compute instance delete "$PREFIX-web-1"
yc compute instance delete "$PREFIX-web-manual"
yc vpc subnet delete "$PREFIX-subnet"
yc vpc network delete "$PREFIX-net"

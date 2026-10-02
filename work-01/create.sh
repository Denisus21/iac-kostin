#!/bin/bash
set -e

# === Параметры варианта 01 (Костин) ===
PREFIX=kostin-01
ZONE=ru-central1-a
CIDR=10.11.1.0/24
DISK_SIZE=15
IMAGE_FAMILY=debian-12
SSH_KEY=~/.ssh/id_ed25519.pub

echo "=== Создание сети и подсети ==="
yc vpc network create --name "$PREFIX-net"
yc vpc subnet create \
  --name "$PREFIX-subnet" \
  --network-name "$PREFIX-net" \
  --zone "$ZONE" \
  --range "$CIDR"

echo "=== Создание двух машин на Debian 12 ==="
for i in 1 2; do
  yc compute instance create \
    --name "$PREFIX-app-$i" \
    --zone "$ZONE" \
    --platform standard-v3 \
    --cores=2 --core-fraction=20 --memory=2 \
    --preemptible \
    --create-boot-disk image-folder-id=standard-images,image-family=$IMAGE_FAMILY,type=network-hdd,size="$DISK_SIZE" \
    --network-interface subnet-name="$PREFIX-subnet",nat-ip-version=ipv4 \
    --hostname "$PREFIX-app-$i" \
    --ssh-key "$SSH_KEY" \
    --labels created-by=cli
done

echo "=== Готово. Адреса машин: ==="
yc compute instance list --format json \
  | jq -r '.[] | select(.name | startswith("'"$PREFIX"'")) | "\(.name)\t\(.network_interfaces[0].primary_v4_address.one_to_one_nat.address)"'

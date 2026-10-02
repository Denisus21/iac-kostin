#!/bin/bash
set -e

PREFIX=kostin-01

echo "Удаление машин"
yc compute instance delete "$PREFIX-app-1"
yc compute instance delete "$PREFIX-app-2"

echo "Удаление подсети и сети"
yc vpc subnet delete "$PREFIX-subnet"
yc vpc network delete "$PREFIX-net"

echo "Проверка"
yc compute instance list
yc compute disk list

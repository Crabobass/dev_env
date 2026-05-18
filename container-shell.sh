#!/usr/bin/env bash

set -euo pipefail

mapfile -t CONTAINER_LINES < <(docker ps --format '{{.ID}}|{{.Names}}|{{.Image}}')

if [ "${#CONTAINER_LINES[@]}" -eq 0 ]; then
  echo "Нет запущенных контейнеров."
  exit 1
fi

echo "Запущенные контейнеры:"
for i in "${!CONTAINER_LINES[@]}"; do
  IFS='|' read -r _id name image <<< "${CONTAINER_LINES[$i]}"
  printf "%d) %s (%s)\n" "$((i + 1))" "$name" "$image"
done

read -r -p "Введите номер контейнера: " selection

if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
  echo "Ошибка: нужно ввести число."
  exit 1
fi

if [ "$selection" -lt 1 ] || [ "$selection" -gt "${#CONTAINER_LINES[@]}" ]; then
  echo "Ошибка: номер вне диапазона."
  exit 1
fi

selected_line="${CONTAINER_LINES[$((selection - 1))]}"
IFS='|' read -r container_id container_name _image <<< "$selected_line"

echo "Подключение к контейнеру: $container_name"
if docker exec "$container_id" sh -lc 'command -v bash >/dev/null 2>&1'; then
  docker exec -it "$container_id" bash
  exit 0
fi

docker exec -it "$container_id" sh

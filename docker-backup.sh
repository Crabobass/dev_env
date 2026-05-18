#!/usr/bin/env bash
#
# Создаёт каталог docker_backup/ с образами Docker и архивами volumes проекта.
# После выполнения можно заархивировать весь репозиторий и перенести на другую машину.
#
# Использование: ./docker-backup.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="${ROOT_DIR}/${DOCKER_BACKUP_DIR_NAME:-docker_backup}"

# shellcheck source=docker-backup-lib.sh
source "${ROOT_DIR}/docker-backup-lib.sh"

load_project_env "$ROOT_DIR"
detect_compose

mkdir -p "${BACKUP_DIR}/images" "${BACKUP_DIR}/volumes"

MANIFEST="${BACKUP_DIR}/manifest.env"
IMAGES_LIST="${BACKUP_DIR}/images.list"
VOLUMES_LIST="${BACKUP_DIR}/volumes.list"

echo "==> Проект: ${PROJECT_NAME}"
echo "==> Каталог бэкапа: ${BACKUP_DIR}"

echo "==> Остановка контейнеров проекта (для консистентного бэкапа БД)..."
compose stop || true

echo "==> Проверка образов..."
mapfile -t IMAGES < <(compose config --images 2>/dev/null | sort -u)

if [[ ${#IMAGES[@]} -eq 0 ]]; then
  echo "Ошибка: compose config --images не вернул образы" >&2
  exit 1
fi

missing=0
for image in "${IMAGES[@]}"; do
  if ! docker image inspect "$image" &>/dev/null; then
    echo "    образ отсутствует локально: ${image}"
    missing=1
  fi
done

if [[ "$missing" -eq 1 ]]; then
  echo "==> Сборка недостающих образов (docker compose build)..."
  compose build
  mapfile -t IMAGES < <(compose config --images 2>/dev/null | sort -u)
fi

: > "$IMAGES_LIST"
for image in "${IMAGES[@]}"; do
  archive_name="$(image_to_filename "$image").tar"
  archive_path="${BACKUP_DIR}/images/${archive_name}"

  echo "==> Сохранение образа: ${image} -> images/${archive_name}"
  docker save "$image" -o "$archive_path"
  echo "$image" >> "$IMAGES_LIST"
done

: > "$VOLUMES_LIST"
mapfile -t LOGICAL_VOLUMES < <(compose config --volumes 2>/dev/null | sort -u)

if [[ ${#LOGICAL_VOLUMES[@]} -eq 0 ]]; then
  echo "Предупреждение: в compose не найдены named volumes" >&2
fi

for logical_volume in "${LOGICAL_VOLUMES[@]}"; do
  if ! docker_volume="$(resolve_compose_volume_name "$logical_volume" "$PROJECT_NAME")"; then
    echo "Предупреждение: volume «${logical_volume}» не найден в Docker, пропуск" >&2
    continue
  fi

  archive_name="${logical_volume}.tar.gz"
  archive_rel="volumes/${archive_name}"

  echo "==> Сохранение volume: ${docker_volume} -> ${archive_rel}"
  docker run --rm \
    -v "${docker_volume}:/volume:ro" \
    -v "${BACKUP_DIR}/volumes:/backup" \
    alpine:3.20 \
    tar czf "/backup/${archive_name}" -C /volume .

  printf '%s|%s|%s\n' "$logical_volume" "$docker_volume" "$archive_rel" >> "$VOLUMES_LIST"
done

{
  echo "BACKUP_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "PROJECT_NAME=${PROJECT_NAME}"
  echo "PHP_VERSION=${PHP_VERSION:-8.5.2}"
  echo "COMPOSE_BIN=${COMPOSE_BIN[*]}"
} > "$MANIFEST"

echo ""
echo "Готово."
echo "  manifest:  ${MANIFEST}"
echo "  images:    ${BACKUP_DIR}/images/"
echo "  volumes:   ${BACKUP_DIR}/volumes/"
echo ""
echo "Дальше: заархивируйте корень проекта (включая docker_backup/) и перенесите на другую машину."
echo "На новой машине: ./docker-restore.sh && ./run.sh"

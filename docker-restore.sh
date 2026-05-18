#!/usr/bin/env bash
#
# Восстанавливает образы и volumes из каталога docker_backup/ (после переноса проекта).
# Использование: ./docker-restore.sh
#
# Рекомендуется запускать до первого ./run.sh или после docker compose down
# (без -v), если нужно перезаписать существующие volumes.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="${ROOT_DIR}/${DOCKER_BACKUP_DIR_NAME:-docker_backup}"

# shellcheck source=docker-backup-lib.sh
source "${ROOT_DIR}/docker-backup-lib.sh"

load_project_env "$ROOT_DIR"
detect_compose

MANIFEST="${BACKUP_DIR}/manifest.env"
IMAGES_LIST="${BACKUP_DIR}/images.list"
VOLUMES_LIST="${BACKUP_DIR}/volumes.list"

if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "Ошибка: каталог бэкапа не найден: ${BACKUP_DIR}" >&2
  echo "Сначала выполните ./docker-backup.sh на исходной машине." >&2
  exit 1
fi

if [[ ! -f "$IMAGES_LIST" ]]; then
  echo "Ошибка: не найден ${IMAGES_LIST}" >&2
  exit 1
fi

manifest_project=""
if [[ -f "$MANIFEST" ]]; then
  manifest_project="$(grep -E '^PROJECT_NAME=' "$MANIFEST" | cut -d= -f2- || true)"
  backup_date="$(grep -E '^BACKUP_DATE=' "$MANIFEST" | cut -d= -f2- || true)"
  if [[ -n "$backup_date" ]]; then
    echo "==> Бэкап от: ${backup_date}"
  fi
fi

if [[ -n "$manifest_project" && "$manifest_project" != "$PROJECT_NAME" ]]; then
  echo "Предупреждение: PROJECT_NAME в .env (${PROJECT_NAME}) != в бэкапе (${manifest_project})" >&2
  echo "  Имена Docker volumes могут не совпасть. Проверьте .env." >&2
fi

echo "==> Проект: ${PROJECT_NAME}"
echo "==> Каталог бэкапа: ${BACKUP_DIR}"

echo "==> Остановка контейнеров проекта..."
compose stop 2>/dev/null || true

echo "==> Загрузка образов из ${BACKUP_DIR}/images/"
shopt -s nullglob
image_archives=("${BACKUP_DIR}"/images/*.tar)
if [[ ${#image_archives[@]} -eq 0 ]]; then
  echo "Ошибка: в ${BACKUP_DIR}/images нет файлов *.tar" >&2
  exit 1
fi

for archive in "${image_archives[@]}"; do
  echo "    docker load -i $(basename "$archive")"
  docker load -i "$archive"
done
shopt -u nullglob

if [[ -f "$VOLUMES_LIST" ]]; then
  echo "==> Восстановление volumes"
  while IFS='|' read -r logical_volume _backup_docker_name archive_rel; do
    [[ -z "$logical_volume" ]] && continue

    archive_path="${BACKUP_DIR}/${archive_rel}"
    if [[ ! -f "$archive_path" ]]; then
      echo "Ошибка: архив volume не найден: ${archive_path}" >&2
      exit 1
    fi

    target_volume="${PROJECT_NAME}_${logical_volume}"
    if ! docker volume inspect "$target_volume" &>/dev/null; then
      echo "    создание volume: ${target_volume}"
      docker volume create "$target_volume" >/dev/null
    else
      echo "    перезапись volume: ${target_volume}"
    fi

    archive_basename="$(basename "$archive_path")"
    echo "    распаковка volumes/${archive_basename} -> ${target_volume}"
    docker run --rm \
      -v "${target_volume}:/volume" \
      -v "${BACKUP_DIR}/volumes:/backup:ro" \
      alpine:3.20 \
      sh -c "find /volume -mindepth 1 -maxdepth 1 -exec rm -rf {} +; tar xzf \"/backup/${archive_basename}\" -C /volume"
  done < "$VOLUMES_LIST"
else
  echo "Предупреждение: ${VOLUMES_LIST} не найден, volumes не восстановлены" >&2
fi

echo ""
echo "Восстановление завершено."
echo "Запустите проект: ./run.sh"
echo ""
echo "Проверка образов из images.list:"
while IFS= read -r image || [[ -n "$image" ]]; do
  [[ -z "$image" ]] && continue
  if docker image inspect "$image" &>/dev/null; then
    echo "  [ok] ${image}"
  else
    echo "  [!!] ${image} — не найден после load; попробуйте: docker compose build"
  fi
done < "$IMAGES_LIST"

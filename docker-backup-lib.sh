#!/usr/bin/env bash
# Общие функции для docker-backup.sh и docker-restore.sh

set -euo pipefail

DOCKER_BACKUP_DIR_NAME="docker_backup"

load_project_env() {
  local root="$1"
  local env_file="${root}/.env"

  if [[ ! -f "$env_file" ]]; then
    echo "Ошибка: не найден файл ${env_file}" >&2
    exit 1
  fi

  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a

  if [[ -z "${PROJECT_NAME:-}" ]]; then
    echo "Ошибка: в .env не задан PROJECT_NAME" >&2
    exit 1
  fi
}

detect_compose() {
  if docker compose version &>/dev/null; then
    COMPOSE_BIN=(docker compose)
  elif docker-compose version &>/dev/null; then
    COMPOSE_BIN=(docker-compose)
  else
    echo "Ошибка: не найден docker compose / docker-compose" >&2
    exit 1
  fi
}

compose() {
  "${COMPOSE_BIN[@]}" --env-file "${ROOT_DIR}/.env" "$@"
}

image_to_filename() {
  echo "$1" | tr '/:@' '___'
}

resolve_compose_volume_name() {
  local logical_volume="$1"
  local project="$2"

  local candidates=(
    "${project}_${logical_volume}"
    "${project}-${logical_volume}"
  )

  local name
  for name in "${candidates[@]}"; do
    if docker volume inspect "$name" &>/dev/null; then
      echo "$name"
      return 0
    fi
  done

  local labeled
  labeled="$(docker volume ls -q \
    --filter "label=com.docker.compose.project=${project}" \
    --filter "label=com.docker.compose.volume=${logical_volume}" 2>/dev/null | head -n 1 || true)"

  if [[ -n "$labeled" ]]; then
    echo "$labeled"
    return 0
  fi

  return 1
}

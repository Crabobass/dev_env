
# Запуск

Данное окружение построено исключительно для локальной разработки бэкенда **не нагруженных** битрикс проектов.

- PHP 8.5.2 (по умолчанию) / PHP 8.1 (через `PHP_VERSION`)
- Xdebug 3.5.0
- MariaDB 10.4.29
- Apache 2.4.66
- Composer 2.9.4

---


```bash
#запустить окружение
docker compose up -d

#запустить на PHP 8.1 (пересобрать server и поднять)
PHP_VERSION=8.1 docker compose up -d --build server

#вернуться на PHP 8.5.2
PHP_VERSION=8.5.2 docker compose up -d --build server

#остановить окружение
docker compose down

#рестарт (например после внесения конфигов)
docker compose restart

#остановить все контейнеры
docker stop $(docker ps -q)

```

# Вход в котейнер

```bash
#запуск контейнера от www-data
export $(grep -v '^#' .env | xargs) && docker exec -it -u www-data ${PROJECT_NAME}_server bash

#запуск server контейнера от root
export $(grep -v '^#' .env | xargs) docker exec -it ${PROJECT_NAME}_server bash
```

# Импорт БД

```bash
#импорт бд из корня проекта
docker compose exec -T <service_name> mariadb -u root -p<password> <db_name> < dump.sql

#или так - в этом случае подтянутся перменные окружения из .env
export $(grep -v '^#' .env | xargs) && docker compose exec -T db mariadb -uroot -p${DB_ROOT_PASSWORD} ${DB_NAME} < db.sql
```

## Экспорт БД

```bash
#экспорт
docker compose exec -T <service_name> mariadb-dump -u root -p<password> <db_name> > dump.sql

#или так - в этом случае подтянутся перменные окружения из .env
export $(grep -v '^#' .env | xargs) && docker compose exec -T db mariadb-dump -u root -p${DB_ROOT_PASSWORD} ${DB_NAME} > dump.sql
```

# Перенос окружения на другую машину (Docker images + volumes)

Скрипты `docker-backup.sh` и `docker-restore.sh` сохраняют образы Docker и named volumes проекта (БД MariaDB) в каталог `docker_backup/`. Код приложения (`./app`) в volumes не входит — он переносится вместе с репозиторием.

**Требования:** Docker, `docker compose` (или `docker-compose`), файл `.env` с тем же `PROJECT_NAME` на обеих машинах.

## Что попадает в бэкап

| Компонент | Куда сохраняется |
|-----------|------------------|
| Образы `server` и `mariadb:10.4.29` | `docker_backup/images/*.tar` |
| Volume `db_data` (данные MySQL) | `docker_backup/volumes/db_data.tar.gz` |
| Метаданные | `docker_backup/manifest.env`, `images.list`, `volumes.list` |

Каталог `docker_backup/` в git не коммитится (см. `.gitignore`).

## Бэкап (исходная машина)

```bash
# из корня проекта
./docker-backup.sh
```

Скрипт останавливает контейнеры проекта, при необходимости собирает образ `server`, сохраняет образы и архивирует volumes.

Дальше **вручную** заархивируйте весь корень проекта (включая `docker_backup/`, `.env`, `app/`) и перенесите на другую машину.

## Восстановление (новая машина)

```bash
# 1. Распаковать проект, положить .env (тот же PROJECT_NAME, что на исходной машине)

# 2. Восстановить образы и volumes
./docker-restore.sh

# 3. Запустить окружение
./run.sh
```

`docker-restore.sh` загружает образы через `docker load`, создаёт volume `${PROJECT_NAME}_db_data` и распаковывает в него данные БД.

В конце скрипт выводит проверку образов из `images.list`. Если образ `server` отмечен как `[!!]`, выполните:

```bash
docker compose --env-file ./.env build server
```

## Важно

- **`PROJECT_NAME` в `.env` должен совпадать** на обеих машинах — от него зависят имена volume и контейнеров.
- Перед повторным `./docker-restore.sh` на машине, где уже есть данные БД, volume будет **перезаписан**.
- Для переноса только данных БД без Docker-образов можно использовать [экспорт/импорт БД](#экспорт-бд) (`mariadb-dump` / `db.sql`).
- `./run.sh` останавливает все запущенные контейнеры Docker на машине, не только контейнеры этого проекта.
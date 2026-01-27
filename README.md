
# Запуск

Данное окружение построено исключительно для локальной разработки бэкенда **не нагруженных** битрикс проектов.

- PHP 8.5.2
- Xdebug 3.5.0
- MariaDB 10.4.29
- Apache 2.4.66
- Composer 2.9.4

---


```bash
#запустить окружение
docker compose up -d

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
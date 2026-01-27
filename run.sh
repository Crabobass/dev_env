#!/bin/bash

docker ps -q | xargs -r docker stop

# Очистить переменные проекта
unset PROJECT_NAME DB_NAME DB_USER DB_PASSWORD DB_ROOT_PASSWORD APP_PORT DB_PORT

# Запустить с явным указанием .env
docker-compose --env-file ./.env up -d

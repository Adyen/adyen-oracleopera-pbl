#!/bin/bash

echo "Starting application..."
cd "../../ad-app/" || exit 1
docker compose -f ./docker-compose-infrastructure.yml -f ./docker-compose-migrations.yml -f ./docker-compose-app.yml -f ./docker-compose-workers.yml up -d || exit 1

echo "Starting server..."
cd "../ad-nginx/nginx/" || exit 1
docker compose up -d || exit 1


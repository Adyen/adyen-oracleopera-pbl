#!/bin/bash

echo "Stopping server..."
cd "../ad-nginx/nginx/" || exit 1
docker compose down

echo "Stopping application..."
cd "../../ad-app/" || exit 1
docker compose -f ./docker-compose-infrastructure.yml -f ./docker-compose-migrations.yml -f ./docker-compose-app.yml -f ./docker-compose-workers.yml down || exit 1
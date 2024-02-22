#!/bin/bash

echo "Create directory structure..."

mkdir -p "app/ad-nginx"
cd "app" || exit
mkdir "ad-app"
cd "../"

echo "Prepare app docker files..."
cp -rT "./assets/docker/app/" "./app/ad-app/"
cp -rT "./assets/docker/nginx/" "./app/ad-nginx/"

cd "app" || exit

validate_db_name() {
    if [[ $1 =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        return 0
    else
        echo "Invalid database name. A valid name should start with a letter or underscore, followed by any combination of letters, digits, and underscores."
        return 1
    fi
}

validate_password() {
    if [[ ${#1} -ge 8 ]]; then
        return 0
    else
        echo "Invalid password. A valid password must be at least 8 characters long."
        return 1
    fi
}

validate_app_url() {
    if [[ $1 =~ ^https://[a-zA-Z0-9./-]+$ ]]; then
        return 0
    else
        echo "Invalid URL. Please enter a valid URL starting with https://."
        return 1
    fi
}

read -rp "Enter database name: " POSTGRES_DB
while ! validate_db_name "$POSTGRES_DB"; do
    read -rp "Enter database name: " POSTGRES_DB
done

read -rp "Enter password: " POSTGRES_PASSWORD
while ! validate_password "$POSTGRES_PASSWORD"; do
    read -rp "Enter password: " POSTGRES_PASSWORD
done

read -rp "Enter Application URL (https://...): " APP_URL
while ! validate_app_url "$APP_URL"; do
    read -rp "Enter Application URL (https://...): " APP_URL
done

DOMAIN=$(echo "$APP_URL" | cut -d'/' -f3)

find . -type f -exec sed -i "s|%{{POSTGRES_PASSWORD}}%|$POSTGRES_PASSWORD|g; s|%{{POSTGRES_DB}}%|$POSTGRES_DB|g; s|%{{DOMAIN}}%|$DOMAIN|g; s|%{{APP_URL}}%|$APP_URL|g" {} +

echo "Docker files prepared successfully."

echo "Starting up the application..."
cd "ad-app" || exit
docker compose -f ./docker-compose-infrastructure.yml -f ./docker-compose-migrations.yml -f ./docker-compose-app.yml -f ./docker-compose-workers.yml up -d

cd  "../ad-nginx/nginx/" || exit
mkdir "conf"
cp ./template/website.conf ./conf/"$DOMAIN".conf
docker compose up -d

cd ../certbot || exit

echo "Setting up the certificate..."
docker compose run --rm certbot certonly --webroot --webroot-path /var/www/certbot/ -d $DOMAIN

cd ../nginx || exit
docker compose down
cat ./template/ssl.conf > ./conf/"$DOMAIN".conf
docker compose up -d
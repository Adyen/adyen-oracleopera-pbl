#!/bin/bash

echo "Create directory structure..."

mkdir -p "app/ad-nginx"
cd "app" || exit 1
mkdir "ad-app"
cd "../"

echo "Prepare app docker files..."
cp -rT "./assets/docker/app/" "./app/ad-app/"
cp -rT "./assets/docker/nginx/" "./app/ad-nginx/"

cd "app" || exit 1

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

validate_from_email() {
    if [[ ${#1} -ge 1 ]]; then
        return 0
    else
        echo "Invalid email. A valid email cannot be empty."
        return 1
    fi
}

validate_environment() {
    if [[ $1 == "dev" || $1 == "live" ]]; then
        return 0
    else
        echo "Invalid environment. Please specify 'dev' or 'live'."
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

read -rp "Enter outgoing email: " FROM_EMAIL
while ! validate_from_email "$FROM_EMAIL"; do
    read -rp "Enter outgoing email: " FROM_EMAIL
done

read -rp "Select application environment [Development, Production]: " APP_ENVIRONMENT
while ! validate_environment "$APP_ENVIRONMENT"; do
    read -rp "Select application environment [Development, Production]: " APP_ENVIRONMENT
done

read -rp "Enter Application URL (https://...): " APP_URL
while ! validate_app_url "$APP_URL"; do
    read -rp "Enter Application URL (https://...): " APP_URL
done

DOMAIN=$(echo "$APP_URL" | cut -d'/' -f3)

if [[ "$APP_ENVIRONMENT" == "Development" ]]; then
    APP_KEY="b57a184f-0a96-40fd-b1ae-3dd598eed66a"
elif [[ "$APP_ENVIRONMENT" == "Production" ]]; then
    APP_KEY="b57a184f-0a96-40fd-b1ae-3dd598eed66a"
else
    echo "Invalid APP_ENVIRONMENT. It must be either 'Development' or 'Production'."
fi

find . -type f -exec sed -i "s|%{{POSTGRES_PASSWORD}}%|$POSTGRES_PASSWORD|g; s|%{{POSTGRES_DB}}%|$POSTGRES_DB|g; s|%{{DOMAIN}}%|$DOMAIN|g; s|%{{APP_ENVIRONMENT}}%|$APP_ENVIRONMENT|g; s|%{{FROM_EMAIL}}%|$FROM_EMAIL|g; s|%{{APP_KEY}}%|$APP_KEY|g; s|%{{APP_URL}}%|$APP_URL|g" {} +

echo "Docker files prepared successfully."

echo "Starting up the application..."
cd "ad-app" || exit 1
docker compose -f ./docker-compose-infrastructure.yml -f ./docker-compose-migrations.yml -f ./docker-compose-app.yml -f ./docker-compose-workers.yml up -d || exit 1

cd  "../ad-nginx/nginx/" || exit 1
mkdir "conf"
cp ./template/website.conf ./conf/"$DOMAIN".conf
docker compose up -d

cd ../certbot || exit 1

echo "Setting up the certificate..."
docker compose run --rm certbot certonly --webroot --webroot-path /var/www/certbot/ -d $DOMAIN

cd ../nginx || exit 1
docker compose down
cat ./template/ssl.conf > ./conf/"$DOMAIN".conf
docker compose up -d
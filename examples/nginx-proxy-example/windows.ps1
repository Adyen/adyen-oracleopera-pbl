Write-Output "Create directory structure..."

New-Item -Path "app/ad-nginx" -ItemType Directory -Force
Set-Location -Path "app" -ErrorAction Stop
New-Item -Path "ad-app" -ItemType Directory
Set-Location -Path ".."

Write-Output "Prepare app docker files..."
Copy-Item -Path "./assets/docker/app/*" -Destination "./app/ad-app/" -Recurse -Force
Copy-Item -Path "./assets/docker/nginx/*" -Destination "./app/ad-nginx/" -Recurse -Force

Set-Location -Path "app" -ErrorAction Stop

Function Validate-DbName {
    param ([string]$name)
    if ($name -match '^[a-zA-Z_][a-zA-Z0-9_]*$') {
        return $true
    } else {
        Write-Output "Invalid database name. A valid name should start with a letter or underscore, followed by any combination of letters, digits, and underscores."
        return $false
    }
}

Function Validate-Password {
    param ([string]$password)
    if ($password.Length -ge 8) {
        return $true
    } else {
        Write-Output "Invalid password. A valid password must be at least 8 characters long."
        return $false
    }
}

Function Validate-AppUrl {
    param ([string]$url)
    if ($url -match '^https://[a-zA-Z0-9./-]+$') {
        return $true
    } else {
        Write-Output "Invalid URL. Please enter a valid URL starting with https://."
        return $false
    }
}

$POSTGRES_DB = Read-Host "Enter database name"
while (-not (Validate-DbName -name $POSTGRES_DB)) {
    $POSTGRES_DB = Read-Host "Enter database name"
}

$POSTGRES_PASSWORD = Read-Host "Enter password"
while (-not (Validate-Password -password $POSTGRES_PASSWORD)) {
    $POSTGRES_PASSWORD = Read-Host "Enter password"
}

$APP_URL = Read-Host "Enter Application URL (https://...)"
while (-not (Validate-AppUrl -url $APP_URL)) {
    $APP_URL = Read-Host "Enter Application URL (https://...)"
}

$DOMAIN = $APP_URL.Split('/')[2]

Get-ChildItem -Path . -Recurse -File | ForEach-Object {
    (Get-Content $_.FullName).Replace('%{{POSTGRES_PASSWORD}}%', $POSTGRES_PASSWORD).Replace('%{{POSTGRES_DB}}%', $POSTGRES_DB).Replace('%{{DOMAIN}}%', $DOMAIN).Replace('%{{APP_URL}}%', $APP_URL) | Set-Content $_.FullName
}

Write-Output "Docker files prepared successfully."

Write-Output "Starting up the application..."
Set-Location -Path "ad-app" -ErrorAction Stop
docker compose -f ./docker-compose-infrastructure.yml -f ./docker-compose-migrations.yml -f ./docker-compose-app.yml -f ./docker-compose-workers.yml up -d -ErrorAction Stop

Set-Location -Path "../ad-nginx/nginx/" -ErrorAction Stop
New-Item -Path "conf" -ItemType Directory -Force
Copy-Item -Path "./template/website.conf" -Destination "./conf/$DOMAIN.conf"
docker compose up -d

Set-Location -Path "../certbot" -ErrorAction Stop

Write-Output "Setting up the certificate..."
docker compose run --rm certbot certonly --webroot --webroot-path /var/www/certbot/ -d $DOMAIN

Set-Location -Path "../nginx" -ErrorAction Stop
docker compose down
Get-Content ./template/ssl.conf | Set-Content ./conf/"$DOMAIN".conf
docker compose up -d
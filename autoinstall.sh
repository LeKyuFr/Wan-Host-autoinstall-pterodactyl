#!/bin/bash
#!/usr/bin/env bash

########################################################################
#                                                                      #
#            Pterodactyl Installer, Updater, Remover and More          #
#            Copyright 2022, Malthe K, <me@malthe.cc>                  # 
# https://github.com/guldkage/Pterodactyl-Installer/blob/main/LICENSE  #
#                                                                      #
#  This script is not associated with the official Pterodactyl Panel.  #
#  You may not remove this line                                        #
#                                                                      #
########################################################################

dist="$(. /etc/os-release && echo "$ID")"
version="$(. /etc/os-release && echo "$VERSION_ID")"

finish(){
    clear
    echo ""
    echo "[!] Panel installed."
    echo ""
    echo "Admin user created with the following credentials:"
    echo "Username: admin"
    echo "Password: admin"
    echo "First Name: admin"
    echo "Last Name: admin"
    echo "Email: $EMAIL"
    echo "FQDN: $FQDN"
}

panel_conf(){
    [ "$SSL" == "true" ] && appurl="https://$FQDN" || appurl="http://$FQDN"
    DBPASSWORD=$(LC_ALL=C </dev/urandom tr -dc '[:alnum:]' | fold -w 16 | head -n 1)
    mariadb -u root -e "CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DBPASSWORD';" && mariadb -u root -e "CREATE DATABASE panel;" && mariadb -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;" && mariadb -u root -e "FLUSH PRIVILEGES;"
    php artisan p:environment:setup --author="$EMAIL" --url="$appurl" --timezone="CET" --telemetry=false --cache="redis" --session="redis" --queue="redis" --redis-host="localhost" --redis-pass="null" --redis-port="6379" --settings-ui=true
    php artisan p:environment:database --host="127.0.0.1" --port="3306" --database="panel" --username="pterodactyl" --password="$DBPASSWORD"
    php artisan migrate --seed --force
    php artisan p:user:make --email="$EMAIL" --username="admin" --name-first="admin" --name-last="admin" --password="admin" --admin=1
    chown -R www-data:www-data /var/www/pterodactyl/*
    curl -o /etc/systemd/system/pteroq.service https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pteroq.service
    (crontab -l ; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1")| crontab -
    sudo systemctl enable --now redis-server
    sudo systemctl enable --now pteroq.service
    [ "$WINGS" == true ] && curl -sSL https://get.docker.com/ | CHANNEL=stable bash && systemctl enable --now docker && mkdir -p /etc/pterodactyl && apt-get -y install curl tar unzip && curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")" && curl -o /etc/systemd/system/wings.service https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/wings.service && chmod u+x /usr/local/bin/wings
    if  [ "$SSL" == "true" ]; then
        rm -rf /etc/nginx/sites-enabled/default
        curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx-ssl.conf
        sed -i "s@<domain>@$FQDN@g" /etc/nginx/sites-enabled/pterodactyl.conf
        systemctl stop nginx
        certbot certonly --standalone -d $FQDN --staple-ocsp --no-eff-email -m $EMAIL --agree-tos
        systemctl start nginx
        finish
    fi
    if  [ "$SSL" == "false" ]; then
        rm -rf /etc/nginx/sites-enabled/default
        curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/guldkage/Pterodactyl-Installer/main/configs/pterodactyl-nginx.conf
        sed -i "s@<domain>@$FQDN@g" /etc/nginx/sites-enabled/pterodactyl.conf
        systemctl restart nginx
        finish
    fi
}

panel_install(){
    echo "" 
    apt update
    apt install certbot -y
    if  [ "$dist" == "ubuntu" ] && [ "$version" == "20.04" ]; then
        apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
        curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor --batch --yes -o /usr/share/keyrings/redis-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
        apt update
        sudo add-apt-repository "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) universe"
    fi
    if [ "$dist" == "debian" ] && [ "$version" == "11" ]; then
        apt -y install software-properties-common curl ca-certificates gnupg2 sudo lsb-release
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/sury-php.list
        curl -fsSL  https://packages.sury.org/php/apt.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg
        curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
        apt update -y
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
    fi
    if [ "$dist" == "debian" ] && [ "$version" == "12" ]; then
        apt -y install software-properties-common curl ca-certificates gnupg2 sudo lsb-release
        sudo apt install -y apt-transport-https lsb-release ca-certificates wget
        wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list
        curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
        apt update -y
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
    fi
    apt install -y mariadb-server tar unzip git redis-server
    sed -i 's/character-set-collations = utf8mb4=uca1400_ai_ci/character-set-collations = utf8mb4=utf8mb4_general_ci/' /etc/mysql/mariadb.conf.d/50-server.cnf
    systemctl restart mariadb
    apt -y install php8.1 php8.1-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip}
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    sleep 0.5s
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl || exit
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/
    cp .env.example .env
    composer install --no-dev --optimize-autoloader --no-interaction
    php artisan key:generate --force
    apt install nginx -y
    panel_conf
}

FQDN="$1"
SSL="$2"
EMAIL="$3"
USERNAME="admin"
FIRSTNAME="admin"
LASTNAME="admin"
PASSWORD="admin"
WINGS="$4"

if [ -z "$FQDN" ] || [ -z "$SSL" ] || [ -z "$EMAIL" ]; then
    echo "Error! The usage of this script is incorrect."
    exit 1
fi

echo "Checking your OS.."
if [ "$dist" == "ubuntu" ] && [ "$version" == "20.04" ] || [ "$dist" == "debian" ] && [ "$version" == "11" ] || [ "$dist" == "debian" ] && [ "$version" == "12" ]; then
    echo "Welcome to Autoinstall of Pterodactyl Panel"
    echo "Quick summary before the install begins:"
    echo ""
    echo "FQDN (URL): $FQDN"
    echo "SSL: $SSL"
    echo "Preselected webserver: NGINX"
    echo "Email: $EMAIL"
    echo "Default Admin User Credentials:"
    echo "Username: $USERNAME"
    echo "Password: $PASSWORD"
    echo "First Name: $FIRSTNAME"
    echo "Last Name: $LASTNAME"
    echo ""
    echo "Starting automatic installation in 5 seconds"
    sleep 5s
    panel_install
else
    echo "Your OS, $dist $version, is not supported"
    exit 1
fi

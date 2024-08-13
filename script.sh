#!/bin/bash

# Define colors for output
green_color="\033[1;32m"
no_color="\033[0m"
script_log_file="script_log.log"
MYSQL_ROOT_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)

# Function to log messages
log() {
    echo "$1" | tee -a $script_log_file
}

# Function to check for command success
check_success() {
    if [ $? -eq 0 ]; then
        log "${green_color}[SUCCESS]${no_color}"
    else
        log "${green_color}[FAILURE]${no_color}"
        exit 1
    fi
}

# Get domain argument
while getopts d: flag; do
    case "${flag}" in
        d) domain=${OPTARG};;
        *) echo "Usage: $0 -d domain" >&2; exit 1;;
    esac
done

if [ -z "$domain" ]; then
    echo "Domain is required. Usage: $0 -d domain"
    exit 1
fi

log "${no_color}PREPARING INSTALLATION"
sudo rm -rf /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend /var/cache/apt/archives/lock >> $script_log_file 2>&1
sudo apt-get update >> $script_log_file 2>&1
check_success

log "${no_color}REMOVING APACHE"
sudo apt-get purge -y apache2 apache2-* >> $script_log_file 2>&1
sudo kill -9 $(sudo lsof -t -i:80) 2>/dev/null
sudo kill -9 $(sudo lsof -t -i:443) 2>/dev/null
check_success

log "${no_color}INSTALLING NGINX"
sudo apt-get install -y nginx >> $script_log_file 2>&1
check_success

log "${no_color}OPEN NGINX PORTS"
sudo ufw allow 'Nginx Full' >> $script_log_file 2>&1
sudo ufw allow 'OpenSSH' >> $script_log_file 2>&1
check_success

log "${no_color}RESTARTING NGINX"
sudo systemctl restart nginx >> $script_log_file 2>&1
check_success

log "${no_color}INSTALLING PHP 8.2"
sudo apt-get install -y lsb-release ca-certificates apt-transport-https software-properties-common >> $script_log_file 2>&1
sudo add-apt-repository ppa:ondrej/php -y >> $script_log_file 2>&1
sudo apt-get update >> $script_log_file 2>&1
sudo apt-get install -y php8.2 php8.2-fpm php8.2-common php8.2-curl php8.2-mbstring php8.2-mysql php8.2-xml php8.2-zip php8.2-gd php8.2-cli php8.2-imagick php8.2-intl >> $script_log_file 2>&1
check_success

log "${no_color}INSTALLING PHP 8.3"
sudo apt-get install -y php8.3 php8.3-fpm php8.3-redis php8.3-common php8.3-curl php8.3-mbstring php8.3-mysql php8.3-xml php8.3-zip php8.3-gd php8.3-cli php8.3-imagick php8.3-intl >> $script_log_file 2>&1
check_success

log "${no_color}INSTALLING NPM"
sudo apt-get install -y npm >> $script_log_file 2>&1
check_success

log "${no_color}INSTALLING CERTBOT (SSL GENERATOR)"
sudo apt-get install -y snapd >> $script_log_file 2>&1
sudo snap install core >> $script_log_file 2>&1
sudo snap install --classic certbot >> $script_log_file 2>&1
sudo ln -s /snap/bin/certbot /usr/bin/certbot >> $script_log_file 2>&1
check_success

log "${no_color}INSTALLING COMPOSER"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" >> $script_log_file 2>&1
php composer-setup.php >> $script_log_file 2>&1
sudo mv composer.phar /usr/local/bin/composer >> $script_log_file 2>&1
check_success

log "${no_color}CREATING NGINX FILE FOR $domain"
sudo tee /etc/nginx/sites-available/$domain > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    root /var/www/html/$domain/public;
    index index.php index.html index.htm;
    server_name $domain www.$domain;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/ >> $script_log_file 2>&1
sudo mkdir -p /var/www/html/$domain/public >> $script_log_file 2>&1
sudo tee /var/www/html/$domain/public/index.php > /dev/null <<EOF
<h1 style="color:#0194fe">Welcome</h1>
<h4 style="color:#0194fe">$domain</h4>
EOF
check_success

log "${no_color}GENERATING SSL CERTIFICATE FOR $domain"
sudo certbot --nginx -d $domain -d www.$domain --non-interactive --agree-tos -m admin@$domain >> $script_log_file 2>&1
check_success

log "${no_color}INSTALLING MYSQL"
export DEBIAN_FRONTEND=noninteractive
echo "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | sudo debconf-set-selections
sudo apt-get install -y mysql-server >> $script_log_file 2>&1

log "${no_color}SECURING MYSQL"
sudo apt-get install -y expect >> $script_log_file 2>&1
sudo tee ~/secure_our_mysql.sh > /dev/null <<EOF
spawn $(which mysql_secure_installation)

expect "Enter password for user root:"
send "$MYSQL_ROOT_PASSWORD\r"
expect "Press y|Y for Yes, any other key for No:"
send "y\r"
expect "Please enter 0 = LOW, 1 = MEDIUM and 2 = STRONG:"
send "0\r"
expect "Change the password for root ? ((Press y|Y for Yes, any other key for No) :"
send "n\r"
expect "Remove anonymous users? (Press y|Y for Yes, any other key for No) :"
send "y\r"
expect "Disallow root login remotely? (Press y|Y for Yes, any other key for No) :"
send "n\r"
expect "Remove test database and access to it? (Press y|Y for Yes, any other key for No) :"
send "y\r"
expect "Reload privilege tables now? (Press y|Y for Yes, any other key for No) :"
send "y\r"
EOF
sudo expect ~/secure_our_mysql.sh >> $script_log_file 2>&1
rm -f ~/secure_our_mysql.sh >> $script_log_file 2>&1
echo $MYSQL_ROOT_PASSWORD | sudo tee /var/www/html/mysql >> $script_log_file 2>&1
check_success

log "${no_color}CHANGING PHP FPM UPLOAD VALUES"
sudo sed -i 's/post_max_size = 8M/post_max_size = 1000M/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 1000M/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/max_execution_time = 30/max_execution_time = 300/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/memory_limit = 128/memory_limit = 12800/' /etc/php/8.2/fpm/php.ini
sudo systemctl restart php8.2-fpm
check_success

# log "${no_color}PUSHING CRONJOBS"
# (crontab -l 2>/dev/null; echo "################## START $domain ####################") | crontab -
# (crontab -l 2>/dev/null; echo "* * * * * cd /var/www/html/$domain && rm -rf ./.git/index.lock && rm -rf ./.git/index && git reset --hard HEAD && git clean -f -d && git pull origin master --allow-unrelated-histories") | crontab -
# (crontab -l 2>/dev/null; echo "* * * * * cd /var/www/html/$domain && php artisan queue:restart && php artisan queue:work >> /dev/null 2>&1") | crontab -
# (crontab -l 2>/dev/null; echo "* * * * * cd /var/www/html/$domain && php artisan schedule:run >> /dev/null 2>&1") | crontab -
# (crontab -l 2>/dev/null; echo "* * * * * cd /var/www/html/$domain && chmod -R 777 *") | crontab -
# (crontab -l 2>/dev/null; echo "################## END $domain ####################") | crontab -
# echo $green_color"[SUCCESS]";
# echo $green_color"[######################################]";

log "${no_color}FINALIZE INSTALLING"
sudo apt-get autoremove -y >> $script_log_file 2>/dev/null
sudo bash -c "echo 'net.core.netdev_max_backlog = 65535'" | sudo tee -a /etc/sysctl.conf >> $script_log_file 2>/dev/null
sudo bash -c "echo 'net.core.somaxconn = 65535'" | sudo tee -a /etc/sysctl.conf >> $script_log_file 2>/dev/null
sudo apt-get autoclean -y >> $script_log_file 2>/dev/null
sudo apt-get update >> $script_log_file 2>/dev/null
echo $green_color"[SUCCESS]";
echo $green_color"[######################################]";

log "${green_color}[MADE WITH LOVE BY Ahmad Chebbo]";
echo $green_color"[####################]";

log "${no_color}SETTING UP LOG FILE PERMISSIONS";
sudo chmod 640 $script_log_file >> $script_log_file 2>/dev/null
sudo chown root:adm $script_log_file >> $script_log_file 2>/dev/null
echo $green_color"[SUCCESS]";
echo $green_color"[######################################]";

log "${no_color}REVIEWING LOG FILE CONTENT";
tail -n 20 $script_log_file >> $script_log_file
echo $green_color"[SUCCESS]";
echo $green_color"[######################################]";

log "${no_color}FINAL CHECKS";
# Check nginx status
if systemctl is-active --quiet nginx; then
    echo $green_color"NGINX IS RUNNING";
else
    echo $no_color"NGINX IS NOT RUNNING";
fi

# Check php8.2-fpm status
if systemctl is-active --quiet php8.2-fpm; then
    echo $green_color"PHP 8.2 FPM IS RUNNING";
else
    echo $no_color"PHP 8.2 FPM IS NOT RUNNING";
fi

# Check php8.3-fpm status
if systemctl is-active --quiet php8.3-fpm; then
    echo $green_color"PHP 8.3 FPM IS RUNNING";
else
    echo $no_color"PHP 8.3 FPM IS NOT RUNNING";
fi

# Check MySQL status
if systemctl is-active --quiet mysql; then
    echo $green_color"MYSQL IS RUNNING";
else
    echo $no_color"MYSQL IS NOT RUNNING";
fi

echo $green_color"[####################]";

echo $no_color"INSTALLATION COMPLETED. PLEASE REVIEW LOG FILE FOR DETAILS.";


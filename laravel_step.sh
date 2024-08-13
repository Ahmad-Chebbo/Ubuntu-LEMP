#!/bin/sh

# Variables
script_log_file="laravel_script_log.log"
green_color="\033[1;32m"
no_color="\033[0m"
DB_NAME=""
DB_USER="root"
DB_PASSWORD=""

# Logging function
log() {
    echo "$1" | tee -a $script_log_file
}


# Get user inputs
read -p "Enter GitHub/GitLab repository URL (e.g., https://github.com/username/repo.git): " repo_url
read -p "Enter domain name (e.g., example.com): " domain
read -p "Enter database name: " DB_NAME
read -p "Enter database username: " DB_USER
read -p "Enter database password: " DB_PASSWORD
# Install dependencies
log "${no_color}INSTALLING DEPENDENCIES"
sudo apt-get update >> $script_log_file 2>/dev/null
sudo apt-get install -y git unzip nginx php-fpm php-mysql mysql-server ufw certbot python3-certbot-nginx >> $script_log_file 2>/dev/null

# Install Composer
# if ! [ -x "$(command -v composer)" ]; then
#     log "${no_color}INSTALLING COMPOSER"
#     php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" >> $script_log_file 2>/dev/null
#     php composer-setup.php >> $script_log_file 2>/dev/null
#     sudo mv composer.phar /usr/local/bin/composer >> $script_log_file 2>/dev/null
#     log $green_color"[SUCCESS]"
#     log $green_color"[######################################]"
# else
#     log "${green_color}COMPOSER ALREADY INSTALLED!"
# fi

# Clone repository
log "${no_color}CLONING REPOSITORY"
read -sp "Enter repository username (if private): " repo_user
read -sp "Enter repository password (if private): " repo_pass
echo
sudo git clone https://$repo_user:$repo_pass@$repo_url /var/www/$domain >> $script_log_file 2>/dev/null
log $green_color"[SUCCESS]"
log $green_color"[######################################]"

# Set up environment
log "${no_color}SETTING UP ENVIRONMENT"
cd /var/www/$domain
sudo cp .env.example .env
sudo chmod -R 755 /var/www/$domain/storage
sudo chown -R www-data:www-data /var/www/$domain/storage
sudo chmod -R 755 /var/www/$domain/bootstrap/cache
sudo chown -R www-data:www-data /var/www/$domain/bootstrap/cache
php artisan key:generate

# Update .env with database credentials
log "${no_color}UPDATING .ENV FILE"
sudo sed -i "s/DB_CONNECTION=mysql/DB_CONNECTION=mysql/" .env
sudo sed -i "s/DB_HOST=127.0.0.1/DB_HOST=127.0.0.1/" .env
sudo sed -i "s/DB_PORT=3306/DB_PORT=3306/" .env
sudo sed -i "s/DB_DATABASE=laravel/DB_DATABASE=$DB_NAME/" .env
sudo sed -i "s/DB_USERNAME=root/DB_USERNAME=$DB_USER/" .env
sudo sed -i "s/DB_PASSWORD=/DB_PASSWORD=$DB_PASSWORD/" .env
log $green_color"[SUCCESS]"
log $green_color"[######################################]"

# Install PHP dependencies
composer install --no-dev --optimize-autoloader >> $script_log_file 2>/dev/null

# Check and create database if needed
log "${no_color}CHECKING CREATING DATABASE"
# DB_NAME="${domain//./_}"
DB_EXISTS=$(echo "SHOW DATABASES LIKE '$DB_NAME';" | mysql -u root -p$DB_PASSWORD -s --skip-column-names)
if [ -z "$DB_EXISTS" ]; then
    echo "CREATE DATABASE $DB_NAME;" | mysql -u root -p$DB_PASSWORD
    echo "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';" | mysql -u root -p$DB_PASSWORD
    echo "FLUSH PRIVILEGES;" | mysql -u root -p$DB_PASSWORD
    log $green_color"[DATABASE CREATED]"
else
    log $green_color"[DATABASE ALREADY EXISTS]"
fi
log $green_color"[######################################]"

# Configure Nginx
log "${no_color}CONFIGURING NGINX"
sudo tee /etc/nginx/sites-available/$domain << EOF > /dev/null
server {
    listen 80;
    server_name $domain www.$domain;

    root /var/www/$domain/public;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$SCRIPT_FILENAME;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/ >> $script_log_file 2>/dev/null
sudo nginx -t >> $script_log_file 2>/dev/null
sudo systemctl reload nginx >> $script_log_file 2>/dev/null
log $green_color"[SUCCESS]"
log $green_color"[######################################]"

# Generate SSL certificate
log "${no_color}GENERATING SSL CERTIFICATE"
sudo certbot --nginx -d $domain -d www.$domain --non-interactive --agree-tos -m admin@$domain >> $script_log_file 2>/dev/null
log $green_color"[SUCCESS]"
log $green_color"[######################################]"

# Set up cron jobs
# log "${no_color}SETTING UP CRON JOBS"
# (crontab -l 2>/dev/null; echo "* * * * * cd /var/www/$domain && php artisan schedule:run >> /dev/null 2>&1") | crontab -
# log $green_color"[SUCCESS]"
# log $green_color"[######################################]"

# Finalize setup
log "${no_color}FINALIZING SETUP"
sudo apt-get autoremove -y >> $script_log_file 2>/dev/null
sudo apt-get autoclean -y >> $script_log_file 2>/dev/null
echo $green_color"[SUCCESS]"
echo $green_color"[######################################]"

log "${green_color}[INSTALLATION COMPLETE]";
echo $green_color"[####################]";


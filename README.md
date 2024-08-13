# About

### install Important softwares on fresh Ubuntu instance

- ✅  PREPAIRE Installing
- ✅  REMOVING APACHE
- ✅  Installing PHP 8.2
- ✅  Installing PHP 8.3
- ✅  Installing NGINX
- ✅  OPEN NGINX PORTS
- ✅  Installing PHP EXTENSIONS
- ✅  INCREASING FPM UPLOAD VALUES
- ✅  Installing NPM
- ✅  Installing CERTBOT (SSL GENERATOR)
- ✅  CREATING NGINX FILE FOR [example.com](http://example.com/)
- ✅  GENERATING SSL CERTIFICATE FOR [example.com](http://example.com/)
- ✅  Finalize Installing
- ✅  Installing MySQL
- ✅  Pushing Cronjobs

### How to Use the LEMP script

```php

wget -q https://raw.githubusercontent.com/ahmad-chebbo/ubuntu-lemp/main/script.sh -O script.sh ; sudo chmod +x script.sh ; ./script.sh -d example.com
# Replace example.com with your domain
```
### How to Use the laravel setup script

```php

wget -q https://raw.githubusercontent.com/ahmad-chebbo/ubuntu-lemp/main/laravel_setup.sh -O script.sh ; sudo chmod +x laravel_setup.sh ; ./laravel_setup.sh -d example.com
# Replace example.com with your domain
```

### How To Debug LIVE

```php
tail -f script_log.log
```

### 
Made With Love By [AhmadChebbo](https://dotzonegrp.com/)

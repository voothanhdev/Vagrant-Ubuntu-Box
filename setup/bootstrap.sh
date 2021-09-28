#!/bin/bash

# Enviroment variable
#
export MYSQL_PASS="pass@root"
export MACHINE_PASS="vagrant"
export PHP_VERSION="7.1"
export GIT_NAME=""
export GIT_EMAIL=""


echo "(Setting up your Vagrant box...)"
echo ">>>>>>>>>>>>>>>>>>>>> Updating repository <<<<<<<<<<<<<<<<<<<<"
sudo apt-get update > /dev/null 2>&1
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8 > /dev/null 2>&1
sudo sh -c "echo 'deb [arch=amd64,i386] https://mirrors.evowise.com/mariadb/repo/10.3/ubuntu '$(lsb_release -cs)' main' > /etc/apt/sources.list.d/MariaDB-10.3.list" > /dev/null 2>&1
sudo add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
sudo add-apt-repository -y ppa:ondrej/nginx > /dev/null 2>&1
sudo apt-get update > /dev/null 2>&1

echo "-------------------------Update done!-------------------------"

# Nginx
echo ">>>>>>>>>>>>>>>>>>>>>> Installing Nginx <<<<<<<<<<<<<<<<<<<<<<"
sudo apt-get install -y nginx > /dev/null 2>&1
sudo systemctl enable nginx > /dev/null 2>&1
sudo systemctl start nginx > /dev/null 2>&1
sudo touch /etc/nginx/sites-available/magento
sudo printf "
upstream fastcgi_backend { 
     server  unix:/run/php/php$PHP_VERSION-fpm.sock; 
} 

server { 
     listen 80; 
     server_name www.ufo.jvo ufo.jvo; 
     set \$MAGE_ROOT /project/Urbanfox; 
     include /project/Urbanfox/nginx.conf.sample; 
}
" >> /etc/nginx/sites-available/magento
sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/mysite > /dev/null 2>&1
systemctl status nginx

echo "-----------------------Nginx Installed------------------------"

# Add user to www-data group
sudo usermod -a -G www-data vagrant
sudo mkdir /project
sudo chown -R vagrant:www-data /project
sudo chmod -R 755 /project

# Config git
if [[ $GIT_NAME != '' ]]; then
	git config --global user.name "$GIT_NAME";
fi
if [[ $GIT_EMAIL != '' ]]; then
	git config --global user.email "$GIT_EMAIL";
fi
git config --global core.filemode false

# MariaDB
echo ">>>>>>>>>>>>>>>>>>>>> Installing MariaDB <<<<<<<<<<<<<<<<<<<<<"
sudo debconf-set-selections <<< "mariadb-server mysql-server/root_password password $MYSQL_PASS"
sudo debconf-set-selections <<< "mariadb-server mysql-server/root_password_again password $MYSQL_PASS"
sudo apt-get install -y mariadb-server > /dev/null 2>&1
sudo systemctl enable mysql > /dev/null 2>&1
sudo systemctl start mysql > /dev/null 2>&1

echo "grant all privileges on *.* to root@localhost identified by '$MYSQL_PASS';" | mysql -uroot -p$MYSQL_PASS -Dmysql > /dev/null 2>&1
echo "grant all privileges on *.* to root@127.0.0.1 identified by '$MYSQL_PASS';" | mysql -uroot -p$MYSQL_PASS -Dmysql > /dev/null 2>&1
echo "flush privileges;" | mysql -uroot -p$MYSQL_PASS -Dmysql > /dev/null 2>&1
sudo sed -i 's/max_allowed_packet	= 16M/max_allowed_packet	= 1024M/g' /etc/mysql/my.cnf
sudo systemctl restart mysql
systemctl status mysql

echo "---------------------MariaDB Installed-----------------------"

# PHP
echo ">>>>>>>>>>>>>>>>>>>>>> Installing PHP <<<<<<<<<<<<<<<<<<<<<<<"
sudo apt-get install -y php$PHP_VERSION-fpm \
php$PHP_VERSION-cli \
php$PHP_VERSION-common \
php$PHP_VERSION-gd \
php$PHP_VERSION-mysql \
php$PHP_VERSION-mcrypt \
php$PHP_VERSION-curl \
php$PHP_VERSION-intl \
php$PHP_VERSION-xsl \
php$PHP_VERSION-mbstring \
php$PHP_VERSION-zip \
php$PHP_VERSION-bcmath \
php$PHP_VERSION-iconv \
php$PHP_VERSION-soap \
php$PHP_VERSION-xdebug > /dev/null 2>&1

sudo printf "
[XDEBUG]
zend_extension=\"/usr/lib/php/20160303/xdebug.so\"
xdebug.remote_enable=1
xdebug.remote_handler=dbgp 
xdebug.remote_mode=req
xdebug.remote_host=127.0.0.1
xdebug.remote_port=9000
" >> /etc/php/$PHP_VERSION/fpm/php.ini
sudo sed -i 's/display_errors = Off/display_errors = On/g' /etc/php/$PHP_VERSION/fpm/php.ini
sudo sed -i 's/max_execution_time = 30/max_execution_time = 1800/g' /etc/php/$PHP_VERSION/fpm/php.ini
sudo sed -i 's/memory_limit = 128M/memory_limit = 2G/g' /etc/php/$PHP_VERSION/fpm/php.ini
sudo sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 2G/g' /etc/php/$PHP_VERSION/fpm/php.ini
sudo sed -i 's/post_max_size = 2G/post_max_size = 2G/g' /etc/php/$PHP_VERSION/fpm/php.ini
sudo sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 2G/g' /etc/php/$PHP_VERSION/fpm/php.ini

sudo systemctl enable php$PHP_VERSION-fpm > /dev/null 2>&1
sudo systemctl start php$PHP_VERSION-fpm > /dev/null 2>&1
sudo systemctl restart nginx > /dev/null 2>&1

php -v
echo "-----------------------PHP Installed--------------------------"

# Composer
echo ">>>>>>>>>>>>>>>>>>>>> Installing Composer <<<<<<<<<<<<<<<<<<<<"
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/bin --filename=composer > /dev/null 2>&1
sudo -u vagrant -H sh -c "composer global require hirak/prestissimo"
sudo -u vagrant -H sh -c "composer global require \"squizlabs/php_codesniffer=*\""
composer

echo "--------------------Composer Installed------------------------"

# PHPStorm
echo ">>>>>>>>>>>>>>>>>>>>> Installing PHPstorm <<<<<<<<<<<<<<<<<<<<"
sudo snap install phpstorm --classic > /dev/null 2>&1
echo "-------------------PHPStorm Installed--------------------------"

echo ">>>>>>>>>>>>>>>> Installing Magento tools ... <<<<<<<<<<<<<<<<"
wget https://files.magerun.net/n98-magerun2.phar > /dev/null 2>&1
chmod +x n98-magerun2.phar > /dev/null 2>&1
sudo mv n98-magerun2.phar /usr/bin/mgt > /dev/null 2>&1

echo "-------------------------------------------------------------"

echo "(Setting Ubuntu (user) password to \"vagrant\"...)"

echo "vagrant:$MACHINE_PASS" | chpasswd

sudo -u vagrant -H sh -c "ssh-keygen -t rsa -b 4096 -C \"$GIT_EMAIL\" -f \"/home/vagrant/.ssh/id_rsa\" -q -N \"\""
cat /home/vagrant/.ssh/id

echo "+---------------------------------------------------------+"
echo "|                      S U C C E S S                      |"
echo "+---------------------------------------------------------+"
echo "|   You're good to go! You can now view your server at    |"
echo "|      \"127.0.0.1/\" or private ip in a browser.         |"
echo "|                                                         |"
echo "|          You can SSH in with vagrant / vagrant          |"
echo "|                                                         |"
echo "|      You can login to MySQL with root / $MYSQL_PASS     |"
echo "+---------------------------------------------------------+"

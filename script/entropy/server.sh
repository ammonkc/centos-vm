#!/bin/bash -eux

echo "==> Installing Apache"

yum -y install httpd mod_ssl mod_fastcgi

# Start httpd service
systemctl enable httpd.service
systemctl start httpd.service

# Disable sendfile
sed -i 's/#EnableSendfile off/EnableSendfile off/g' /etc/httpd/conf/httpd.conf
# vhosts.conf
cat <<EOF > /etc/httpd/conf.d/vhosts.conf
    ServerName entropy.dev
    # virtualHost
    NameVirtualHost *:80
    NameVirtualHost *:443
    # Load vhost configs from enabled directory
    Include conf/vhosts/enabled/*.conf
EOF
# cache.conf
cat <<EOF > /etc/httpd/conf.d/cache.conf
<filesMatch "\.(html|htm|js|css)$">
  FileETag None
  <ifModule mod_headers.c>
     Header unset ETag
     Header set Cache-Control "max-age=0, no-cache, no-store, must-revalidate"
     Header set Pragma "no-cache"
     Header set Expires "Wed, 11 Jan 1984 05:00:00 GMT"
  </ifModule>
</filesMatch>
EOF

# create directory for vhosts
mkdir -p /etc/httpd/conf/vhosts/{available,enabled}

echo "==> Installing PHP-FPM"
if [ "$PHP_VERSION" = "php56" ]; then
  yum --enablerepo=remi,remi-php56 -y install php-common php-cli php-pear php-fpm php-pdo php-gd php-xml php-mbstring php-mcrypt
else
  yum --enablerepo=remi,remi-php71 -y install php-common php-cli php-pear php-fpm php-pdo php-gd php-xml php-mbstring php-mcrypt
fi

# Start php-fpm service
systemctl enable php-fpm.service
systemctl start php-fpm.service
#Configure Apache to use mod_fastcgi
sed -i 's/FastCgiWrapper On/FastCgiWrapper Off/g' /etc/httpd/conf.d/fastcgi.conf
echo -e "<IfModule mod_fastcgi.c>\nDirectoryIndex index.html index.shtml index.cgi index.php\nAddHandler php5-fcgi .php\nAction php5-fcgi /php5-fcgi\nAlias /php5-fcgi /usr/lib/cgi-bin/php5-fcgi\nFastCgiExternalServer /usr/lib/cgi-bin/php5-fcgi -host 127.0.0.1:9000 -pass-header Authorization\n</IfModule>" >> /etc/httpd/conf.d/fastcgi.conf
mkdir /usr/lib/cgi-bin/
# Fix Permissions
chown -R apache:apache /var/run/mod_fastcgi
# optimise php-fpm
echo -e "include=/etc/php-fpm.d/*.conf" >> /etc/php-fpm.conf
sed -i 's/;listen.backlog = -1/listen.backlog = 1000/' /etc/php-fpm.d/www.conf
sed -i 's/pm.max_children = 50/pm.max_children = 512/' /etc/php-fpm.d/www.conf
sed -i 's/pm.start_servers = 5/pm.start_servers = 16/' /etc/php-fpm.d/www.conf
sed -i 's/pm.min_spare_servers = 5/pm.min_spare_servers = 10/' /etc/php-fpm.d/www.conf
sed -i 's/pm.max_spare_servers = 35/pm.max_spare_servers = 64/' /etc/php-fpm.d/www.conf
sed -i 's/;pm.max_requests = 500/pm.max_requests = 5000/' /etc/php-fpm.d/www.conf
sed -i 's/;rlimit_files = 1024/rlimit_files = 102400/' /etc/php-fpm.d/www.conf

# Set php timezone
sed -i 's|;date.timezone =|date.timezone = Pacific/Honolulu|' /etc/php.ini

echo "==> Installing mysqld"
if [ "$PHP_VERSION" = "php56" ]; then
  yum --enablerepo=remi,remi-php56 -y install mysql mysql-devel mysql-server php-mysqlnd
else
  yum --enablerepo=remi,remi-php71 -y install mariadb mariadb-devel mariadb-server php-mysqlnd
fi
# Start mysqld service
systemctl enable mysqld.service
systemctl start  mysqld.service
# Mysql privileges
mysql -e "GRANT ALL ON *.* TO 'entropy'@'%' WITH GRANT OPTION; UPDATE mysql.user SET Password = PASSWORD('secret') WHERE User='entropy'; FLUSH PRIVILEGES;" > /dev/null 2>&1
mysql -e "GRANT ALL ON *.* TO 'entropy'@'localhost' WITH GRANT OPTION; UPDATE mysql.user SET Password = PASSWORD('secret') WHERE User='entropy'; FLUSH PRIVILEGES;" > /dev/null 2>&1
mysql -e "GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION; UPDATE mysql.user SET Password = PASSWORD('Dbr00+') WHERE User='root'; FLUSH PRIVILEGES;" > /dev/null 2>&1

echo "==> Installing postgreSQL"
yum -y install postgresql96-server postgresql96-contrib
/usr/pgsql-9.6/bin/postgresql96-setup initdb
systemctl enable postgresql-9.6
sed -i "s|host    all             all             127.0.0.1/32            ident|host    all             all             127.0.0.1/32            md5|" /var/lib/pgsql/9.6/data/pg_hba.conf
sed -i "s|host    all             all             ::1/128                 ident|host    all             all             ::1/128                 md5|" /var/lib/pgsql/9.6/data/pg_hba.conf
echo -e "host    all             all             10.0.2.2/32               md5" >> /var/lib/pgsql/9.6/data/pg_hba.conf
systemctl start postgresql-9.6
su postgres -c "psql -U postgres -c \"CREATE USER \"entropy\" WITH PASSWORD 'secret';\""
su postgres -c "psql -U postgres -c \"ALTER USER entropy WITH SUPERUSER;\""
su postgres -c "createdb -O entropy 'entropy'"

echo "==> Installing nodejs modules"
yum -y install nodejs npm
npm install -g bower gulp grunt clean-css

echo "==> Installing composer"

curl -sS https://getcomposer.org/installer | /usr/bin/php
mv composer.phar /usr/local/bin/composer
chmod 755 /usr/local/bin/composer
/usr/local/bin/composer self-update

echo "==> Installing laravel"

curl -sS http://laravel.com/laravel.phar -o /usr/local/bin/laravel
chmod 755 /usr/local/bin/laravel

echo "==> Installing laravel/envoy"

/usr/local/bin/composer global require "laravel/envoy=~1.0"

echo "==> Installing Beanstalkd"

# Install Beanstalkd
# -y --force-yes
yum -y install beanstalkd
# Set to start on system start
systemctl enable beanstalkd.service
# Start Beanstalkd
systemctl start beanstalkd.service

echo "==> Installing Supervisord"

# Install Supervisord
# -y --force-yes
yum -y install supervisor
# Set to start on system start
systemctl enable supervisord.service
# Start Supervisord
systemctl start supervisord.service

echo ">>> Installing memcached"

if [ "$PHP_VERSION" = "php56" ]; then
  yum --enablerepo=remi,remi-php56 -y install php-pecl-memcached memcached libmemcached-devel
else
  yum --enablerepo=remi,remi-php71 -y install php-pecl-memcached memcached libmemcached-devel
fi
sed -i 's/OPTIONS=""/OPTIONS="-l 127.0.0.1"/' /etc/sysconfig/memcached
systemctl enable memcached.service
systemctl start memcached.service

echo "==> Installing redis"
if [ "$PHP_VERSION" = "php56" ]; then
  yum --enablerepo=remi,remi-php56 -y install redis php-redis
else
  yum --enablerepo=remi -y install redis php-redis
fi
systemctl enable redis.service
systemctl start redis.service

echo "==> dnsmasq nameserver"
yum -y install dnsmasq

sed -i 's|#conf-dir=/etc/dnsmasq.d|conf-dir=/etc/dnsmasq.d|' /etc/dnsmasq.conf
cat <<EOF > /etc/dnsmasq.d/entropy.conf
domain-needed
bogus-priv
# listen on both local machine and private network
listen-address=127.0.0.1
listen-address=192.168.10.20
bind-interfaces
# read domain mapping from this file as well as /etc/hosts
addn-hosts=/etc/hosts.dnsmasq
expand-hosts
EOF
cat <<EOF > /etc/dnsmasq.d/dev.conf
domain=dev
local=/dev/
EOF
echo -e "192.168.10.20 entropy.dev" > /etc/hosts.dnsmasq
systemctl enable dnsmasq.service
systemctl start dnsmasq.service

echo "==> Network fix"

cat <<EOF > /etc/start_netfix.sh
rm -f /etc/udev/rules.d/70-persistent-net.rules
sed -i '/HWADDR/d' /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i '/UUID/d' /etc/sysconfig/network-scripts/ifcfg-eth0
rm -f /etc/sysconfig/network-scripts/ifcfg-eth1
EOF

sh /etc/start_netfix.sh

echo "==> Setup NFS"

systemctl enable nfs.service
systemctl start nfs.service

systemctl enable nfslock.service
systemctl start nfslock.service

systemctl enable rpcbind.service
systemctl start rpcbind.service

echo "==> Setup iptables"

iptables -I INPUT -p tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp --dport 443 -j ACCEPT
iptables -I INPUT -p tcp --dport 3306 -j ACCEPT
iptables -I INPUT -p tcp --dport 5432 -j ACCEPT
iptables -I INPUT -p tcp --dport 8081 -j ACCEPT
iptables -I INPUT -p tcp --dport 53 -j ACCEPT
service iptables save

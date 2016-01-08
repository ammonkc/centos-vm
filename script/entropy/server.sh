#!/bin/bash -eux

echo "==> Installing Apache"

yum -y install httpd mod_ssl mod_fastcgi

# Start httpd service
chkconfig httpd --add
chkconfig httpd on --level 2345
service httpd start

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
  yum --enablerepo=remi,remi-php56 -y install php-common php-cli php-pear php-fpm php-gd php-xml php-mbstring php-mcrypt
else
  yum --enablerepo=remi -y install php-common php-cli php-pear php-fpm php-gd php-xml php-mbstring php-mcrypt
fi

# Start php-fpm service
chkconfig php-fpm --add
chkconfig php-fpm on --level 235
service php-fpm start
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

echo "==> Installing HHVM"
yum --nogpgcheck -y install hhvm
cat <<EOF > /etc/rc.d/init.d/hhvm
#!/bin/bash
#
# /etc/rc.d/init.d/hhvm
#
# Starts the hhvm daemon
#
# chkconfig: 345 26 74
# description: HHVM (aka the HipHop Virtual Machine) is an open-source virtual machine designed for executing programs written in Hack and PHP
# processname: hhvm

### BEGIN INIT INFO
# Provides: hhvm
# Required-Start: $local_fs
# Required-Stop: $local_fs
# Default-Start:  2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: start and stop hhvm
# Description: HHVM (aka the HipHop Virtual Machine) is an open-source virtual machine designed for executing programs written in Hack and PHP
### END INIT INFO

# Source function library.
. /etc/rc.d/init.d/functions

# Default values. This values can be overwritten in '/etc/default/hhvm'
CONFIG_FILE="/etc/hhvm/daemon.hdf"
SYSTEM_CONFIG_FILE="/etc/hhvm/php.ini"
RUN_AS_USER="apache"
RUN_AS_GROUP="apache"
ADDITIONAL_ARGS=""

hhvm=/usr/bin/hhvm
prog=`/bin/basename $hhvm`
lockfile=/var/lock/subsys/hhvm
pidfile=/var/run/hhvm/pid
RETVAL=0

test -x /usr/bin/hhvm || exit 1

start() {
    echo -n $"Starting $prog: "
    touch $pidfile
    chown $RUN_AS_USER:$RUN_AS_GROUP $pidfile
    daemon --pidfile ${pidfile} ${hhvm} --config ${CONFIG_FILE} --mode daemon
    RETVAL=$?
    echo
    [ $RETVAL = 0 ] && touch ${lockfile}
    return $RETVAL
}

stop() {
    echo -n $"Stopping $prog: "
    killproc -p ${pidfile} ${prog}
    RETVAL=$?
    echo
    [ $RETVAL = 0 ] && rm -f ${lockfile} ${pidfile}
}

rh_status() {
    status -p ${pidfile} ${hhvm}
}

check_run_dir() {
    # Only perform folder creation, if the PIDFILE location was not modified
    PIDFILE_BASEDIR=$(dirname ${pidfile})
    # We might have a tmpfs /var/run.
    if [ "/var/run/hhvm" = "${PIDFILE_BASEDIR}" ] && [ ! -d /var/run/hhvm ]; then
        mkdir -p -m0755 /var/run/hhvm
        chown $RUN_AS_USER:$RUN_AS_GROUP /var/run/hhvm
    fi
}

case "$1" in
  start)
  check_run_dir
        rh_status >/dev/null 2>&1 && exit 0
        start
        ;;
  stop)
        stop
        ;;

  reload|force-reload|restart|try-restart)
        stop
        start
        ;;

  status)
        rh_status
        RETVAL=$?
        ;;

  *)
        echo "Usage: /etc/init.d/hhvm {start|stop|restart|status}"
        exit 2
esac

exit $RETVAL
EOF

cat <<EOF > /etc/hhvm/daemon.hdf
PidFile = /var/run/hhvm/pid

Server {
  Port = 9001
  Type = fastcgi
  FixPathInfo = true
  DefaultDocument = index.php
}
Log {
  Level = Warning
  AlwaysLogUnhandledExceptions = true
  RuntimeErrorReportingLevel = 8191
  UseLogFile = true
  UseSyslog = false
  File = /var/log/hhvm/error.log
  Access {
    * {
      File = /var/log/hhvm/access.log
      Format = %h %l %u % t \"%r\" %>s %b
    }
  }
}
Eval {
  Jit = true
  EnableHipHopSyntax = true
}
Repo {
  Central {
    Path = /var/log/hhvm/.hhvm.hhbc
  }
}
#include "/usr/share/hhvm/hdf/static.mime-types.hdf"
StaticFile {
  FilesMatch {
    * {
      pattern = .*\.(dll|exe)
      headers {
        * = Content-Disposition: attachment
      }
    }
  }
  Extensions : StaticMimeTypes
}
MySQL {
  TypedResults = false
}
EOF


echo "==> Installing mysqld"
if [ "$PHP_VERSION" = "php56" ]; then
  yum --enablerepo=remi,remi-php56 -y install mysql mysql-devel mysql-server php-mysql
else
  yum --enablerepo=remi -y install mysql mysql-devel mysql-server php-mysql
fi
# Start mysqld service
chkconfig mysqld --add
chkconfig mysqld on --level 2345
service mysqld start
# Mysql privileges
mysql -e "GRANT ALL ON *.* TO 'entropy'@'%' WITH GRANT OPTION; UPDATE mysql.user SET Password = PASSWORD('secret') WHERE User='entropy'; FLUSH PRIVILEGES;" > /dev/null 2>&1
mysql -e "GRANT ALL ON *.* TO 'entropy'@'localhost' WITH GRANT OPTION; UPDATE mysql.user SET Password = PASSWORD('secret') WHERE User='entropy'; FLUSH PRIVILEGES;" > /dev/null 2>&1
mysql -e "GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION; UPDATE mysql.user SET Password = PASSWORD('Dbr00+') WHERE User='root'; FLUSH PRIVILEGES;" > /dev/null 2>&1

echo "==> Installing postgreSQL"
yum -y install postgresql94-server postgresql94-contrib
service postgresql-9.4 initdb
chkconfig postgresql-9.4 --add
chkconfig postgresql-9.4 on --level 2345
sed -i "s|host    all             all             127.0.0.1/32            ident|host    all             all             127.0.0.1/32            md5|" /var/lib/pgsql/9.4/data/pg_hba.conf
sed -i "s|host    all             all             ::1/128                 ident|host    all             all             ::1/128                 md5|" /var/lib/pgsql/9.4/data/pg_hba.conf
echo -e "host    all             all             10.0.2.2/32               md5" >> /var/lib/pgsql/9.4/data/pg_hba.conf
service postgresql-9.4 start
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
chkconfig beanstalkd --add
chkconfig beanstalkd on --level 2345
# Start Beanstalkd
service beanstalkd start

echo "==> Installing Supervisord"

# Install Supervisord
# -y --force-yes
yum -y install supervisor
# Set to start on system start
chkconfig supervisord --add
chkconfig supervisord on --level 2345
# Start Supervisord
service supervisord start

echo ">>> Installing memcached"

if [ "$PHP_VERSION" = "php56" ]; then
  yum --enablerepo=remi,remi-php56 -y install php-pecl-memcached memcached libmemcached-devel
else
  yum --enablerepo=remi -y install php-pecl-memcached memcached libmemcached-devel
fi
sed -i 's/OPTIONS=""/OPTIONS="-l 127.0.0.1"/' /etc/sysconfig/memcached
chkconfig memcached --add
chkconfig memcached on --level 235
service memcached start

echo "==> Installing redis"
if [ "$PHP_VERSION" = "php56" ]; then
  yum --enablerepo=remi,remi-php56 -y install redis php-redis
else
  yum --enablerepo=remi -y install redis php-redis
fi
chkconfig --add redis
chkconfig --level 345 redis on
service redis start

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
chkconfig dnsmasq --add
chkconfig dnsmasq on --level 235
service dnsmasq start

echo "==> Network fix"

cat <<EOF > /etc/start_netfix.sh
rm -f /etc/udev/rules.d/70-persistent-net.rules
sed -i '/HWADDR/d' /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i '/UUID/d' /etc/sysconfig/network-scripts/ifcfg-eth0
rm -f /etc/sysconfig/network-scripts/ifcfg-eth1
EOF

sh /etc/start_netfix.sh

echo "==> Setup NFS"

chkconfig nfs --add
chkconfig nfs on --level 2345
service nfs start

chkconfig nfslock --add
chkconfig nfslock on --level 2345
service nfslock start

chkconfig rpcbind --add
chkconfig rpcbind on --level 2345
service rpcbind start

echo "==> Setup iptables"

iptables -I INPUT -p tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp --dport 443 -j ACCEPT
iptables -I INPUT -p tcp --dport 3306 -j ACCEPT
iptables -I INPUT -p tcp --dport 5432 -j ACCEPT
iptables -I INPUT -p tcp --dport 8081 -j ACCEPT
iptables -I INPUT -p tcp --dport 53 -j ACCEPT
service iptables save

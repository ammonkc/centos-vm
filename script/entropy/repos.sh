#!/bin/bash -eux

echo "==> Install EPEL, remi, hop5, pgdg, and rpmforge yum repos"
yum -y install wget

cd /tmp

if grep -q -i "release 6" /etc/redhat-release ; then
    wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
    wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
    wget -O /etc/yum.repos.d/hop5.repo http://www.hop5.in/yum/el6/hop5.repo
    wget http://yum.postgresql.org/9.4/redhat/rhel-6-x86_64/pgdg-centos94-9.4-1.noarch.rpm
fi

if grep -q -i "release 7" /etc/redhat-release ; then
    wget http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
    wget http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
    wget http://yum.postgresql.org/9.4/redhat/rhel-7-x86_64/pgdg-centos94-9.4-1.noarch.rpm
fi

yum -y install epel-release
rpm -Uvh remi-release-*.rpm pgdg-*.rpm


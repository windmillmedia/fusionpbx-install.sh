#!/bin/sh

VERSION=17.01
EJABBERD_USERNAME=ejabberd
EJABBERD_DATABASE=ejabberd
HOSTNAME=$(hostname -f)

#send a message
echo "Install ejabberd\n"

wget https://www.process-one.net/downloads/ejabberd/${VERSION}/ejabberd_${VERSION}-0_amd64.deb -O /tmp/ejabberd.deb
dpkg -i /tmp/ejabberd.deb

# move config to /etc
cp -a /opt/ejabberd-${VERSION}/conf /etc/ejabberd
# use /etc in ejabberdctl
sed -i "s/: \${ETC_DIR:=.*/: \${ETC_DIR:=\/etc\/ejabberd}/g" /opt/ejabberd-${VERSION}/bin/ejabberdctl

# install systemd service
cp /opt/ejabberd-${VERSION}/bin/ejabberd.service /lib/systemd/system
systemctl daemon-reload
systemctl enable ejabberd.service

password=$(dd if=/dev/urandom bs=1 count=20 2>/dev/null | base64)
cwd=$(pwd)
cd /tmp
#add the databases, users and grant permissions to them
sudo -u postgres psql -c "CREATE DATABASE ${EJABBERD_DATABASE}";
sudo -u postgres psql -c "CREATE ROLE ${EJABBERD_USERNAME} WITH SUPERUSER LOGIN PASSWORD '$password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${EJABBERD_DATABASE} to ${EJABBERD_USERNAME};"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${EJABBERD_DATABASE} to ${EJABBERD_USERNAME};"
sudo -u postgres psql ${EJABBERD_DATABASE} < /opt/ejabberd-${VERSION}/lib/ejabberd-${VERSION}/priv/sql/pg.sql
cd $cwd

cp resources/ejabberd/ejabberd.yml /etc/ejabberd
sed -i /etc/ejabberd/ejabberd.yml -e s:"{ejabberd_database}:$EJABBERD_DATABASE:"
sed -i /etc/ejabberd/ejabberd.yml -e s:"{ejabberd_username}:$EJABBERD_USERNAME:"
sed -i /etc/ejabberd/ejabberd.yml -e s:"{ejabberd_password}:$password:"
sed -i /etc/ejabberd/ejabberd.yml -e s:"{hostname}:$HOSTNAME:"

systemctl start ejabberd.service

password=$(dd if=/dev/urandom bs=1 count=20 2>/dev/null | base64 | sed 's/[=\+//]//g')
# create admin user
/opt/ejabberd-${VERSION}/bin/ejabberdctl change_password admin ${HOSTNAME} ${password}

HOST=$(hostname -I | cut -d ' ' -f1)
echo "ejabberd administrator:"
echo "  admin web interface: http://${HOST}:5280/admin/"
echo "  username: admin@${HOSTNAME}"
echo "  password: ${password}"

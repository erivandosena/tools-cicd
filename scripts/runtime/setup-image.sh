#!/bin/sh
set -eu
chmod 755 /usr/local/bin/*.sh
ln -sf /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner
chmod 755 /opt/sonar-scanner/bin/sonar-scanner
if ! command -v mailx >/dev/null; then ln -s "$(command -v mail)" /usr/local/bin/mailx; fi
ln -sf /usr/share/zoneinfo/America/Fortaleza /etc/localtime
echo America/Fortaleza > /etc/timezone
mkdir -p /etc/docker /usr/share/tools-buildinfo
printf '%s\n' '{"storage-driver":"fuse-overlayfs"}' > /etc/docker/daemon.json
mv /usr/local/bin/*.buildinfo /usr/local/bin/SHA256SUMS /usr/share/tools-buildinfo/
postconf -e 'myhostname = tools.local' 'inet_interfaces = loopback-only' 'inet_protocols = ipv4' 'relayhost ='
touch /etc/msmtprc
chmod 600 /etc/msmtprc

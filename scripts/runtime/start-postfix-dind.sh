#!/bin/sh
set -eu
# Comandos explícitos funcionam como toolbox, sem iniciar serviços.
[ "$#" -gt 0 ] || set -- dockerd
case "$1" in -*) set -- dockerd "$@" ;; esac
if [ "$1" != dockerd ]; then exec "$@"; fi
SMTP_SERVER=${SMTP_SERVER:-}
SMTP_PORT=${SMTP_PORT:-25}
SMTP_HOSTNAME=${SMTP_HOSTNAME:-tools.local}
EMAIL_FROM=${EMAIL_FROM:-}
case "$SMTP_PORT" in ''|*[!0-9]*) echo 'SMTP_PORT inválido' >&2; exit 1 ;; esac
[ "$SMTP_PORT" -ge 1 ] && [ "$SMTP_PORT" -le 65535 ]
for value in "$SMTP_SERVER" "$SMTP_HOSTNAME"; do
  case "$value" in *[!a-zA-Z0-9.-]*) echo 'Hostname SMTP inválido' >&2; exit 1 ;; esac
done
case "$EMAIL_FROM" in *[!a-zA-Z0-9@._+-]*) echo 'EMAIL_FROM inválido' >&2; exit 1 ;; esac
postconf -e "myhostname = $SMTP_HOSTNAME" 'inet_interfaces = loopback-only' 'inet_protocols = ipv4'
if [ -n "$SMTP_SERVER" ]; then postconf -e "relayhost = [$SMTP_SERVER]:$SMTP_PORT"; else postconf -e 'relayhost ='; fi
umask 077
{
  printf '%s\n' defaults 'auth off' 'account default'
  if [ -n "$SMTP_SERVER" ]; then printf 'host %s\nport %s\n' "$SMTP_SERVER" "$SMTP_PORT"; fi
  if [ -n "$EMAIL_FROM" ]; then printf 'from %s\n' "$EMAIL_FROM"; fi
} > /etc/msmtprc
chmod 600 /etc/msmtprc
postfix check
postfix start
exec "$@"

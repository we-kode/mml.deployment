#!/bin/sh
# Generates the listen configuration of the MML reverse proxy and writes the global error log to a file instead of the console.
# PROXY_TLS=true terminates TLS with the certificate CERT_NAME.
# PROXY_TLS=false listens on http behind an external proxy, which terminates TLS. The client ip is taken from
# X-Forwarded-For of the proxies in TRUSTED_PROXY (space separated ips or CIDRs, default private networks).
# PROXY_TLS=both does both at the same time: TLS on INTERN_SSL_PORT and http for an external proxy on INTERN_HTTP_PORT.
set -eu

target=/etc/nginx/conf.d/mml-listen.inc
port="${INTERN_SSL_PORT:-5050}"
http_port="${INTERN_HTTP_PORT:-5080}"

fail() {
  echo "$0: $1" >&2
  exit 1
}

sed -i 's#^error_log .*#error_log /var/log/nginx/mml/error.log error;#' /etc/nginx/nginx.conf

tls() {
  [ -n "${CERT_NAME:-}" ] || fail "CERT_NAME is required when PROXY_TLS=${PROXY_TLS:-true}."
  cat <<EOF
listen ${port} ssl default_server;
ssl_certificate /etc/nginx/certs/${CERT_NAME}.crt;
ssl_certificate_key /etc/nginx/certs/${CERT_NAME}.key;
ssl_protocols TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers "EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA HIGH !RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS";
EOF
}

real_ip() {
  networks="${TRUSTED_PROXY:-10.0.0.0/8 172.16.0.0/12 192.168.0.0/16}"
  for network in $networks; do
    case "$network" in
      *:*) case "$network" in *[!0-9a-fA-F:./]*) fail "Invalid TRUSTED_PROXY entry '$network'. Use ips or CIDRs separated by spaces." ;; esac ;;
      *[!0-9./]*) fail "Invalid TRUSTED_PROXY entry '$network'. Use ips or CIDRs separated by spaces." ;;
    esac
  done
  for network in $networks; do
    echo "set_real_ip_from ${network};"
  done
  echo "real_ip_header X-Forwarded-For;"
  echo "real_ip_recursive on;"
}

case "${PROXY_TLS:-true}" in
  true)
    {
      tls
      echo 'set $mml_forwarded_proto $scheme;'
    } > "$target"
    ;;
  false)
    {
      echo "listen ${port} default_server;"
      real_ip
      echo 'set $mml_forwarded_proto $http_x_forwarded_proto;'
      echo 'if ($mml_forwarded_proto = "") { set $mml_forwarded_proto $scheme; }'
    } > "$target"
    ;;
  both)
    [ "$http_port" != "$port" ] || fail "INTERN_HTTP_PORT must differ from INTERN_SSL_PORT when PROXY_TLS=both."
    {
      tls
      echo "listen ${http_port} default_server;"
      real_ip
      # The tls port keeps its scheme, only the external proxy on the http port sends the original one.
      echo 'set $mml_forwarded_proto $scheme;'
      echo 'if ($scheme = http) { set $mml_forwarded_proto $http_x_forwarded_proto; }'
      echo 'if ($mml_forwarded_proto = "") { set $mml_forwarded_proto $scheme; }'
    } > "$target"
    ;;
  *)
    fail "PROXY_TLS must be 'true', 'false' or 'both'."
    ;;
esac

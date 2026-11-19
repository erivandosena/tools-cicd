#!/usr/bin/env bash
set -Eeuo pipefail
image="${1:?Uso: test-local.sh IMAGEM}"
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
out="$ROOT/.local/reports/local-$(date -u +%Y%m%dT%H%M%S)-$$"
mkdir -p "$out"
docker image inspect "$image" > "$out/image.json"
docker run --rm --network none "$image" /usr/local/bin/smoke-tools.sh | tee "$out/tools.log"
docker run --rm --network none "$image" sh -ec 'test -z "$(postconf -h relayhost)"; test "$(postconf -h inet_interfaces)" = loopback-only; test -z "${SMTP_SERVER:-}"'
name="tools-local-$$"
cleanup() { rc=$?; trap - EXIT; if docker container inspect "$name" >/dev/null 2>&1; then docker logs "$name" > "$out/dind.log" 2>&1; docker rm -f -v "$name" >/dev/null || rc=1; fi; exit "$rc"; }
trap cleanup EXIT
docker run -d --name "$name" --privileged --network none "$image" > "$out/container-id"
ready=0
for ((i=0;i<60;i++)); do
  if docker exec "$name" docker info > "$out/docker-info.txt" 2>&1; then ready=1; break; fi
  sleep 2
done
[[ "$ready" == 1 ]]
docker exec "$name" /usr/local/bin/test-dind.sh | tee "$out/dind-test.log"
echo "PASS: $image; relatórios: $out"

#!/bin/sh
set -eu
postfix check
postfix status
test "$(docker info --format '{{.Driver}}')" = fuse-overlayfs
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# Copiar shell e bibliotecas: build/run/create/cp sem pull ou rede externa.
mkdir -p "$work/rootfs/bin"
cp -L /bin/sh "$work/rootfs/bin/sh"
ldd /bin/sh | awk '{for(i=1;i<=NF;i++) if ($i ~ /^\//) print $i}' | sort -u > "$work/libs"
while IFS= read -r lib; do
  mkdir -p "$work/rootfs$(dirname "$lib")"
  cp -L "$lib" "$work/rootfs$lib"
done < "$work/libs"
printf '%s\n' 'FROM scratch' 'COPY rootfs /' 'COPY marker /marker' 'CMD ["/bin/sh", "-c", "echo DIND_RUN_PASS"]' > "$work/Dockerfile"
echo DIND_PASS > "$work/marker"
DOCKER_BUILDKIT=0 docker build -t tools-smoke:local "$work"
docker run --rm --network none tools-smoke:local | grep -qx DIND_RUN_PASS
id=$(docker create tools-smoke:local)
docker cp "$id:/marker" "$work/result"
grep -qx DIND_PASS "$work/result"
docker rm "$id"
docker image rm tools-smoke:local
echo DIND_PASS

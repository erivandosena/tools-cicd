#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
VERSION="${VERSION:-1.6.0}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-a-zA-Z0-9.]*)$ ]] || exit 2
REVISION="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
mkdir -p .local/reports
if [[ "$#" -eq 0 ]]; then set -- alpine ubuntu; fi
for target in "$@"; do
    [[ "$target" == alpine || "$target" == ubuntu ]] || exit 2
    image="local/tools-$target:$VERSION"
    docker buildx build --load --pull --no-cache-filter "$target" --platform linux/amd64 --target "$target" \
      --build-arg VERSION="$VERSION" --build-arg REVISION="$REVISION" \
      -t "$image" --progress=plain . 2>&1 | tee ".local/reports/build-$target.log"
    if [[ "${BUILD_ONLY:-0}" != 1 ]]; then bash scripts/test-local.sh "$image"; fi
done

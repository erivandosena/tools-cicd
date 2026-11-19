#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
version="${1:?Uso: publish.sh VERSAO [CONTEXTO_K8S]}"
context="${2:-}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-a-zA-Z0-9.]*)$ ]] || exit 2
images=("local/tools-alpine:$version" "local/tools-ubuntu:$version")
ids=()
for image in "${images[@]}"; do ids+=("$(docker image inspect "$image" --format '{{.Id}}')"); done
bash scripts/audit.sh "${ids[@]}"
for image in "${ids[@]}"; do bash scripts/test-local.sh "$image"; done
out="$ROOT/.local/releases/$version"
[[ ! -e "$out" ]] || { echo 'Versão já utilizada localmente; escolha outra.' >&2; exit 1; }
mkdir -p "$out"
refs=()
index=0
# Conferir ambas antes de publicar a primeira.
for kind in alpine ubuntu; do python3 scripts/registry.py absent "docker.io/unlb/tools-$kind:$version"; done
for kind in alpine ubuntu; do
  remote="docker.io/unlb/tools-$kind:$version"
  id="${ids[$index]}"
  index=$((index+1))
  docker tag "$id" "$remote"
  docker push "$remote" | tee "$out/$kind-push.txt"
  # API anônima comprova leitura pública sem credenciais do operador.
  digest=$(python3 scripts/registry.py digest "$remote")
  [[ "$digest" =~ ^sha256:[a-f0-9]{64}$ ]]
  ref="docker.io/unlb/tools-$kind@$digest"
  python3 scripts/registry.py digest "$ref" > "$out/$kind-digest.txt"
  refs+=("$remote")
  printf '%s\n' "$remote" > "$out/$kind-reference.txt"
done
if [[ -n "$context" ]]; then bash scripts/test-k8s.sh "$context" "${refs[@]}"; fi
# Com contexto, exige homologação; CI sem contexto comprova build/testes/auditoria.
index=0
for kind in alpine ubuntu; do
  python3 scripts/registry.py digest "docker.io/unlb/tools-$kind:$version" > "$out/$kind-after-test.txt"
  cmp "$out/$kind-digest.txt" "$out/$kind-after-test.txt"
  docker tag "${ids[$index]}" "docker.io/unlb/tools-$kind:latest"
  index=$((index+1))
  docker push "docker.io/unlb/tools-$kind:latest" | tee "$out/$kind-latest.txt"
  python3 scripts/registry.py digest "docker.io/unlb/tools-$kind:latest" > "$out/$kind-latest-digest.txt"
  cmp "$out/$kind-digest.txt" "$out/$kind-latest-digest.txt"
done
echo "PUBLICACAO_PASS: $out"
if [[ -z "$context" ]]; then echo 'Kubernetes: pendente; execute scripts/test-k8s.sh a partir da rede do cluster.'; fi

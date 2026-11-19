#!/usr/bin/env bash
set -Eeuo pipefail
context="${1:?Uso: test-k8s.sh CONTEXTO IMAGEM:TAG [IMAGEM...]}"
shift
[[ "$#" -gt 0 ]]
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
out="$ROOT/.local/reports/k8s-$(date -u +%Y%m%dT%H%M%S)-$$"
mkdir -p "$out"
ns="tools-smoke-$(date -u +%Y%m%d%H%M%S)-$$"
k() { kubectl --context "$context" --request-timeout=20s "$@"; }
[[ "$(kubectl config current-context)" == "$context" ]] || { echo 'Contexto atual divergente' >&2; exit 1; }
for image in "$@"; do [[ "$image" =~ ^docker.io/unlb/tools-(alpine|ubuntu):[a-zA-Z0-9_.-]+$ ]] || exit 2; done
k get nodes -o wide > "$out/nodes.txt"
created=0
cleanup() {
  rc=$?; trap - EXIT
  if [[ "$created" == 1 ]]; then
    k -n "$ns" get pods -o json > "$out/pods.json" 2>&1 || rc=1
    k -n "$ns" get events > "$out/events.txt" 2>&1 || true
    if ! k delete namespace "$ns" --wait=true --timeout=60s > "$out/cleanup.txt" 2>&1; then rc=1; fi
    if ! remaining=$(k get namespace "$ns" --ignore-not-found -o name); then rc=1
    elif [[ -n "$remaining" ]]; then rc=1; fi
  fi
  echo "Resultado=$rc; evidências=$out"
  exit "$rc"
}
trap cleanup EXIT
k create namespace "$ns"
created=1
k label namespace "$ns" pod-security.kubernetes.io/enforce=privileged
index=0
for image in "$@"; do
  index=$((index+1)); pod="tools-$index"
  digest=$(python3 "$ROOT/scripts/registry.py" runtime-digest "$image")
  python3 - "$pod" "$image" <<'PY' | k -n "$ns" create -f -
import json,sys
print(json.dumps({'apiVersion':'v1','kind':'Pod','metadata':{'name':sys.argv[1]},'spec':{
 'restartPolicy':'Never','activeDeadlineSeconds':420,'automountServiceAccountToken':False,
 'containers':[{'name':'tools','image':sys.argv[2],'imagePullPolicy':'Always',
 'securityContext':{'privileged':True},
 'resources':{'requests':{'cpu':'100m','memory':'256Mi'},'limits':{'cpu':'2','memory':'2Gi'}}}]}}))
PY
  ready=0
  for ((i=0;i<60;i++)); do
    if k -n "$ns" exec "$pod" -- docker info > "$out/$pod-info.txt" 2>&1; then ready=1; break; fi
    phase=$(k -n "$ns" get pod "$pod" -o jsonpath='{.status.phase}')
    [[ "$phase" != Failed ]] || break
    sleep 3
  done
  k -n "$ns" logs "$pod" > "$out/$pod-startup.txt" 2>&1 || true
  [[ "$ready" == 1 ]] || { k -n "$ns" describe pod "$pod"; exit 1; }
  actual=$(k -n "$ns" get pod "$pod" -o jsonpath='{.status.containerStatuses[0].imageID}')
  printf '%s\n' "$image" "$actual" > "$out/$pod-identity.txt"
  [[ "$actual" == *"@$digest" || "$actual" == *"//$digest" || "$actual" == "$digest" ]] || { echo 'Digest divergente' >&2; exit 1; }
  k -n "$ns" exec "$pod" -- /usr/local/bin/smoke-tools.sh | tee "$out/$pod-tools.txt"
  k -n "$ns" exec "$pod" -- /usr/local/bin/test-dind.sh | tee "$out/$pod-dind.txt"
  k -n "$ns" delete pod "$pod" --wait=true --timeout=60s
done
echo K8S_PASS

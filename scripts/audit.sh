#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ "$#" -gt 0 ]] || { echo 'Uso: audit.sh IMAGEM [IMAGEM...]' >&2; exit 2; }
out="$ROOT/.local/reports/audit-$(date -u +%Y%m%dT%H%M%S)-$$"
mkdir -p "$out"
status=0
index=0
container=''
cleanup() { rc=$?; trap - EXIT; if [[ -n "$container" ]]; then docker rm -f "$container" >/dev/null || rc=1; fi; exit "$rc"; }
trap cleanup EXIT
for image in "$@"; do
  index=$((index+1))
  docker image inspect "$image" > "$out/$index-image.json"
  scanner="${SCANNER_IMAGE:-$image}"
  container="tools-audit-$$-$index"
  docker create --name "$container" --entrypoint trivy \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v tools-trivy-cache:/root/.cache/trivy \
    "$scanner" image --scanners vuln,secret --timeout 30m --no-progress \
    --format json --output /tmp/report.json "$image" >/dev/null
  docker start -a "$container"
  [[ "$(docker inspect --format '{{.State.ExitCode}}' "$container")" == 0 ]]
  docker cp "$container:/tmp/report.json" "$out/$index.json"
  docker rm "$container" >/dev/null
  container=''
  python3 - "$out/$index.json" <<'PY' || status=1
import collections,json,sys
d=json.load(open(sys.argv[1])); counts=collections.Counter(); blocking=[]; findings=[]
# O relatório identifica a distribuição mesmo quando a imagem é passada por ID.
family=d.get('Metadata',{}).get('OS',{}).get('Family','unknown')
allow_cves=family=='ubuntu'
for r in d.get('Results',[]):
    for v in r.get('Vulnerabilities') or []:
        counts[v['Severity']]+=1
        finding=(r['Target'],v['VulnerabilityID'],v['PkgName'],v['Severity'])
        findings.append(finding)
        if not allow_cves: blocking.append(finding)
    for s in r.get('Secrets') or []: blocking.append((r['Target'],'SECRET',s.get('RuleID')))
print(d['ArtifactName'], dict(counts), 'bloqueios:',len(blocking))
for item in findings: print(*item)
for item in blocking:
    if item not in findings: print(*item)
if allow_cves and findings: print('AVISO: CVEs Ubuntu registradas sem bloquear publicação; segredos continuam bloqueantes.')
sys.exit(bool(blocking))
PY
done
echo "Relatórios completos: $out"
exit "$status"

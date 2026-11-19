#!/usr/bin/env bash
set -Eeuo pipefail
export CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GOTOOLCHAIN=local GOMAXPROCS=2 GOWORK=off
mkdir -p /out /sources
python3 - <<'PY'
import hashlib,json,pathlib,urllib.request
for name, item in json.load(open('/build/sources.lock.json')).items():
    p=pathlib.Path('/sources')/(name+('.zip' if name=='sonar' else '.tar.gz'))
    urllib.request.urlretrieve(item['url'],p)
    assert hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256'], name
PY
# Migrar as duas dependências que ainda importam go-jose/v3, como na imagem homologada.
for dep in cap okta; do
  mkdir -p "/sources/$dep"
  tar -xzf "/sources/$dep.tar.gz" --strip-components=1 -C "/sources/$dep"
done
python3 - <<'PATCH'
from pathlib import Path
import re
for name in ('cap','okta'):
    for path in (Path('/sources')/name).rglob('*.go'):
        data=path.read_text()
        if 'github.com/go-jose/go-jose/v3' in data:
            data=data.replace('github.com/go-jose/go-jose/v3','github.com/go-jose/go-jose/v4')
            # go-jose/v4 renomeou o método do jwt.Builder.
            data=data.replace('jwtBuilder.CompactSerialize()', 'jwtBuilder.Serialize()')
            if name == 'cap':
                data=data.replace('jose.ParseSigned(', 'parseJOSESigned(').replace('jwt.ParseSigned(', 'parseJWTSigned(')
                data=data.replace('Claims(claims).\n\t\tCompactSerialize()', 'Claims(claims).\n\t\tSerialize()')
            if name == 'cap':
                if 'jose.' not in data:
                    data=re.sub(r'(?m)^\s*(?:jose\s+)?"github.com/go-jose/go-jose/v4"\n', '', data)
                if 'jwt.' not in data:
                    data=re.sub(r'(?m)^\s*(?:jwt\s+)?"github.com/go-jose/go-jose/v4/jwt"\n', '', data)
            path.write_text(data)
for package in ('jwt','oidc'):
    helper = '// Adapter for go-jose/v4, retaining CAP\'s existing supportedAlgorithms allowlist.\npackage PACKAGE\nimport (\n    jose "github.com/go-jose/go-jose/v4"\n    josejwt "github.com/go-jose/go-jose/v4/jwt"\n)\nfunc supportedJOSEAlgorithms() []jose.SignatureAlgorithm {\n    result := make([]jose.SignatureAlgorithm, 0, len(supportedAlgorithms))\n    for alg, enabled := range supportedAlgorithms {\n        if enabled { result = append(result, jose.SignatureAlgorithm(alg)) }\n    }\n    return result\n}\nfunc parseJOSESigned(token string) (*jose.JSONWebSignature, error) {\n    return jose.ParseSigned(token, supportedJOSEAlgorithms())\n}\nfunc parseJWTSigned(token string) (*josejwt.JSONWebToken, error) {\n    return josejwt.ParseSigned(token, supportedJOSEAlgorithms())\n}\n'
    (Path('/sources/cap')/package/'jose_v4_adapter.go').write_text(helper.replace('PACKAGE',package))
PATCH
for dep in cap okta; do
  (cd "/sources/$dep" && go mod edit -droprequire=github.com/go-jose/go-jose/v3 &&
    GOFLAGS=-mod=mod go get github.com/go-jose/go-jose/v4@v4.1.6 && go mod tidy)
done
for name in ${TOOLS_COMPONENTS:-yq kustomize mc bao trivy argocd kubectl}; do
  mkdir -p "/sources/$name"
  tar -xzf "/sources/$name.tar.gz" --strip-components=1 -C "/sources/$name"
  cd "/sources/$name"
  [[ "$name" != kustomize ]] || cd kustomize
  # Cobrir também dependências transitivas; tidy remove módulos não utilizados.
  GOFLAGS=-mod=mod go get golang.org/x/net@v0.62.0 \
    golang.org/x/crypto@v0.58.1-0.20261009181718-2f1f834330b2 \
    go.opentelemetry.io/otel@v1.47.0 go.opentelemetry.io/otel/sdk@v1.47.0 \
    go.opentelemetry.io/otel/trace@v1.47.0 go.opentelemetry.io/otel/sdk/metric@v1.47.0
  # Versões usadas na remediação anterior; não reintroduzir as bibliotecas antigas.
  case "$name" in
    mc) GOFLAGS=-mod=mod go get github.com/klauspost/compress@v1.18.7 google.golang.org/grpc@v1.83.2 \
      github.com/prometheus/prometheus@v0.311.3 github.com/prometheus/client_golang@v1.23.2 \
      github.com/prometheus/common@v0.67.5 github.com/prometheus/procfs@v0.16.1 \
      github.com/coreos/go-systemd/v22@v22.6.0 go.uber.org/zap@v1.27.1 ;;
    bao)
      go mod edit -replace=github.com/hashicorp/cap=/sources/cap
      go mod edit -replace=github.com/okta/okta-sdk-golang/v2=/sources/okta
      GOFLAGS=-mod=mod go get github.com/klauspost/compress@v1.19.2 \
        github.com/go-jose/go-jose/v4@v4.1.6 google.golang.org/grpc@v1.83.2 \
        github.com/google/cel-go@v0.30.0 github.com/moby/go-archive@v0.3.0 \
        github.com/moby/sys/user@v0.4.1 github.com/moby/sys/sequential@v0.7.0 \
        github.com/moby/patternmatcher@v0.6.1 ;;

  esac
  go mod tidy
  flags='-s -w'
  package=.
  case "$name" in
    argocd) package=./cmd; flags="$flags -X github.com/argoproj/argo-cd/v3/common.version=3.6.1 -X github.com/argoproj/argo-cd/v3/common.gitTreeState=dirty -X github.com/argoproj/argo-cd/v3/common.extraBuildInfo=security-remediation" ;;
    trivy) package=./cmd/trivy; flags="$flags -X github.com/aquasecurity/trivy/pkg/version/app.ver=0.76.2" ;;
    kubectl) package=./cmd/kubectl; flags="$flags -X k8s.io/component-base/version.gitVersion=v1.35.9 -X k8s.io/client-go/pkg/version.gitVersion=v1.35.9" ;;
    kustomize) flags="$flags -X sigs.k8s.io/kustomize/api/provenance.version=v5.8.3" ;;
    bao) flags="$flags -X github.com/openbao/openbao/version.fullVersion=2.6.2 -X github.com/openbao/openbao/version.VersionPrerelease= -X github.com/openbao/openbao/version.VersionMetadata=security-remediation" ;;
  esac
  echo "BUILD $name"
  go build -mod=mod -p 2 -trimpath -buildvcs=false -ldflags "$flags" -o "/out/$name" "$package"
  go version -m "/out/$name" > "/out/$name.buildinfo"
  if grep -q 'github.com/go-jose/go-jose/v3' "/out/$name.buildinfo"; then
    echo "ERRO: go-jose/v3 vulnerável ainda presente em $name" >&2; exit 1
  fi
  mkdir -p "/licenses/$name"
  find "/sources/$name" -maxdepth 1 -type f \( -iname 'LICENSE*' -o -iname 'NOTICE*' -o -iname 'COPYING*' \) -exec cp '{}' "/licenses/$name/" \;
done
unzip -q /sources/sonar.zip -d /opt
mv /opt/sonar-scanner-* /opt/sonar-scanner
cd /out
sha256sum $(find . -maxdepth 1 -type f ! -name "*.buildinfo" ! -name SHA256SUMS -printf "%f\n" | sort) > SHA256SUMS
rm -rf /sources

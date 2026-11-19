#!/bin/sh
set -eu
python3 -c 'import yaml; assert yaml.safe_load("ok: true")["ok"] is True'
python3 -m coverage --version
for tool in bash git node npm docker dockerd; do "$tool" --version; done
openssl version
kubectl version --client
argocd version --client
bao version | grep -F 'OpenBao v2.6.2'
trivy --version
kustomize version
yq --version
mc --version
sonar-scanner --version
command -v mailx
command -v sendmail
command -v fuse-overlayfs
! command -v vault
postfix check
echo TOOLS_PASS

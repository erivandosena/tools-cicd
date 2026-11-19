#!/usr/bin/env python3
"""Consulta anônima ao Docker Hub; falhas de rede/auth nunca significam tag ausente."""
import hashlib, json, re, sys, urllib.error, urllib.parse, urllib.request

mode, ref = sys.argv[1:]
match = re.fullmatch(r'docker.io/(unlb/tools-(?:alpine|ubuntu))(?::([\w.-]+)|@(sha256:[a-f0-9]{64}))', ref)
if not match or mode not in ('absent', 'digest', 'runtime-digest'):
    raise SystemExit('Referência ou operação inválida')
repo, tag, digest = match.groups()
query = urllib.parse.urlencode({'service':'registry.docker.io','scope':f'repository:{repo}:pull'})
with urllib.request.urlopen('https://auth.docker.io/token?'+query, timeout=30) as response:
    token=json.load(response)['token']
request=urllib.request.Request(f'https://registry-1.docker.io/v2/{repo}/manifests/{tag or digest}', headers={
    'Authorization':'Bearer '+token,
    'Accept':', '.join(['application/vnd.oci.image.index.v1+json','application/vnd.oci.image.manifest.v1+json',
                       'application/vnd.docker.distribution.manifest.list.v2+json','application/vnd.docker.distribution.manifest.v2+json'])})
try:
    with urllib.request.urlopen(request, timeout=30) as response:
        body=response.read()
        actual='sha256:'+hashlib.sha256(body).hexdigest()
        if response.headers.get('Docker-Content-Digest') != actual:
            raise SystemExit('Digest remoto inconsistente')
except urllib.error.HTTPError as error:
    if error.code==404 and mode=='absent':
        sys.exit(0)
    raise SystemExit(f'Consulta pública falhou: HTTP {error.code}') from None
if mode=='absent':
    raise SystemExit('Tag já existe; use outra versão')
if digest and actual!=digest:
    raise SystemExit('Digest solicitado divergente')
if mode=='runtime-digest':
    manifest=json.loads(body)
    if 'manifests' in manifest:
        matches=[m for m in manifest['manifests'] if m.get('platform',{}).get('os')=='linux'
                 and m.get('platform',{}).get('architecture')=='amd64']
        if len(matches)!=1: raise SystemExit('Manifesto linux/amd64 não é único')
        actual=matches[0]['digest']
print(actual)

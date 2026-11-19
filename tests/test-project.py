import pathlib, subprocess, tempfile, os, json
root=pathlib.Path(__file__).resolve().parent.parent
for p in root.joinpath('scripts').rglob('*.sh'):
    assert b'\r' not in p.read_bytes(), p
    subprocess.run(['bash','-n',str(p)],check=True)
for p in [root/'README.md',root/'CHANGELOG.md',root/'NOTICE.md',*root.joinpath('docs').glob('*.md')]:
    text=p.read_text()
    assert '/mnt/c/' not in text and 'C:\\Users' not in text and 'Downloads/' not in text, p
# Teste de regressão: auditoria deve falhar para HIGH, segredos e imagem ausente.
with tempfile.TemporaryDirectory() as temp:
    temp=pathlib.Path(temp)
    docker=temp/'docker'
    docker.write_text('''#!/usr/bin/env python3
import os,sys,json,pathlib
a=sys.argv[1:]
if a[:2]==['image','inspect']:
    if os.environ.get('CASE')=='missing': sys.exit(1)
    print('[{}]');sys.exit()
if a[0]=='inspect':
    print('1' if os.environ['CASE']=='scan_error' else '0');sys.exit()
if a[0]!='cp': sys.exit()
dest=a[-1]
r={'Target':'test','Vulnerabilities':[]}
if os.environ['CASE'] in ('critical','high','medium','low','unknown'): r['Vulnerabilities']=[{'Severity':os.environ['CASE'].upper(),'VulnerabilityID':'TEST','PkgName':'test'}]
if os.environ['CASE']=='secret': r['Secrets']=[{'RuleID':'TEST'}]
pathlib.Path(dest).write_text(json.dumps({'ArtifactName':'test','Metadata':{'OS':{'Family':os.environ.get('FAMILY','alpine')}},'Results':[r]}))
''')
    docker.chmod(0o755)
    for family in ('alpine','ubuntu','unknown'):
        for case in ('clean','critical','high','medium','low','unknown','secret','missing','scan_error'):
            expected=0 if case=='clean' or (family=='ubuntu' and case in ('critical','high','medium','low','unknown')) else 1
            env=dict(os.environ,PATH=str(temp)+':'+os.environ['PATH'],CASE=case,FAMILY=family)
            p=subprocess.run(['bash',str(root/'scripts/audit.sh'),'sha256:test'],env=env,capture_output=True,text=True)
            assert p.returncode==expected,(family,case,p.stdout,p.stderr)
print('PASS: sintaxe, LF, documentação portátil e bloqueios da auditoria')

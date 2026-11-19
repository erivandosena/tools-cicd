# Tools Ubuntu e Alpine para Pipeline CI/CD

Imagens `linux/amd64` de ferramentas CI/CD:

- `docker.io/unlb/tools-ubuntu:latest`
- `docker.io/unlb/tools-alpine:latest`

Um único Dockerfile mantém os alvos `ubuntu` e `alpine`. As bases usam as tags `ubuntu:22.04`, `alpine:3.24.4` e `golang:1.27.4-bookworm`, sem digest no FROM. Os CLIs Go são compilados dos fontes verificados em `manifests/sources.lock.json`, usando Go 1.27.4 e correções explícitas de dependências. Nenhuma imagem `local/...` é usada como base.

Inclui kubectl 1.35.9, Argo CD 3.6.1, OpenBao 2.6.2 (`bao`, sem alias `vault`), Trivy 0.76.2, yq 4.54.3, Kustomize 5.8.3, MinIO Client, SonarScanner 8.4.0.16527, Node/npm, Python/PyYAML/Coverage, Git, Docker/DinD, Postfix e utilitários de rede. Pacotes de distribuição podem receber atualizações; o build não promete identidade binária entre datas distintas.

## Pré-requisitos

Bash, Docker Engine com Buildx, Python 3, acesso aos repositórios públicos e espaço para compilação Go. Os testes DinD usam containers temporários privilegiados, sem montar volumes do host. A homologação Kubernetes exige kubectl, contexto explícito e permissão para namespace/Pods temporários privilegiados. Não altera workloads existentes nem envia e-mail externo.

## Build e testes

Sempre execute a partir da raiz do repositório:

```bash
bash scripts/build.sh                 # ambas as imagens e testes locais
bash scripts/build.sh alpine          # somente Alpine
bash scripts/build.sh ubuntu          # somente Ubuntu
bash scripts/audit.sh local/tools-alpine:1.6.0 local/tools-ubuntu:1.6.0
```

O build atualiza a base por tag e refaz a instalação dos pacotes do alvo, preservando o cache de compilação Go. Isso evita reutilizar uma camada antiga quando há atualizações de segurança. O build verifica ferramentas. O teste local verifica o entrypoint toolbox, ausência de relay embutido, Postfix, dockerd, driver fuse-overlayfs e operações Docker. A auditoria mantém o relatório completo: qualquer CVE bloqueia a Alpine; na Ubuntu, CVEs são informativas e permitem publicação. A distribuição é identificada pelo relatório, inclusive para imagens passadas por ID. Segredos detectados e falhas do scanner bloqueiam ambas. Nenhum achado é omitido, incluindo vulnerabilidades herdadas da base ou sem correção.

## Execução

```bash
# Toolbox: executa o comando sem iniciar serviços.
docker run --rm unlb/tools-alpine:latest kubectl version --client
docker run --rm -it unlb/tools-ubuntu:latest bash
# DinD: inicializa Postfix e Docker; requer privilégios.
docker run --rm --privileged unlb/tools-alpine:latest
```

SMTP é configurado somente em runtime por `SMTP_SERVER`, `SMTP_PORT` (25), `SMTP_HOSTNAME` (`tools.local`) e `EMAIL_FROM` (remetente do msmtp). Sem servidor configurado, relayhost fica vazio. Não há credenciais, kubeconfig ou identidade Git institucional embutidos. O serviço Postfix escuta somente em loopback; entrega SMTP externa não faz parte da homologação.

## Publicação e homologação

Crie os dois repositórios públicos na organização `unlb` e autentique-se com uma conta autorizada. Use uma versão nova em cada release:

```bash
docker login docker.io
VERSION=1.6.0 bash scripts/build.sh
bash scripts/publish.sh 1.6.0 "${K8S_CONTEXT:?Defina K8S_CONTEXT no ambiente}"
```

O publicador bloqueia em falhas locais/de auditoria, publica tags de versão e verifica acesso anônimo. Quando recebe o contexto Kubernetes, testa essas tags antes de promover os mesmos artefatos para `latest`. Sem contexto, como na CI, publica após os testes locais e registra a homologação Kubernetes como pendente. Os digests são registrados e comparados ao imageID executado, sem substituir as tags nos manifestos. A promoção das duas tags não é atômica: em falha de rede, conferir ambas antes de usar. Os relatórios ficam em `.local/`; não são versionados.

Para repetir somente a homologação, passe as referências completas registradas nos relatórios:

```bash
bash scripts/test-k8s.sh "${K8S_CONTEXT:?Defina K8S_CONTEXT no ambiente}" \
  "$(cat .local/releases/1.6.0/alpine-reference.txt)" \
  "$(cat .local/releases/1.6.0/ubuntu-reference.txt)"
```

O teste confere o imageID do Pod, ferramentas, Postfix e DinD; exige limpeza do namespace para sucesso. Execução de pipeline real no GitLab Runner e entrega SMTP externa são validações separadas.

## Publicação após commits no GitHub ou GitLab CE

Push na principal do GitLab executa GitLab CI. Push na principal do GitHub executa GitHub Actions. Cada pipeline constrói, testa, audita e publica as duas imagens diretamente no Docker Hub. Configuração: [docs/ci.md](docs/ci.md).


## Configuração local e dados reais

Versione `.env.example`, com valores fictícios. A configuração real fica em `.env`, ignorado pelo Git e pelo contexto Docker. Os scripts não carregam esse arquivo automaticamente; carregue-o apenas na sessão de testes:

```bash
cp -n .env.example .env
nano .env
set -a
. ./.env
set +a

bash scripts/test-k8s.sh "$K8S_CONTEXT" \
  docker.io/unlb/tools-alpine:latest \
  docker.io/unlb/tools-ubuntu:latest
```

O contexto deve corresponder ao contexto atual do kubectl; o script confere isso antes de criar recursos. Kubeconfig e credenciais permanecem fora do repositório. Para SMTP em um container de teste, passe `--env-file .env` ao `docker run`; não use credenciais em ARG, ENV ou COPY do Dockerfile.

Os labels usam fornecedor genérico. Caso queira um fornecedor diferente nos metadados públicos da imagem, informe `--build-arg IMAGE_VENDOR="Seu fornecedor"` ao build. Esses labels são públicos; não coloque segredos neles.

Backups e evidências em `.local/` podem conter nomes reais e continuam ignorados. Para pesquisar apenas arquivos relevantes no terminal, `rg` respeita `.gitignore` por padrão. No VS Code, habilite **Use Exclude Settings and Ignore Files** ou exclua `**/.local/**` da pesquisa.

Antes do commit, confira os arquivos preparados com `git diff --cached --name-only` e o conteúdo com `git diff --cached`. Configure tokens reais nos secrets/variables dos provedores de CI, nunca nos arquivos YAML.

## Estrutura e licenças

- `Dockerfile`: duas imagens e estágio compartilhado de compilação.
- `manifests/sources.lock.json`: versões, URLs e checksums dos fontes.
- `scripts/`: build, testes, auditoria e publicação.
- `scripts/runtime/`: entrypoint e verificações incluídas nas imagens.
- `CHANGELOG.md`: mudanças do projeto; resultados históricos não homologam novos builds.
- `.local/`: caches, backups e evidências, excluídos do Git e do contexto Docker.
- `tests/test-project.py`: verificações estáticas e regressões dos bloqueios de auditoria.
- `.github/workflows/images.yml`: build, testes, auditoria e publicação pelo GitHub Actions.
- `.gitlab-ci.yml`: build, testes, auditoria e publicação pelo GitLab CI.

A licença própria não está declarada no repositório; o metadado OCI permanece `NOASSERTION`. As licenças dos componentes distribuídos estão descritas em `NOTICE.md`, e seus avisos são preservados nas imagens.

# Build e publicação independentes por provedor

| Push na branch principal | Executor | Resultado |
| --- | --- | --- |
| GitLab CE | GitLab CI | Build, testes, auditoria e push no Docker Hub |
| GitHub | GitHub Actions | Build, testes, auditoria e push no Docker Hub |

Cada pipeline identifica a branch padrão do respectivo repositório. Um commit local precisa ser enviado por `git push` para disparar a automação. Os provedores não encaminham commits entre si.

As duas pipelines usam os mesmos scripts e publicam `docker.io/unlb/tools-ubuntu:latest` e `docker.io/unlb/tools-alpine:latest`, além de tags por execução para rastreabilidade. A publicação exige sucesso dos testes e da auditoria.

## GitHub

Em **Settings → Secrets and variables → Actions**, crie a variável `DOCKERHUB_USERNAME` e o secret `DOCKERHUB_TOKEN`, com permissão para publicar na organização `unlb`. O workflow `.github/workflows/images.yml` executa em runner Ubuntu após push na branch padrão ou acionamento manual nessa branch.

Referências: [Docker com GitHub Actions](https://docs.docker.com/build/ci/github-actions/), [teste antes do push](https://docs.docker.com/build/ci/github-actions/test-before-push/).

## GitLab CE

Em **Settings → CI/CD → Variables**, crie `DOCKERHUB_USERNAME` e `DOCKERHUB_TOKEN`. Marque o token como **Masked** e **Protected** e proteja a branch principal. Use um Runner Docker com tag `tools-docker` e configuração:

```toml
[runners.docker]
  image = "docker:29.9.1-cli"
  privileged = true
  volumes = ["/certs/client", "/cache"]
```

O serviço `docker:29.9.1-dind` usa TLS na porta 2376. Reserve memória e disco para a compilação Go e permita containers DinD temporários para os testes.

Referências: [DinD no GitLab CE](https://docs.gitlab.com/ci/docker/docker_in_docker/), [variáveis CI/CD](https://docs.gitlab.com/ci/variables/).

Se o código for enviado aos dois provedores, ambos publicarão; `latest` apontará para a última publicação concluída. As tags por execução permitem identificar cada artefato.

## Kubernetes

Após publicar, execute a partir de um ambiente com acesso ao cluster:

```bash
bash scripts/test-k8s.sh "${K8S_CONTEXT:?Defina K8S_CONTEXT no ambiente}" \
  docker.io/unlb/tools-alpine:latest \
  docker.io/unlb/tools-ubuntu:latest
```

O teste mantém as tags nos Pods e confere o digest executado. A configuração local dos pipelines não comprova sua execução nos provedores, que depende das credenciais e dos runners.

## Política de CVEs

Alpine: qualquer CVE bloqueia publicação. Ubuntu: CVEs são registradas e permitem publicação. Segredos detectados, erros do scanner e falhas nos testes continuam bloqueando ambas. A mesma política vale para execução local, GitHub Actions e GitLab CI.

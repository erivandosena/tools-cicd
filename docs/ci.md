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

Em **Settings → CI/CD → Variables**, crie `DOCKERHUB_USERNAME` e `DOCKERHUB_TOKEN`. Marque o token como **Masked** e **Protected** e proteja a branch principal. Use o Runner de instância com tag `kubernetes` e executor Kubernetes em modo privilegiado:

```toml
[runners.kubernetes]
  privileged = true
```

O serviço `docker:29.9.1-dind` usa TLS na porta 2376. Job e serviço compartilham o diretório de builds do Runner; os certificados são criados em `$CI_BUILDS_DIR/.docker-certs-$CI_JOB_ID`, fora do checkout e do contexto de build. A pasta é exclusiva do job e não depende de um volume adicional `/certs/client`. O job aguarda até 60 segundos pela inicialização do daemon antes de continuar. Reserve memória e disco adequados para a compilação Go e os testes DinD.

No fluxo normal, o GitLab cria um builder exclusivo por job com driver `docker-container`, separando o BuildKit daquele embarcado no daemon DinD. Os scripts mantêm `--load` para disponibilizar as imagens aos testes e à auditoria. O builder é reutilizado nos dois builds e removido após a coleta dos logs. Os limites do Runner permanecem iguais; a mitigação ainda precisa ser validada em execução no GitLab.

Essa configuração é exclusiva do GitLab; o GitHub Actions mantém o runner Ubuntu e suas etapas existentes.

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

## Diagnóstico DinD sem recompilar

Em Build → Pipelines → New pipeline, selecione a principal e informe `DIND_DIAGNOSTIC_ONLY=1`. Esse modo baixa as imagens latest publicadas e executa somente os testes locais; não compila, audita ou publica. Sem essa variável, o fluxo normal permanece ativo.

A espera pelo daemon é de até 300 segundos no GitLab e 120 por padrão nas outras execuções, configurável por `DIND_READY_TIMEOUT`. Se o teste falhar, estado e últimos logs aparecem no job. Os relatórios também são preservados por três dias nos artifacts GitLab, conforme as permissões de acesso do projeto.

Os artifacts incluem `buildkit-builder.txt`, `buildkit.log`, `buildkit-final.log` e `buildkit-state.json` no fluxo normal. A captura contínua começa após o bootstrap; o `after_script` coleta novamente os logs e o estado antes de remover o builder. A preservação depende de o job e o daemon permanecerem acessíveis para a coleta e o envio dos artifacts.

Referência: [driver Docker container do Buildx](https://docs.docker.com/build/builders/drivers/docker-container/).

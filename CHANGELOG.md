# Registro de alterações

Todas as alterações notáveis deste projeto são documentadas neste arquivo.

O formato segue o [Keep a Changelog 1.1.0](https://keepachangelog.com/pt-BR/1.1.0/), e as versões seguem o [Versionamento Semântico](https://semver.org/lang/pt-BR/), quando aplicável. As versões identificam receitas, scripts e procedimentos; publicação e homologação são comprovadas pelos relatórios dos artefatos testados.

## [Não lançado]

### Corrigido
- GitLab passa a usar BuildKit separado com driver docker-container e builder por job, preservando logs/estado nos artifacts antes da limpeza. Mitigação da falha de sessão gRPC pendente de validação no Runner; GitHub e limites de recursos preservados.
- Diagnóstico de falhas DinD com estado/logs no console, espera configurável e artifacts GitLab. Modo DIND_DIAGNOSTIC_ONLY testa imagens publicadas sem repetir o build.
- Build passa a atualizar a base por tag e refazer as camadas do alvo, preservando cache Go, para não conservar pacotes vulneráveis em cache.
- Auditoria atualizada da Alpine antiga `66f7fa10aa1c` em 2026-11-19 detectou seis CVEs no OpenJDK (uma crítica, duas altas e três médias); o resultado histórico zero CVE não é atribuído à auditoria atual.
- Recuperadas as correções de dependências do OpenBao/MinIO Client presentes na Alpine anterior; migração de go-jose/v3 para v4 nos fontes CAP/Okta fixados por checksum.
- Removida a instalação persistente da chave snakeoil na camada Ubuntu e substituído npm embarcado antigo por 11.12.1.
- Correção dos metadados de versão OpenBao, usando fullVersion para identificar 2.6.2. Alterações ainda exigem build e auditoria finais; vulnerabilidades Ubuntu sem correção não são ignoradas.
- Uso de uma única opção `postconf -e` por chamada no setup e no entrypoint, corrigindo a falha de build e inicialização do Postfix.

### Alterado
- Pipeline GitLab alinhada ao Runner de instância com tag kubernetes; TLS usa o diretório de builds compartilhado fora do checkout e aguarda o daemon iniciar. Workflow GitHub preservado.
- Dados reais de contexto Kubernetes e SMTP ficam em configuração local ignorada; exemplos usam valores fictícios. Fornecedor OCI parametrizado por IMAGE_VENDOR. Identificadores de infraestrutura omitidos do histórico público, preservando datas, versões e resultados.
- Política de publicação ajustada: CVEs bloqueiam Alpine; na Ubuntu são informativas. Relatórios completos, bloqueio por segredos, erros do scanner e testes continuam ativos em ambas.
- Consolidação das receitas em um Dockerfile com alvos Alpine e Ubuntu.
- Alpine 3.24.4 e Ubuntu oficial 22.04 com tags convencionais nas imagens-base, sem digest no FROM.
- Compilação compartilhada de CLIs a partir de fontes com checksum e dependências de segurança explícitas.
- OpenBao substitui Vault; configuração SMTP passa a ser exclusivamente de runtime.
- EntryPoint aceita comandos toolbox ou inicializa Postfix/DinD.
- README corresponde aos arquivos e procedimentos atuais.

### Adicionado
- Pipeline GitLab CE independente para build, testes, auditoria e publicação após push na principal.
- Pipeline GitHub Actions independente para build, testes, auditoria e publicação após push na principal.
- Documentação de configuração de credenciais Docker Hub, Runner DinD/TLS e validação posterior no Kubernetes.
- Fluxo de build, teste local, auditoria, publicação versionada e homologação Kubernetes com tags e conferência do digest executado.
- Bloqueio de publicação por qualquer CVE ou segredo detectado, incluindo ocorrências herdadas da imagem-base.
- Verificação de acesso público ao registry e promoção para latest após homologação.
- LF para scripts e exclusões de artefatos locais/credenciais no Git.

### Removido do fluxo ativo
- Geradores desativados, validadores dependentes deles e receitas duplicadas.
- Remediações que exigiam imagens locais preexistentes.
- Referências documentais a scripts ausentes e registros fictícios.

### Validação
- Validação em 2026-11-19: OpenBao e MinIO Client recompilados; Trivy rootfs reconheceu os dois binários Go e detectou zero CVEs nesses dois artefatos. Relatório local em .local/reports/repaired-tools-20261119T041945/result.json. Este resultado não substitui a auditoria das imagens completas.
- Sintaxe Bash, finais de linha LF, portabilidade da documentação e regressões dos bloqueios de auditoria verificados localmente.
- Docker Buildx `--check` aprovado nos alvos Alpine e Ubuntu, sem avisos; não equivale a build ou execução das imagens.
- YAMLs GitHub Actions e GitLab CI analisados localmente; pipelines ainda não executados nos provedores.
- Auditoria preliminar das bases locais em 2026-11-18: Alpine 3.24.4 com uma ocorrência média em zlib; Ubuntu 22.04 com 32 médias e 17 baixas. As receitas atualizam os pacotes; esses números não descrevem as imagens finais.
- Build completo da revisão final, auditoria das imagens finais, push e teste Kubernetes ainda não concluídos. A compilação de uma revisão intermediária foi interrompida para limitar a validação ao escopo solicitado.
- Versão candidata dos metadados: 1.6.0. Não é declaração de release publicada.

## [1.5.0] - 2026-10-16

### Adicionado
- Consolidação na raiz `.` dos scripts `validar-pods-wsl.sh` e `publicar-validacao-wsl.sh`, preservando cópias anteriores com sufixo `.bak-pre-v16` e `.bak-pre-v16-prod`, respectivamente.
- Verificador somente leitura de identidade local e digest remoto da Alpine homologada, com relatório de execução salvo em `Downloads`.
- Verificação do ID local esperado `sha256:c32c8b0d06cb9c59469f7ea0c83cfb4c9e227999488e25352bb39c6ed369a7fe` e da plataforma `linux/amd64`.
- Verificação do digest remoto esperado `sha256:1e20c92b240b4984270246a280d322b6ac1f845f22cace96ad06456031f95275` para `registry.example.invalid/library/alpine-k8s-tools-minimal:ci-cd-v12`.

### Alterado
- O arquivo `publicar-validacao-wsl.sh` da raiz passou a atuar como **verificador de integridade**, apesar do nome histórico: não executa `docker tag`, `docker push` ou sobrescrita de tags.
- O arquivo `validar-pods-wsl.sh` da raiz passou a conter a mesma versão homologada em `harbor-k8s-v16/validar-pods-wsl.sh`, comprovada por SHA-256 idêntico (`bf0db54dbedcb2d34666dc9c05b9bb62263f16d53c6e1a22bf0a091c0b94d5f9`).
- Preservado o repositório Git existente, na branch `main`, sem reinicialização ou alteração dos Dockerfiles já modificados.

### Corrigido
- Substituída na raiz a referência anterior do publicador à tag `ci-cd-v13` pela validação da imagem efetivamente homologada sob `ci-cd-v12`.
- Eliminado do fluxo de verificação atual o risco de sobrescrita da tag homologada por publicação automática ou por validação limitada à existência de manifesto remoto.
- Validado o Docker-in-Docker com `fuse-overlayfs` na Alpine V16, sem reincidência do erro original de `overlay2` na execução observada.

### Segurança
- Divergências no ID local, na plataforma ou no digest remoto bloqueiam o resultado de aprovação, sem modificar o Harbor.
- O teste de Kubernetes V16 exige confirmação explícita do operador, verifica contexto e permissões e utiliza Pod privilegiado e Secret temporários apenas no escopo de homologação.
- A execução de homologação confirmou a remoção do Pod e do Secret temporários; não foram alterados workloads existentes nessa etapa.

### Validado
- **Alpine V16 — Kubernetes:** `PASS` no namespace `[omitido]`, contexto `[omitido]`, nó `[omitido]`; imagem efetivamente executada com digest esperado, inicialização do `dockerd`, driver `fuse-overlayfs`, ferramentas CLI e `postfix check`.
- **Limpeza do teste:** Pod e Secret temporários removidos após a coleta de evidências.
- **Verificador de integridade da raiz:** `PASS` para ID local, plataforma e digest remoto; execução de 2026-10-16 com registro `publicacao-harbor-k8s-20261016-235537-821585.txt`; nenhuma republicação necessária.
- **Instalação local dos scripts:** sintaxe Bash aprovada e comparação binária idêntica entre arquivos de origem e destino.
- **Ubuntu:** homologação anterior em Pod Kubernetes, preservada sem nova alteração nesta etapa; a homologação Alpine V16 não substitui esse resultado nem constitui novo teste da Ubuntu.

## [1.4.0] - 2026-10-16

### Adicionado
- Publicação explícita das imagens Ubuntu e Alpine no projeto `library`, com tags `validacao-k8s-v12`, sem sobrescrever `latest`, conforme histórico desta versão.
- Confirmação de manifestos remotos antes da criação de Pods.
- Execução de Pods temporários privilegiados em `platform-smoke`, com recursos limitados e prazo máximo.
- Secret de pull temporário copiado em memória a partir de `ci-cd/harbor-regcred`, sem imprimir credenciais.
- Coleta de evidências e verificação da exclusão dos Pods e Secret em rotinas de limpeza.

### Segurança
- Procedimento desenhado para não modificar workloads existentes, não executar SMTP externo e não publicar outras tags.
- Teste privilegiado exige autorização explícita do operador e pode ser negado por políticas de admissão.

## [1.3.0] - 2026-10-16

### Adicionado
- Validador inicial para Pods Kubernetes com verificações de CLI, Docker-in-Docker e Postfix.

## [1.2.0] - 2026-10-16

### Corrigido
- Teste `docker create` passou a fornecer comando explícito para imagem sem `CMD`.

### Validado
- Ubuntu e Alpine: ferramentas Git, npm, Kustomize e yq; operações Docker de build, create, copy, run e limpeza no WSL, conforme registros históricos.

## [1.1.0] - 2026-10-16

### Corrigido
- Falso negativo do verificador CLI/configuração.

### Validado
- CLI, Node.js, Docker-in-Docker, API Docker e Postfix no WSL, conforme registros históricos.

## [1.0.0] - 2026-10-16

### Adicionado
- Scripts geradores Ubuntu e Alpine e validadores locais (histórico das versões anteriores).

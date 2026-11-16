# Integração de fases

> Pra que serve: o comportamento de abrir, listar e integrar fases em paralelo. A decisão é a ADR-002. O `AGENTS.md` aponta; aqui está o que o sistema faz.

## R-001 — Modo da fase

A fase é **solitária** ou **paralela**.

Solitária: nenhuma outra fase está em execução e o planejamento abre uma só. A spec fica no `docs/SETUP.md` do checkout, sem commit, e a execução segue o loop de sempre. Não se chama `scripts/abrir-fase.sh`.

Paralela: o planejamento abre mais de uma, ou abre uma enquanto outra paralela já corre, e `scripts/fases-ativas.sh --sobrepor` sai 0 para os caminhos dela. Cada uma nasce com `scripts/abrir-fase.sh`: branch `fase/<id>-<slug>`, worktree em `<diretório-pai>/<repo>-fases/<id>`, primeiro commit `docs: abre <id>`, push, sem pull request. A execução é uma sessão nova por fase, **aberta no checkout principal** (o trust é o dele, e o fecho tira o worktree sem matar a sessão), que trabalha no worktree por caminho absoluto; a spec é o `docs/SETUP.md` de lá. Quem planejou a leva inicia as sessões e as gerencia até o resumo do fim (`AGENTS.md` §O loop).

**O corte agrupa por afinidade:** itens que fazem sentido juntos ficam numa fase, uma etapa (um commit) por item; em projeto com deploy no merge, todo item de produção da leva vai numa fase só (um build, um CI, um deploy). Paralela separada só pro que é de outra área e tem motivo pra andar sozinho — arquivo disjunto é condição pra paralelizar, não motivo.

**Caminho que só fase solitária toca.** Recurso que não se divide entre worktrees (o schema e as migrations de um banco de desenvolvimento único, por exemplo) entra em `ABRIR_FASE_SO_SOLITARIA` no `scripts/abrir-fase.sh`: `--arquivos` que cruze um deles é recusado. O worktree nasce pronto pelos outros dois ganchos do projeto: `ABRIR_FASE_LINKS` (arquivos fora do git, por link) e `scripts/preparar-worktree.sh` (instalar dependências).

**Exemplo:** nada no ar e um bug num arquivo → solitária, spec no checkout. Duas issues, uma mexe em `src/notas/` e outra em `src/tags/` → duas paralelas. Uma solitária já no ar (sem registro) → a próxima não abre; o registro implícito é o repo inteiro.

**Âncora:** `scripts/abrir-fase.sh` › abertura, ganchos e prompt da sessão; `scripts/fases-ativas.sh` › lista.

**Rejeitado:** worktree obrigatório na solitária (o caso de uma fase só não muda de forma); a sessão da paralela com o cwd no worktree (worktree novo para no diálogo de confiança, e a sessão morre quando a integração apaga a pasta).

**Origem:** F-metodo-v6, ADR-002; sessão no checkout principal, afinidade e ganchos na F-metodo-v8 (Amplug F-110, F-113).

## R-002 — Registro e descoberta

Fase paralela publica `docs/fases-ativas/<id>.md` na branch dela (modelo em `templates/fase-ativa.md`). O arquivo diz modo, status (`executando`, `pronta-para-integrar` — fase de produção parada antes do `/integrar-fase`, à espera do ok do dono —, `integrando` — só a integração rodando), branch, `depende_de`, `arquivos`, `areas`, `bots` e uma linha de escopo. Diretório em `arquivos` leva barra no fim; sem barra é arquivo e não cobre o filho.

`scripts/fases-ativas.sh` lê worktrees, branches locais `fase/*` e, com `--fetch`, `origin/fase/*`. Sem esse arquivo, branch `fase/*` ainda não integrada reivindica o repo inteiro. Spec com título `# F-` no `docs/SETUP.md` do checkout da `main` também: é solitária que ainda não virou branch. `--sobrepor caminho…` sai 1 se alguma reivindicação cruza. A lista sai no stdout; o cruzamento, no stderr.

**Exemplo:** `src/notas/` cruza `src/notas/tags.ts`. `src/notas` sem barra não cruza `src/notas/tags.ts`.

**Âncora:** `scripts/fases-ativas.sh` › `registrar`; `templates/fase-ativa.md`; `scripts/conferir-fecho.sh` › `outros` (branch `fase/*` com registro não é sobra).

**Rejeitado:** um markdown único de registro. Ele seria o conflito que o registro existe para evitar.

**Origem:** F-metodo-v6, ADR-002.

## R-003 — Fragmento dos ledgers

Na paralela, a fase não edita `docs/CHANGELOG.md`, `docs/ROADMAP.md`, `docs/DECISOES.md`, `docs/DEBITO-TECNICO.md`, `docs/history/DEBITO-RESOLVIDO.md` nem `docs/history/SETUP-HISTORICO.md`. Escreve `docs/changes/<id>.md` (modelo em `templates/fragmento-fase.md`). A integração aplica e apaga o fragmento e o registro. Arquivo novo (`docs/history/fases/<id>.md`, ADR novo) nasce na branch: não conflita.

Seções: `changelog`, `historico`, `roadmap-remove` (um id por linha), `roadmap-add`, `decisoes` (`secao: Nome` e a linha da tabela), `debito-add`, `debito-resolve` (o id), `debito-resolvido`. Linha de `roadmap-add` com `**F-xxx**` substitui a linha antiga desse id. Sem linha em `changelog`, a integração sai 6.

O aplicador aceita os dois formatos de ledger: item de lista (`- **F-xxx** — …`, `- F-xxx — …`, o deste template) e linha de tabela (`DECISOES`, depois da última `|` da seção) entram colados; parágrafo (`**F-xxx** — …`, `**D-xxx** — …`, a nota `> Resolvido …`) entra com uma linha em branco antes e depois, e o que sai leva uma das brancas em volta. A linha de outra fase não se toca.

Na solitária esses arquivos são editados direto, como antes. O fragmento não existe e a integração não procura.

**Exemplo:** a fase tira a si do roadmap e deixa `- **F-020** — exportar — depende de F-012` em `roadmap-add`. No merge, a linha velha de F-020 sai e a nova entra em `## Próximas`.

**Âncora:** `scripts/lib/integracao.sh` › `integracao_aplicar_fragmento`.

**Rejeitado:** a fase paralela editar o ledger "porque o rebase resolve". Dois appends no mesmo fim de arquivo são exatamente o conflito chato; o fragmento tira a fase desse arquivo.

**Origem:** F-metodo-v6, ADR-002.

## R-004 — Conflito trivial, trava e merge

A integração rebaseia a branch em `origin/main`. Conflito em `CHANGELOG`, `SETUP-HISTORICO`, `DECISOES`, `ROADMAP`, `DEBITO-TECNICO`, `DEBITO-RESOLVIDO`, `SETUP.md` ou `docs/reference/atritos.md` é trivial só se a fase não tirou nem reescreveu linha que não é dela. Linha dela é a que tem `**<id>**` ou começa com `- <id> `. Menção `depende de <id>` não autoriza apagar a linha de outra fase. Os dois lados que só acrescentam linha ficam com as duas. Qualquer outro arquivo em conflito é lógica: o rebase fica parado.

A trava é o ref `refs/integracao/lock` no remoto (mensagem `lock <id>`). Outra fase recebe exit 3. A mesma fase entra de novo (`--continuar`). `--abortar` aborta o rebase e solta a trava; roda também do checkout principal, sem a branch da fase, e aí só solta a trava (a rota quando a branch já sumiu). Não se solta trava alheia. Depois do `fechar-pr.sh` a integração segue do checkout principal: o `gh` tira o worktree da branch apagada, e o script não pode ficar numa pasta que sumiu. Se o `integrar-fase.sh` da branch difere do `origin/main`, roda a versão do `main`, de uma cópia: a correção do script vale pra fase cortada antes dela.

Saídas do script: 0 integrou; 1 uso, branch ou git, ou integrou com pendência (o `fechar-pr.sh` falhou depois do merge, a limpeza não fechou ou o `conferir-fecho.sh` acusou: a trava já está solta e o stderr diz o que falta); 3 trava alheia; 4 conflito de lógica; 5 validação falhou ou o PR não integrou no `fechar-pr.sh`; 6 fragmento sem changelog. Em 4, 5 e 6 a trava fica. `SETUP.md` com título `# F-` também para: o fecho devolve o template e commita antes.

Depois do rebase a validação é `scripts/validar.sh`, salvo `INTEGRACAO_VALIDAR` em teste. Sem esse script, não integra. Então o push da branch e o PR, se ainda não há. **O merge é do fecho comum**, `scripts/fechar-pr.sh <pr> [--issue N]`, chamado do checkout principal (ADR-003): espera os checks, põe o PR em dia com `gh pr update-branch --rebase`, integra por `gh pr merge --rebase --delete-branch`, fecha a issue e avança o `main` local por fast-forward. Com o PR `MERGED`, a integração solta a trava, tira o worktree e o branch local e roda o `scripts/conferir-fecho.sh`.

O script pode `push --force-with-lease` somente em branch `fase/*`, depois do rebase. O hook continua barrando force na mão e aponta este script.

**Exemplo:** duas solitárias acrescentam linhas diferentes no fim do `CHANGELOG`. A segunda integração fica com as duas. As duas reescrevem a mesma linha que não é delas, ou uma apaga essa linha enquanto a outra a reescreve → exit 4, `main` intacto. As duas editam o mesmo `.ts` → exit 4, `main` intacto.

**Âncora:** `scripts/integrar-fase.sh` › `resolver_um`; `scripts/lib/integracao.sh` › `integracao_resolver_ledger`.

**Rejeitado:** `merge=union`. Não distingue linha apagada de linha nova e estraga tabela.

**Origem:** F-metodo-v6, ADR-002.

## R-005 — Fila de dependência

Item que depende de uma fase ainda não integrada não abre. `scripts/abrir-fase.sh --depende-de <id>` sai 2 se esse id não está no `CHANGELOG` da base. A fila é, nesta ordem de leitura: linha do `ROADMAP` com `depende de <id>`, seção `roadmap-add` dos fragmentos das fases ativas, e o corpo de issue aberta com a mesma frase. `scripts/fases-ativas.sh` imprime a fila. Id que já está no `CHANGELOG` não bloqueia.

Quem abre a dependência leva a linha da dependente com `--enfileirar` (ou `scripts/enfileirar.sh --na <id> --linha '…'` se a fase já está aberta e o worktree está limpo). Worktree sujo: o script recusa; a linha fica na issue e no fragmento no fecho.

**Exemplo:** F-020 diz `depende de F-012` e F-012 não está no `CHANGELOG`. F-020 não abre. Quando F-012 integra, a linha já está no `ROADMAP` e a próxima sessão pode abrir F-020.

**Âncora:** `scripts/abrir-fase.sh` › `--depende-de`; `scripts/enfileirar.sh`.

**Rejeitado:** abrir a dependente na mesma leva e "resolver a ordem no merge". O merge serial não cria o código que a outra fase precisa ler.

**Origem:** F-metodo-v6, ADR-002.

## R-006 — Canal com fases paralelas

O contrato v1 não muda. A pasta do canal já é por id de fase (`~/.canal/<projeto>/F-012/…`), então duas fases não misturam pedido. Cada execução lê só a seção `## Bots` do `SETUP.md` do próprio worktree. O teto diário é do projeto: as fases dividem. Pedidos ao mesmo bot dentro de `agrupar_segundos` podem sair num POST só, com um ponteiro por fase — o JSON já é uma lista. Sem bot na spec, a fase paralela também é só code.

**Exemplo:** F-010 e F-011 pedem `marketing` no mesmo minuto. Um POST, dois caminhos em `avisos[]`. As respostas voltam cada uma na pasta da própria fase.

**Âncora:** `docs/reference/canal.md` › Árvore; `templates/spec-fase.md` › `## Bots`.

**Rejeitado:** serializar bots porque as fases são paralelas. O canal já separa por id; serializar de novo só atrasaria.

**Origem:** F-metodo-v6, emenda ADR-001.

## R-007 — Um restart de produção por leva (add-on opcional)

Só para projeto em que o merge no `main` publica imagem e um workflow faz o deploy sozinho. Leva com fase de produção (a que muda o que vai pra imagem ou pro banco) segura o deploy automático na abertura e o solta no fim, com um restart só. `scripts/deploy-segurado.sh segurar` grava a hora na variável `DEPLOY_SEGURADO` do repositório; com ela preenchida, o workflow de deploy automático do projeto termina verde sem recriar nada, e o build segue publicando. Com a última fase no `main`, `soltar` espera os builds e os deploys automáticos em andamento, apaga a variável e dispara o deploy manual se houve imagem desde a hora gravada; sem imagem nova, não reinicia nada. `scripts/fases-ativas.sh` e `scripts/conferir-fecho.sh` avisam quando a variável segue preenchida e não há mais leva. Os nomes dos workflows e o prefixo dos jobs de build são do projeto (variáveis no cabeçalho do script). Projeto sem deploy automático ignora esta regra e o script.

**Exemplo:** F-020 muda o backend e F-021 muda a interface. A sessão da leva roda `segurar` antes do primeiro `abrir-fase.sh`. Os dois merges publicam imagem e o deploy não roda. Com F-021 no `main`, `soltar` dispara um deploy manual: um restart, não dois.

**Âncora:** `scripts/deploy-segurado.sh`; `scripts/fases-ativas.sh` › alarme do esquecido; `/planejar-fase` (abertura e fecho da leva).

**Rejeitado:** pausar o deploy desligando o runner ou o workflow (some o deploy sem ninguém notar e não deixa rastro da hora); segurar na fase solitária (um merge, um deploy, não há o que juntar).

**Origem:** F-metodo-v8, portado do Amplug F-116.

## Fluxo

1. Planejar no checkout da `main`, com `scripts/fases-ativas.sh --fetch`.
2. Solitária: gravar a spec no `SETUP.md`, sem commit. Paralela: `scripts/abrir-fase.sh` por fase. Não abrir pull request aqui.
3. Executar no worktree, da sessão aberta no checkout principal (paralela), ou na branch da fase neste checkout (solitária). Uma sessão por fase.
4. Fechar: critérios, revisão de contexto fresco, docs. Paralela preenche o fragmento e esvazia o `SETUP.md`. Solitária edita os ledgers.
5. Em projeto com deploy no merge, a fase de produção para aqui e espera o ok do dono, com o que muda, o risco e o que testar (`AGENTS.md` §Git). Com o ok, ou nas demais: `scripts/integrar-fase.sh --id <id> [--issue N]` (paralela: `(cd <worktree> && …)`, da sessão no checkout principal). Se sair 4 ou 5, parar e mostrar o stderr ao dono.
6. O script já roda o `scripts/conferir-fecho.sh <pr> [--issue N]` no fim, do checkout principal: `ok`, e `git ls-remote origin refs/integracao/lock` volta vazio.
7. Fim da leva: a sessão que planejou solta o deploy segurado, se houver (R-007), arquiva as sessões de fase e entrega o resumo ao dono.

## Validação e CI

`scripts/validar.sh` é a validação do projeto. Neste template ele roda os testes dos hooks e destes scripts (a lista é explícita, e o `scripts/validar.test.sh` reprova teste versionado que ficou de fora) e o `shellcheck`, quando o binário existe. Tudo roda no bash 3.2 do macOS: sem `declare -A`, `mapfile` nem `readarray`. Projeto derivado acrescenta typecheck, lint e teste da stack no mesmo arquivo. O workflow `.github/workflows/validar.yml` roda esse script em pull request e em push na `main`. Ele não mergeia e não serializa: a trava é o ref no git. Duas validações podem correr juntas; dois merges, não.

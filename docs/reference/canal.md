# Canal — contrato v1

> Pra que serve: o contrato do canal entre o agente de código e os bots (ou um humano no lugar deles). Add-on opcional. Quem consulta quem está em `AGENTS.md` §Bots; aqui está o como. Quem cumpre o aviso é `scripts/canal-avisar.sh`. Fases paralelas não mudam este contrato (R-006 em `docs/reference/integracao.md`).

## Liga e desliga

Sem bot na issue de trabalho e sem seção `## Bots` na spec, o canal não existe para aquela fase: o agente não lê esta pasta e não acorda ninguém. A seção da spec é a lista que vale na execução. Ela herda a issue; se o planejamento tirar ou trocar um bot, a spec mostra a lista nova. Uma fase pode ter vários bots. O agente só fala com os listados, e só no modo declarado para aquele bot.

Modos, um ou mais por bot: `planejamento` (plan mode), `codificação` (code mode), `disponível-para-dúvidas` (os dois, só quando houver dúvida concreta no para quê daquele bot).

## Lista

A mesma linha na issue (`.github/ISSUE_TEMPLATE/trabalho.md`) e na spec (`templates/spec-fase.md`):

`- \`<slug>\`: <modo>[, <modo>] — <para quê>`

O slug é minúsculo, casa com `[a-z0-9-]`, com a chave em `bots.yaml`, com a pasta do bot e com a etiqueta opcional `bot:<slug>`. A etiqueta só filtra. A seção é a fonte. `(nenhum)`, seção vazia ou seção ausente = só code.

Exemplo: `- \`marketing\`: planejamento, disponível-para-dúvidas — QA de vídeo e roteiro`

## Pasta

Fora do git, uma por projeto. `CANAL_DIR`, se estiver definida, é a raiz absoluta deste canal. Senão, `$CANAL_HOME/<projeto>`, com `CANAL_HOME` padrão `~/.canal` e `<projeto>` o nome da pasta do checkout principal (o mesmo quando quem chama está num worktree de fase). O campo `projeto:` do `bots.yaml` é esse nome.

Na raiz: `LEIA.md`, `bots.yaml` e, quando o aviso existir, `avisos.log` e `.avisados`. O `bots.yaml` mapeia cada bot para o arquivo `.env` do webhook (caminho absoluto, fora do repo, permissão 600), para os `tipos` que ele atende e para o que ele não faz (`proibido:`). Modelo em `templates/canal/`. Segredo não entra no `bots.yaml`.

Chaves do `.env` do bot: `CANAL_WEBHOOK_URL`, `CANAL_WEBHOOK_CHAVE`, e opcionais `CANAL_WEBHOOK_CABECALHO` (padrão `Authorization`) e `CANAL_WEBHOOK_PREFIXO` (padrão `Bearer `). Cada bot tem URL e chave próprias.

## Árvore

Uma pasta por unidade de trabalho, nesta ordem: se há fase, o id dela (`F-012`, `F-metodo-v5`), mesmo que também haja issue; se não há fase e há issue, `issue-<n>`; se não há nem fase nem issue, `sem-issue`. Dentro, uma pasta por slug de bot, com `pedidos/` e `respostas/`.

`~/.canal/exemplo/F-012/marketing/pedidos/2026-11-14-1530-roteiro-qa.md`

`~/.canal/exemplo/F-012/marketing/respostas/2026-11-14-1530-roteiro-qa.md`

## Nome do arquivo

`AAAA-MM-DD-HHMM-<slug>-<tipo>.md`, hora local de 24 h, sem dois-pontos. O slug do nome é o assunto (pode ter hífen). O `tipo` é o último trecho e tem de estar em `tipos` daquele bot no `bots.yaml`. O pedido e a resposta usam o mesmo nome. Um arquivo, um bot.

## Pedido

Frontmatter, depois o corpo. Obrigatório: `canal: v1`, `tipo`, `de`, `para`. Opcional: `issue` (número), `fase` (id), `prazo` (ISO-8601; vazio = não bloquear a sessão). `de` é quem escreve (`agente`, `humano` ou o slug de outro bot). `para` é o slug da pasta. Chave desconhecida não muda o v1. Modelo: `templates/canal/pedido.md`.

## Resposta

O mesmo nome em `respostas/`. A primeira linha do arquivo é `status:`, sem linha em branco antes, com um destes valores: `aprovado`, `reprovado`, `respondido`, `pendente`. O corpo vem em seguida. Quem escreve grava um temporário no mesmo diretório (`<nome>.md.tmp`) e renomeia por cima do destino. Quem lê ignora `.tmp` e ignora arquivo cuja primeira linha não é `status:`. Modelo: `templates/canal/resposta.md`.

`pendente` é a parada para o dono: ação cara ou decisão que o bot não toma sozinho. O `status:` é único: não existe outro campo de estado. Projeto que precisar de mais um valor o declara aqui, marcado como extensão do projeto, e ensina quem espera a resposta a reconhecê-lo.

### A resposta como handoff

Depois da linha `status:`, o corpo é um handoff: o que o próximo leitor precisa para agir sem refazer o trabalho.

- `task:` o que foi respondido, numa frase.
- `output:` o que o pedido pedia, em itens numerados.
- `sources:` o que foi visto, com o caminho.
- `next owner:` quem age agora (`agente`, `humano`, `dono`, o slug de um bot).
- Opcionais: `decisions:` (o que ficou decidido e por quê), `uncertainties:` (o que o bot não sabe), `do-not-assume:` (o que o leitor não deve supor).

Cada afirmação de fato leva uma marca, antes dela:

- `VERIFIED`: visto no arquivo ou na execução, agora.
- `INFERRED`: conclusão do bot a partir do que viu.
- `UNKNOWN`: não sabe e não tem como saber daqui.
- `SOURCE UNAVAILABLE`: o arquivo ou o link citado não abriu.

Afirmação sem marca vale como `INFERRED`.

## Aviso

Cada bot tem a própria rotina de webhook. O POST leva só ponteiros, nunca o corpo do pedido, a URL ou a chave. Vários pedidos ao mesmo bot dentro de `agrupar_segundos` saem num POST só.

`{"canal":"v1","para":"marketing","avisos":[{"tipo":"qa","pedido":"F-012/marketing/pedidos/2026-11-14-1530-roteiro-qa.md","fase":"F-012","issue":null}]}`

O caminho em `pedido` é relativo à raiz do canal. A chave vai ao cliente HTTP pela entrada padrão (config no stdin), nunca no argv, no `ps`, no log, na issue ou no commit. O log do canal (`avisos.log`) guarda hora, slug, caminho relativo e o HTTP. Três tentativas, 30 s entre elas; esgotadas, uma linha no log e saída diferente de zero.

A verificação de certificado fica ligada. É proibido `-k`, `--insecure` e `NODE_TLS_REJECT_UNAUTHORIZED=0`: a máquina do dono usa a cadeia corporativa, e desligar a verificação não é contorno.

Arquivo em `respostas/` não gera aviso. A rotina não chama o webhook de volta.

`teto_diario` em `bots.yaml` é o máximo de POSTs (acordares) daquele projeto no dia. Passou do teto: o arquivo do pedido fica no disco, o POST não sai, o log registra o corte. Sem a chave `teto_diario`, não há aviso — teto ausente não vira ilimitado. Resposta de bot não conta no teto. O exemplo do template usa `teto_diario: 40` e `agrupar_segundos: 60`; o projeto ajusta os dois.

**O aviso é silencioso e idempotente.** Pedido já avisado (o mesmo caminho relativo, registrado em `.avisados` na raiz do canal) não reenvia. Um POST que falhou não marca o pedido como avisado: o próximo aviso o leva junto. O script imprime uma linha por chamada e nada mais; só a falha vai pro `stderr`.

**`falha` e `fim`, só na trilha fora do ciclo.** O disparador de uma trilha (`AGENTS.md` §Trilha fora do ciclo) manda, no mesmo formato de `avisos`, dois itens que não têm `pedido`: `{"tipo":"falha","issue":N,"motivo":"…","log":"…"}` (a trilha parou e não segue sozinha) e `{"tipo":"fim","issue":N,"resultado":"ok"|"pendente","pendencias":[…],"log":"…"}` (o fim do disparo, depois do `scripts/conferir-fecho.sh`; `pendente` não é sucesso). Saem um por disparo, sem agrupamento, e contam no teto. Projeto sem trilha não usa os dois.

Quem cumpre o aviso é `scripts/canal-avisar.sh` (`--para <bot>`; pede `jq` e `curl`).

## Custo

A espera pela resposta é um loop de shell com `sleep`, nunca uma sequência de leituras do modelo. Sem `prazo`, a sessão segue no que não depende da resposta e lê `respostas/` no próximo passo. Aviso é pedido novo, não boletim de progresso.

Gerar vídeo, gerar imagem e usar browser são ação cara: a resposta é `status: pendente`, descreve o que faria e para. O dono aprova. Prefira API, SSH, CLI ou MCP. O projeto pode estreitar o que conta como ação cara (o que o dono já decidiu fazer em casa não é), desde que escreva aqui a regra dele.

## Trilha

Só a trilha fora do ciclo (`AGENTS.md` §Trilha fora do ciclo) usa esta seção; o contrato v1 acima não muda. O disparador `scripts/disparar-trilha.sh --skill <skill> --modelo <id> --effort <nível> [--bot <bot>] <issue>` roda a skill em `claude -p`. Modelo e effort são sempre informados (flag ou `TRILHA_MODELO`, `TRILHA_EFFORT`), sem valor de fábrica: faltando um, o disparo não roda. O `init` do stream tem de trazer o modelo informado (o id inteiro), senão `falha`.

A skill grava `<raiz>/issue-<n>/estado.json` a cada disparo: `{"estado":"esperando|pronto|falha","espera":"<unidade>/<bot>/respostas/<nome>.md","pr":N,"motivo":"…"}`. `esperando` pede `espera`: o disparador chama `scripts/canal-esperar.sh` (loop de `sleep` em shell; `CANAL_ESPERA_INTERVALO` 120 s, `CANAL_ESPERA_TETO` 4 h; a resposta só vale estável e com `status:`) e dispara de novo, até `TRILHA_VOLTAS` voltas (8). `pronto` pede `pr` e é conferido pelo `scripts/conferir-fecho.sh`. Um aviso por disparo, `fim` ou `falha`, só com `--bot`.

## Proibido por bot

Cada bot tem no `bots.yaml` uma lista `proibido:` do que ele não faz neste canal. A rotina a recebe no prompt; o agente de código a consulta antes de pedir. O modelo em `templates/canal/bots.yaml` traz o mínimo: não escrever em `pedidos/` nem fora de `respostas/`, não chamar o webhook, não copiar segredo, não gastar sem aprovação do dono e não inventar dado.

## Sem webhook

O mesmo contrato vale sem bot do outro lado. Com `env` vazio ou arquivo ausente, ninguém é acordado por POST: um humano ou outro agente escreve `respostas/` na mesma forma. A fase que não lista bot não usa esta pasta.

## O agente de código

Consulta só a lista da spec, só no modo daquele bot, só no para quê declarado. Grava o pedido no caminho deste contrato e avisa com `scripts/canal-avisar.sh`. Lê a lista `proibido:` do bot antes de pedir. Não lê o `.env`, não imprime a chave, não commita `~/.canal/` nem segredo. Não improvisa o POST e não faz polling em turno de modelo.

## Fases paralelas

Duas fases no ar não compartilham pasta: a árvore já é `F-<id>/`. Cada execução lê a seção `## Bots` do `SETUP.md` do próprio worktree. O `teto_diario` é do projeto, então as fases dividem o mesmo teto. Pedidos ao mesmo bot dentro de `agrupar_segundos` saem num POST só, com um ponteiro por fase — `avisos` já é lista. Sem bot na spec, a fase paralela também é só code.

## Prompt da rotina

Texto da rotina de webhook de cada bot. O aviso já trouxe os ponteiros; a rotina não pede o corpo de novo.

```
Você foi acordado por um aviso do canal v1. O JSON traz ponteiros em avisos[].pedido, relativos à raiz do canal do projeto. Leia esse arquivo. O aviso é só ponteiro e pode estar incompleto: a cada acordar, varra também as pastas <unidade>/<seu slug>/pedidos/ atrás de pedido sem resposta com o mesmo nome (o que ficou no disco acima do teto ou chegou sem aviso) e responda a todos, um a um.

Responda com o mesmo nome, na pasta respostas/ irmã de pedidos/. A primeira linha é `status:` com um de: aprovado, reprovado, respondido, pendente. Grave um temporário no mesmo diretório e renomeie por cima do destino. Não escreva em pedidos/. Não chame o webhook. Depois do status, escreva task, output, sources, next owner (e, se couber, decisions, uncertainties, do-not-assume). Marque com VERIFIED, INFERRED, UNKNOWN ou SOURCE UNAVAILABLE as afirmações de fato.

Gerar vídeo, gerar imagem ou abrir browser fica em status: pendente, com o que você faria. Prefira API, SSH, CLI ou MCP. Quem aprova a ação cara é o dono.

Siga a sua lista proibido: do bots.yaml. Não copie chave, URL de webhook nem segredo para a resposta, para o log ou para a issue.
```

## Adoção

1. Crie a raiz (`CANAL_DIR` ou `~/.canal/<projeto>/`) e copie `templates/canal/LEIA.md`, `bots.yaml`, `pedido.md` e `resposta.md`. Ajuste `projeto:` e apague o bot que não entra.
2. Para cada bot, crie o `.env` fora do repo, `chmod 600`, com `CANAL_WEBHOOK_URL` e `CANAL_WEBHOOK_CHAVE`. Aponte `env:` no `bots.yaml`. Sem webhook ainda, deixe `env` vazio: um humano responde em `respostas/`.
3. Na rotina do bot (uma por bot, URL e chave próprias), cole o prompt da seção acima. A rotina lê o ponteiro e escreve a resposta; não devolve o conteúdo no webhook. Acrescente ao prompt a lista `proibido:` daquele bot.
4. Abra issue pelo template Trabalho. A seção Bots lista slug, modos e para quê. Etiqueta `bot:<slug>` só se quiser filtrar.
5. No plan mode, a spec herda essa seção. Na execução, o agente grava o pedido na pasta da fase (ou `issue-<n>`, ou `sem-issue`), avisa com `scripts/canal-avisar.sh <unidade>/<bot>/pedidos/<nome>.md` e lê a resposta do mesmo nome.

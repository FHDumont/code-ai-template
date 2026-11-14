# Canal — contrato v1

> Pra que serve: o contrato do canal entre o agente de código e os bots (ou um humano no lugar deles). Add-on opcional. Quem consulta quem está em `AGENTS.md` §Bots; aqui está o como. Os scripts que cumprem o aviso ficam na F-metodo-v6.

## Liga e desliga

Sem bot na issue de trabalho e sem seção `## Bots` na spec, o canal não existe para aquela fase: o agente não lê esta pasta e não acorda ninguém. A seção da spec é a lista que vale na execução. Ela herda a issue; se o planejamento tirar ou trocar um bot, a spec mostra a lista nova. Uma fase pode ter vários bots. O agente só fala com os listados, e só no modo declarado para aquele bot.

Modos, um ou mais por bot: `planejamento` (plan mode), `codificação` (code mode), `disponível-para-dúvidas` (os dois, só quando houver dúvida concreta no para quê daquele bot).

## Lista

A mesma linha na issue (`.github/ISSUE_TEMPLATE/trabalho.md`) e na spec (`templates/spec-fase.md`):

`- \`<slug>\`: <modo>[, <modo>] — <para quê>`

O slug é minúsculo, casa com `[a-z0-9-]`, com a chave em `bots.yaml`, com a pasta do bot e com a etiqueta opcional `bot:<slug>`. A etiqueta só filtra. A seção é a fonte. `(nenhum)`, seção vazia ou seção ausente = só code.

Exemplo: `- \`marketing\`: planejamento, disponível-para-dúvidas — QA de vídeo e roteiro`

## Pasta

Fora do git, uma por projeto. `CANAL_DIR`, se estiver definida, é a raiz absoluta deste canal. Senão, `$CANAL_HOME/<projeto>`, com `CANAL_HOME` padrão `~/.canal` e `<projeto>` o basename do repositório. O campo `projeto:` do `bots.yaml` é esse nome.

Na raiz: `LEIA.md`, `bots.yaml` e, quando o aviso existir, `avisos.log`. O `bots.yaml` mapeia cada bot para o arquivo `.env` do webhook (caminho absoluto, fora do repo, permissão 600) e para os `tipos` que ele atende. Modelo em `templates/canal/`. Segredo não entra no `bots.yaml`.

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

`pendente` é a parada para o dono: ação cara ou decisão que o bot não toma sozinho.

## Aviso

Cada bot tem a própria rotina de webhook. O POST leva só ponteiros, nunca o corpo do pedido, a URL ou a chave. Vários pedidos ao mesmo bot dentro de `agrupar_segundos` saem num POST só.

`{"canal":"v1","para":"marketing","avisos":[{"tipo":"qa","pedido":"F-012/marketing/pedidos/2026-11-14-1530-roteiro-qa.md","fase":"F-012","issue":null}]}`

O caminho em `pedido` é relativo à raiz do canal. A chave vai ao cliente HTTP pela entrada padrão (config no stdin), nunca no argv, no `ps`, no log, na issue ou no commit. O log do canal (`avisos.log`) guarda hora, slug, caminho relativo e o HTTP. Três tentativas, 30 s entre elas; esgotadas, uma linha no log e saída diferente de zero.

A verificação de certificado fica ligada. É proibido `-k`, `--insecure` e `NODE_TLS_REJECT_UNAUTHORIZED=0`: a máquina do dono usa a cadeia corporativa, e desligar a verificação não é contorno.

Arquivo em `respostas/` não gera aviso. A rotina não chama o webhook de volta.

`teto_diario` em `bots.yaml` é o máximo de POSTs (acordares) daquele projeto no dia. Passou do teto: o arquivo do pedido fica no disco, o POST não sai, o log registra o corte. Sem a chave `teto_diario`, não há aviso — teto ausente não vira ilimitado. Resposta de bot não conta no teto. O exemplo do template usa `teto_diario: 40` e `agrupar_segundos: 60`; o projeto ajusta os dois.

## Custo

A espera pela resposta é um loop de shell com `sleep`, nunca uma sequência de leituras do modelo. Sem `prazo`, a sessão segue no que não depende da resposta e lê `respostas/` no próximo passo. Aviso é pedido novo, não boletim de progresso.

Gerar vídeo, gerar imagem e usar browser são ação cara: a resposta é `status: pendente`, descreve o que faria e para. O dono aprova. Prefira API, SSH, CLI ou MCP.

## Sem webhook

O mesmo contrato vale sem bot do outro lado. Com `env` vazio ou arquivo ausente, ninguém é acordado por POST: um humano ou outro agente escreve `respostas/` na mesma forma. A fase que não lista bot não usa esta pasta.

## O agente de código

Consulta só a lista da spec, só no modo daquele bot, só no para quê declarado. Grava o pedido no caminho deste contrato. Não lê o `.env`, não imprime a chave, não commita `~/.canal/` nem segredo. Não improvisa o POST: quem avisa é o script da F-metodo-v6, ou a rotina que o projeto já tiver apontada para este contrato.

## Até a F-metodo-v6

Este template ainda não traz `canal-avisar` nem o disparador. O pedido é o arquivo. Quem responde — bot já ligado, humano ou outro agente — escreve `respostas/`. O agente não faz polling em turno de modelo e não chama o webhook por conta própria.

## Prompt da rotina

Texto da rotina de webhook de cada bot. O aviso já trouxe os ponteiros; a rotina não pede o corpo de novo.

```
Você foi acordado por um aviso do canal v1. O JSON traz ponteiros em avisos[].pedido, relativos à raiz do canal do projeto. Leia esse arquivo.

Responda com o mesmo nome, na pasta respostas/ irmã de pedidos/. A primeira linha é `status:` com um de: aprovado, reprovado, respondido, pendente. Grave um temporário no mesmo diretório e renomeie por cima do destino. Não escreva em pedidos/. Não chame o webhook.

Gerar vídeo, gerar imagem ou abrir browser fica em status: pendente, com o que você faria. Prefira API, SSH, CLI ou MCP. Quem aprova a ação cara é o dono.

Não copie chave, URL de webhook nem segredo para a resposta, para o log ou para a issue.
```

## Adoção

1. Crie a raiz (`CANAL_DIR` ou `~/.canal/<projeto>/`) e copie `templates/canal/LEIA.md`, `bots.yaml`, `pedido.md` e `resposta.md`. Ajuste `projeto:` e apague o bot que não entra.
2. Para cada bot, crie o `.env` fora do repo, `chmod 600`, com `CANAL_WEBHOOK_URL` e `CANAL_WEBHOOK_CHAVE`. Aponte `env:` no `bots.yaml`. Sem webhook ainda, deixe `env` vazio: um humano responde em `respostas/`.
3. Na rotina do bot (uma por bot, URL e chave próprias), cole o prompt da seção acima. A rotina lê o ponteiro e escreve a resposta; não devolve o conteúdo no webhook.
4. Abra issue pelo template Trabalho. A seção Bots lista slug, modos e para quê. Etiqueta `bot:<slug>` só se quiser filtrar.
5. No plan mode, a spec herda essa seção. Na execução, o agente grava o pedido na pasta da fase (ou `issue-<n>`, ou `sem-issue`) e lê a resposta do mesmo nome.

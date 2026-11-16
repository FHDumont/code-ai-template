# Canal deste projeto

> Pra que serve: quem abre esta pasta (humano, bot ou outro agente) responde por aqui. O contrato inteiro está no repositório, em `docs/reference/canal.md`. Se este arquivo e o contrato divergirem, vale o contrato.

A raiz desta pasta é o canal do projeto (fora do git). `bots.yaml` diz quais bots existem, que tipos de pedido cada um atende, o que cada um não faz (`proibido:`) e onde está o `.env` do webhook. A chave não fica neste arquivo nem no `bots.yaml`.

Cada unidade de trabalho tem uma pasta: o id da fase (`F-012`, `F-metodo-v5`) quando há fase; `issue-<n>` quando há issue e não há fase; `sem-issue` para dúvida avulsa. Dentro, uma pasta por bot, com `pedidos/` e `respostas/`.

O pedido e a resposta usam o mesmo nome: `AAAA-MM-DD-HHMM-<slug>-<tipo>.md`. A resposta vai em `respostas/`, nunca em `pedidos/`. A primeira linha é `status:` (`aprovado`, `reprovado`, `respondido` ou `pendente`). Grave num temporário no mesmo diretório e renomeie por cima do destino. Arquivo `.tmp` e arquivo sem `status:` na primeira linha ainda não são resposta.

O corpo da resposta é um handoff: `task`, `output`, `sources`, `next owner` (e, se couber, `decisions`, `uncertainties`, `do-not-assume`). Marque as afirmações de fato com `VERIFIED`, `INFERRED`, `UNKNOWN` ou `SOURCE UNAVAILABLE`.

Não chame o webhook ao responder. Ação cara (gerar vídeo, gerar imagem, usar browser) não executa: `status: pendente` e o que faria, para o dono aprovar. Prefira API, SSH, CLI ou MCP.

O aviso que acorda um bot leva só o ponteiro do arquivo. A rotina de cada bot usa o prompt em `docs/reference/canal.md` (§Prompt da rotina).

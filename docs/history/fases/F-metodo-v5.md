# F-metodo-v5 — Canal de bots como add-on opcional

## Objetivo

Padronizar a participação de bots no template, como complemento opcional: sem bot declarado, o loop não muda; com bot, issue, spec e canal seguem um contrato só, para o time e para os projetos derivados.

## O que entrou

- **Issue Trabalho** (`.github/ISSUE_TEMPLATE/trabalho.md`) com a seção `## Bots`: um bot por linha, modos `planejamento`, `codificação` e `disponível-para-dúvidas`, e o para quê. Sem bots, a execução é só code. Etiqueta opcional `bot:<slug>` para filtrar; a seção é a fonte. O `achado` continua inbox e aponta para este template.
- **Seção `## Bots` na spec** (`templates/spec-fase.md`). O plan mode herda a issue e não inventa bot (`planejar-fase`, `grilling`). O fecho não commita canal nem chave (`fechar-fase`).
- **Contrato v1** em `docs/reference/canal.md`: pasta `~/.canal/<projeto>/` (`CANAL_DIR` / `CANAL_HOME`), `LEIA.md`, `bots.yaml`, unidade `F-<id>` | `issue-<n>` | `sem-issue`, pasta por bot com `pedidos/` e `respostas/`, nome `AAAA-MM-DD-HHMM-<slug>-<tipo>.md`, frontmatter do pedido, `status:` na primeira linha da resposta com escrita atômica, aviso só com ponteiro, chave fora do repo e verificação de certificado ligada, regras de custo, modo sem webhook, prompt da rotina e adoção.
- **Modelos** em `templates/canal/` (`LEIA.md`, `bots.yaml`, `pedido.md`, `resposta.md`) e `.gitignore` para `.env` / `*.env`.
- **Ponteiro** em `AGENTS.md` §Bots, com uma linha em `CLAUDE.md` e em `.cursor/rules/metodo.mdc`. A regra não se duplica.
- **ADR-001** — add-on neste template, generalizando o canal do amplug, em vez de repo novo.

## Notas de implementação

- Os scripts (`canal-avisar`, disparador, espera no shell, teto, agrupamento) ficam na **F-metodo-v6** (`docs/ROADMAP.md`). Não viraram débito: é fase seguinte, não defeito, e o "não entra" da fase não vai para `DEBITO-TECNICO.md`.
- A base é o canal do amplug (F-089, F-091, `video/scripts/amplug-canal-avisar`): ponteiro em vez de conteúdo, chave em arquivo 600, curl sem a chave no argv, três tentativas com 30 s, resposta com `status:` na primeira linha. O v1 generaliza: vários bots, pasta da fase na frente da pasta da issue, frontmatter `canal: v1`, escrita atômica. O amplug não foi alterado e o script dele não foi copiado.
- `teto_diario: 40` e `agrupar_segundos: 60` são o exemplo do `bots.yaml`, não medição. Sem a chave de teto, o contrato manda não avisar.
- O leitor ignora `.tmp` e arquivo cuja primeira linha não é `status:`. Isso cobre a corrida que o amplug tratava por mtime, do lado de quem escreve.

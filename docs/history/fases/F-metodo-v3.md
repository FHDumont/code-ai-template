# F-metodo-v3 — ADR vira exceção, histórico por fase, grilling proporcional

## Objetivo

Reduzir o custo de contexto e de ritual do método, a partir do que o Vaulty mediu depois de 250 fases: 342 ADRs (5 `superseded`), histórico de 3,7 MB num arquivo só, glossário de 57 KB pré-carregado em toda sessão, e grilling que re-perguntava o já decidido.

## O que entrou

- **ADR ou regra?** — teste em `AGENTS.md` §Regra de migração: só é ADR o que muda contrato, schema, dependência/padrão transversal, custa mais de uma fase pra reverter, ou é método/escopo. O resto é regra de comportamento `R-NNN` em `docs/reference/<assunto>.md`, viva, no presente, com exemplo, âncora, rejeitado e origem.
- **Emenda por rodapé** — bloco `## Emendas` no ADR emendado (única parte mutável); `DECISOES.md` volta a uma linha por ADR, secionado por assunto; status `regra R-NNN` mantém o ponteiro de um ADR relido.
- **Histórico por fase** — `docs/history/fases/<ID>.md` + índice; `scripts/split-historico.py` fatia um histórico existente sem tocar no conteúdo.
- **Glossário quente/frio** — `CONTEXT.md` uma linha por termo; `docs/reference/dominio.md` com exemplos e mecanismo.
- **Spec com teto** — 4 KB, passos de uma linha, porquê por ponteiro, sem `Q1…Qn`.
- **Grilling proporcional** — passo zero (correção: zero ou uma rodada; modelagem: rodadas), três filtros antes de perguntar (já decidido? fato do ambiente? muda o trabalho?), rodada ≥3 justificada, e a apresentação da spec é a confirmação.
- **Fecho sem gate** — o pedido de fecho é a validação; falha ainda para.
- **Regras de método promovidas da memória do agente** — teste tem que falhar no código antigo; revisão que divergiu roda de novo sobre a correção; `git add` por caminho com subagente rodando; ID da fase pelo maior existente; tela nova mostrada durante a execução; perf medida e confortável não é débito.

## Notas de implementação

- O número da regra é o número do ADR de origem (`R-336` = ex-ADR-336): nenhuma citação no código precisa mudar, e a linha do índice é o ponteiro.
- A migração dos ADRs foi feita por um subagente por assunto, com o teste no prompt e a ordem de preservar exemplos e números; o índice foi reconstruído por script a partir do mapeamento de cada agente, com verificação de que toda regra citada existe e nenhum arquivo de ADR ficou sem linha.

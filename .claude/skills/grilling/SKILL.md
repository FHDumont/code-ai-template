---
name: grilling
description: Interroga o dono até chegar a entendimento compartilhado sobre um plano, decisão ou ideia, e fecha gravando a spec da fase em docs/SETUP.md. Use quando o plan mode precisa fechar as decisões de uma fase, quando o dono quer estressar um raciocínio, ou a pedido ("grelha isso", "me interroga", "fecha a spec comigo").
---

Interrogue o dono até chegarem a entendimento compartilhado — e **só sobre o que ainda não está decidido**. Modele o assunto como uma **árvore de decisão**: toda decisão ramifica nas decisões que penduram nela. Pergunta repetida, pergunta já respondida num doc, e pergunta cuja resposta não muda o trabalho são o custo que esta skill existe pra evitar.

## Passo zero — o tamanho da fase decide o tamanho do grilling

Antes da primeira pergunta, classifique a fase e diga ao dono qual é:

- **Correção ou ajuste** — achado do dono em caminho que já existe, defeito medido, mudança que não cria modelo nem tela: **zero ou uma rodada**. Corrija o que ele descreveu. O que você consegue fechar auditando vira **suposição declarada**, num bloco único que ele veta numa resposta só. Achado dele não vira varredura transversal: a generalização, se houver, é uma linha de `ROADMAP.md`, não pergunta.
- **Modelagem ou tela nova** — muda schema, contrato entre pacotes, ou cria fluxo que o dono vai ver: grilling completo, em rodadas.

## Antes de perguntar, procure

**Achar fato é seu trabalho, nunca do dono.** Toda pergunta candidata passa por três filtros antes de sair:

1. **Já está decidido?** `grep` em `docs/DECISOES.md`, `CONTEXT.md`, nas regras `R-NNN` de `docs/reference/` e no arquivo da fase de origem em `docs/history/fases/`. Decisão gravada vira **citação** na spec, não pergunta. Achado que contradiz um ADR aceito: procure o outro ADR que decide a mesma grandeza — conflito entre decisões é a hipótese principal, e ADR mal feito se corrige por emenda ou `superseded`, não se re-pergunta.
2. **É fato do ambiente?** Código, filesystem, `gh`, banco do lab, laudos já feitos em `docs/scratch/`: dispare um subagente e olhe. Só as perguntas a jusante da exploração esperam por ela; o resto da fronteira sai agora. Número que não fecha se resolve com o **documento** (o extrato, o PDF, a linha do banco), não com um menu de hipóteses pro dono confirmar — peça o documento.
3. **A resposta muda o trabalho?** Pergunta é pra decisão que muda o que o dono vai ver ou o que você vai construir. Recomendação óbvia sem alternativa real vira suposição declarada. O inverso também vale: **o que o dono vê na tela** — rótulo, subtipo, cadastro, o que um formulário pede — é decisão dele, e sai como pergunta com alternativas, nunca como linha solta dentro da recomendação. Descartar uma alternativa exige o mesmo grep que a recomendação teve.

Perguntado sobre **recorte**, o dono puxa pro assunto inteiro: varra o que compartilha a mecânica **antes** de perguntar, e traga a medida (quantos lugares, quanto código) em vez de "é estrutural".

## Rodadas

A **fronteira** é toda decisão cujos pré-requisitos já estão resolvidos — o que dá pra perguntar **agora** sem chutar respostas que você ainda não ouviu. Pergunte a fronteira inteira numa rodada só: numere cada pergunta e dê a sua recomendação. Depois espere as respostas.

Cada pergunta sai neste formato:

```
❓ **Q1** — **<título da pergunta>**: <corpo, que pode ter vários parágrafos e alternativas numeradas>

➡️ <sua recomendação>
```

Cada rodada de respostas reformata a árvore — decisão resolvida empurra a fronteira pra fora e destrava o que dependia dela. Pergunta cuja resposta depende de outra ainda aberta **nesta** rodada pertence a uma rodada **posterior**. **Da terceira rodada em diante, abra a rodada dizendo por que ela existe** — qual resposta da anterior destravou o quê. Rodada que não consegue dizer isso é repetição: feche a árvore.

**Termo afiado entra no glossário.** Quando a conversa negocia o nome de um conceito — o dono corrige uma palavra sua, ou vocês escolhem entre dois nomes —, registre na mesma passada: a definição de uma linha em `CONTEXT.md` (com o descartado sob `_Evitar_`) e, se houver exemplo ou mecanismo, o texto cheio em `docs/reference/dominio.md`. A partir dali, use esse termo em tudo.

## Fechamento — grave a spec

A interrogação termina quando a **fronteira está vazia**: todo galho visitado, nada suposto em silêncio. **Não peça uma confirmação separada**: a apresentação da spec é a confirmação, e a aprovação do plano pela ferramenta (`ExitPlanMode` no Claude Code) é o aceite — o dono corrige ali o que não sobreviveu ao papel.

Escreva a spec em `docs/SETUP.md` no formato de `templates/spec-fase.md` — objetivo, escopo com o **NÃO entra** explícito, passos com nomes de arquivo/símbolo **auditados contra o código**, etapas com um commit cada, critério de pronto verificável, e a linha final `Model/effort de execução: <modelo> · <effort>`. Etapa que pede model/effort diferente do da sessão ganha o sufixo `delegar a subagente: <modelo> · <effort>` (critério em `CLAUDE.md` §Model e effort).

**A spec grava decisões, não a interrogação.** As perguntas e respostas (`Q1…Qn`) não entram; cada decisão vira escopo, passo ou critério, com ponteiro pro ADR, pra regra `R-NNN` ou pro termo do `CONTEXT.md` quando o porquê já está gravado — sem reproduzir o argumento. Teto orientativo de **4 KB**: spec maior que isso virou narrativa. Decisão que o dono tomou e não sobreviveu ao papel foi tempo dele jogado fora.

Decisão de arquitetura tomada aqui vira ADR; regra de comportamento vira `R-NNN` em `docs/reference/`; a recusa segue a mesma régua (`AGENTS.md` §ADR ou regra). O teste é o mesmo nos dois sentidos: só é ADR o que muda contrato, schema, dependência ou padrão transversal, ou o que custa mais de uma fase pra reverter.

Gravada a spec, **pare**. A execução é outra sessão.

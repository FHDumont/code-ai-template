---
name: grilling
description: Interroga o dono até chegar a entendimento compartilhado sobre um plano, decisão ou ideia, e fecha gravando a spec da fase em docs/SETUP.md. Use quando o plan mode precisa fechar as decisões de uma fase, quando o dono quer estressar um raciocínio, ou a pedido ("grelha isso", "me interroga", "fecha a spec comigo").
---

Interrogue o dono sem trégua até chegarem a entendimento compartilhado. Modele o assunto como uma **árvore de decisão**: toda decisão ramifica nas decisões que penduram nela.

Trabalhe a árvore em **rodadas**. A **fronteira** é toda decisão cujos pré-requisitos já estão resolvidos — as perguntas que dá pra fazer **agora**, sem chutar respostas que você ainda não ouviu. Pergunte a fronteira inteira numa rodada só: numere cada pergunta e dê a sua recomendação. Depois espere as respostas do dono antes da rodada seguinte.

Cada pergunta sai neste formato:

```
❓ **Q1** — **<título da pergunta>**: <corpo, que pode ter vários parágrafos e alternativas numeradas>

➡️ <sua recomendação>
```

Cada rodada de respostas reformata a árvore — decisão resolvida empurra a fronteira pra fora e destrava o que dependia dela. Recompute a fronteira e faça a rodada seguinte. Pergunta cuja resposta depende de outra ainda aberta **nesta** rodada pertence a uma rodada **posterior**, não a esta.

**Achar fato é seu trabalho, nunca do dono.** Quando uma pergunta da fronteira precisa de um fato do ambiente (código, filesystem, `gh`, docs), dispare um subagente pra achar — não pergunte o que você pode olhar. E não bloqueie: exploração rodando é pré-requisito não resolvido, então só as perguntas a jusante dela esperam o subagente; faça o resto da fronteira agora. As **decisões** são do dono: ponha cada uma na mesa e espere.

**Termo afiado entra no glossário.** Quando a conversa negocia o nome de um conceito — o dono corrige uma palavra sua, ou vocês escolhem entre dois nomes —, registre em `CONTEXT.md` na mesma passada: uma linha de definição, o descartado sob `_Evitar_`. A partir dali, use esse termo em tudo.

## Fechamento — grave a spec

A interrogação termina quando a **fronteira está vazia**: todo galho da árvore visitado, nada suposto em silêncio. Antes de gravar, confirme com o dono que chegaram ao entendimento compartilhado.

Confirmado, escreva a spec em `docs/SETUP.md` no formato de `templates/spec-fase.md` — objetivo, escopo com o **NÃO entra** explícito, passos com nomes de arquivo/símbolo **auditados contra o código** (não hipóteses), etapas com um commit cada, critério de pronto verificável, e a linha final `Model/effort de execução: <modelo> · <effort>`. Etapa que pede model/effort diferente do da sessão ganha o sufixo `delegar a subagente: <modelo> · <effort>` (critério em `CLAUDE.md` §Model e effort).

Cada decisão da árvore aparece na spec como escopo, passo ou critério — decisão que o dono tomou e não sobreviveu ao papel foi tempo dele jogado fora. Decisão de arquitetura que o dono tomou aqui vira ADR (`AGENTS.md` §Regra de migração), inclusive o "não vamos fazer", com status `rejeitado`.

Gravada a spec, **pare**. A execução é outra sessão.

---
name: fechar-fase
description: Fecha a fase em code mode — critérios, revisão de contexto fresco, passada de docs vivos, PR + merge + limpeza de branch, tudo numa sequência sem pausa (o pedido de fecho é a validação).
disable-model-invocation: true
---

Checklist do fecho. As regras vivem em `AGENTS.md` (§Regra de migração, §Git); aqui está a ordem. **O pedido de fecho é a validação:** invocar esta skill — ou pedir o fecho em linguagem natural — significa que o dono testou e libera a sequência inteira, sem pausa no meio. **Falha ainda para:** critério que falha ou revisão que diverge voltam pro código antes de qualquer PR — isso é falha reportada, não pedido de confirmação.

Esta skill **duplica de propósito** o `AGENTS.md` §Git como runbook executável. Se um mudar, o outro muda junto.

O ambiente é do dono: não suba nem derrube nada; build, teste e lint rodam sem ele.

## A sequência — corre inteira, sem pausar

1. **Rode os critérios de pronto da spec**, um por um, com execução real — typecheck, lint, teste dos arquivos tocados. Critério que falhou volta pro código; "feito" só depois de verificado. Teste novo da fase tem que ter **falhado no código antigo** — se ainda não provou o vermelho (worktree ou patch revertido), prove agora; teste que passa idêntico antes e depois da mudança não é critério. Critério escrito com número absoluto de produção se confere pela **estrutura** e o número se reconta, reportando os dois.
2. **Revisão de fecho com contexto fresco.** Dispare um subagente via `Task` que **não** tem o contexto desta sessão e entregue a ele só: os docs vivos, a spec da fase, e o diff (`git diff main...HEAD`). A pergunta dele é uma: *o entregue bate com a intenção da spec, item a item?* Divergiu → corrija e **rode a revisão de novo sobre o commit de correção** — a correção abre defeito novo com frequência, e só a segunda passada vê. Fase que não tocou código pode pular este passo.
3. **Passada única de docs vivos**, tudo antes do commit final: spec inteira de `SETUP.md` → `docs/history/fases/F-xxx.md` (arquivo novo) mais **uma linha** no índice `docs/history/SETUP-HISTORICO.md`, com o bloco **Notas de implementação** (desvios, soluções não-óbvias, becos evitados — memória, não log); uma linha em `docs/CHANGELOG.md` (`F-xxx — o que entrou — AAAA-MM-DD`); fase removida do `ROADMAP.md`; `DEBITO-TECNICO.md` atualizado (débito novo, e o resolvido migrando inteiro pro histórico com nota de como foi); ADR novo se a entrega divergiu por decisão de arquitetura, regra `R-NNN` em `docs/reference/` se o que mudou foi comportamento com exemplo (`AGENTS.md` §ADR ou regra); `CONTEXT.md` (e `docs/reference/dominio.md`) se a fase afiou algum termo.
4. **Commite por caminho explícito** — nunca `git add -A` com subagente rodando: o working tree é compartilhado; confira o `git status` antes. A passada de docs pode ir junto com a etapa final **ou** num commit `docs: fecho da F-xxx` próprio — desde que esse não carregue código (regra canônica em `AGENTS.md` §Regra de migração).
5. `gh pr create` com corpo curto: o que/por quê, os critérios, e a referência à `F-xxx`.
6. Confirme os **checks verdes**. Um CI por fecho: o build que dispara no merge é entrega, não gate — não espere um segundo.
7. `gh pr merge --rebase --delete-branch` — os commits da fase entram lineares no `main`, um por etapa, e a branch some na remota e na local. O hook bloqueia `git branch -D`; esta é a rota oficial.
8. Sincronize: `git switch main && git pull`.
9. Confirme com `git branch`: só `main`, atualizado com o `origin/main`. O dono não toca no GitHub. **Relate ao dono no fim:** cada critério com seu resultado, o veredito da revisão de fecho, os docs tocados, e o PR integrado.

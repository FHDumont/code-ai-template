---
name: fechar-fase
description: Fecha a fase em code mode — critérios, revisão de contexto fresco, passada de docs vivos, pausa pra validação do dono e, liberado, PR + merge + limpeza de branch.
disable-model-invocation: true
---

Checklist do fecho. As regras vivem em `AGENTS.md` (§Regra de migração, §Git); aqui está a ordem, e onde se para.

## Antes da validação do dono

1. **Rode os critérios de pronto da spec**, um por um, com execução real — build, teste, run. Critério que falhou volta pro código; "feito" só depois de verificado.
2. **Revisão de fecho com contexto fresco.** Dispare um subagente via `Task` que **não** tem o contexto desta sessão e entregue a ele só: os docs vivos, a spec da fase, e o diff (`git diff main...HEAD`). A pergunta dele é uma: *o entregue bate com a intenção da spec, item a item?* Divergiu → corrija antes de seguir. Fase que não tocou código pode pular este passo.
3. **Passada única de docs vivos**, tudo antes do commit final: spec inteira de `SETUP.md` → `docs/history/SETUP-HISTORICO.md` com o bloco **Notas de implementação** (desvios, soluções não-óbvias, becos evitados — memória, não log); uma linha em `docs/CHANGELOG.md` (`F-xxx — o que entrou — AAAA-MM-DD`); fase removida do `ROADMAP.md`; `DEBITO-TECNICO.md` atualizado (débito novo, e o resolvido migrando inteiro pro histórico com nota de como foi); ADR novo se a entrega divergiu por decisão de arquitetura; `CONTEXT.md` se a fase afiou algum termo.
4. **Commite** a etapa final e **pare**. Relate ao dono: cada critério com seu resultado, o veredito da revisão de fecho, os docs tocados, e o que ficou de fora e por quê.

O fecho para **aqui** — PR, merge e limpeza esperam o dono validar. Salvo se o prompt de abertura já autorizou o fecho sem teste; nesse caso siga direto.

## Depois de liberado — sem pausar no meio

5. `gh pr create` com corpo curto: o que/por quê, os critérios, e a referência à `F-xxx`.
6. Confirme os **checks verdes**. Um CI por fecho: o build que dispara no merge é entrega, não gate — não espere um segundo.
7. `gh pr merge --rebase` — os commits da fase entram lineares no `main`, um por etapa.
8. Apague a branch **remota e local**, e sincronize: `git switch main && git pull`.
9. Confirme com `git branch`: só `main`, atualizado com o `origin/main`. O dono não toca no GitHub.

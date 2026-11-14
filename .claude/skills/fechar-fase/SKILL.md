---
name: fechar-fase
description: Fecha a fase em code mode — critérios, revisão de contexto fresco, docs, e a integração serial no main. O pedido de fecho é a validação; falha ainda para.
disable-model-invocation: true
---

Checklist do fecho. As regras vivem em `AGENTS.md` (§Regra de migração, §Git) e em `docs/reference/integracao.md`. **O pedido de fecho é a validação:** invocar esta skill — ou pedir o fecho em linguagem natural — significa que o dono testou e libera a sequência inteira, sem pausa no meio. **Falha ainda para:** critério que falha, revisão que diverge, ou integração que sai diferente de 0 voltam pro código ou param na decisão do dono — falha reportada, não pedido de confirmação.

O merge não se faz nesta skill. O passo 5 entrega para `/integrar-fase`, que roda `scripts/integrar-fase.sh`. Se o script mudar de saída, esta skill muda junto.

O ambiente é do dono: não suba nem derrube nada; build, teste e lint rodam sem ele.

## A sequência — corre inteira, sem pausar

1. **Rode os critérios de pronto da spec**, um por um, com execução real — typecheck, lint, teste dos arquivos tocados. Critério que falhou volta pro código; "feito" só depois de verificado. Teste novo da fase tem que ter **falhado no código antigo** — se ainda não provou o vermelho (worktree ou patch revertido), prove agora; teste que passa idêntico antes e depois da mudança não é critério. Critério escrito com número absoluto de produção se confere pela **estrutura** e o número se reconta, reportando os dois.
2. **Revisão de fecho com contexto fresco.** Dispare o subagente **`revisor-fecho`** (`.claude/agents/revisor-fecho.md`) via `Task`; ele **não** tem o contexto desta sessão, e você entrega só a spec da fase e o alvo (`git diff main...HEAD` neste worktree). Divergiu → corrija e **rode o `revisor-fecho` de novo tendo o commit de correção como alvo**. Fase que não tocou código pode pular.
3. **Passada de docs, no modo da fase.** Sem `docs/fases-ativas/<id>.md` neste worktree, é **solitária**: spec inteira de `SETUP.md` → `docs/history/fases/F-xxx.md` mais uma linha em `docs/history/SETUP-HISTORICO.md`, linha no `CHANGELOG.md`, fase fora do `ROADMAP.md`, `DEBITO-TECNICO.md` atualizado, ADR ou `R-NNN` se couber, `CONTEXT.md` se a fase afiou termo. O `SETUP.md` volta ao template vazio. Com registro `modo: paralela`, **não edite** `CHANGELOG`, `ROADMAP`, `DECISOES`, `DEBITO-TECNICO`, `DEBITO-RESOLVIDO` nem `SETUP-HISTORICO` — essas linhas vão para `docs/changes/<id>.md` (R-003, modelo em `templates/fragmento-fase.md`). O arquivo `docs/history/fases/F-xxx.md` nasce na branch mesmo assim. Depois de `git fetch origin main`, devolva `docs/SETUP.md` ao que está em `origin/main` e deixe o registro com `status: integrando`. Não apague o registro: a integração apaga. Notas de implementação só com o que vale reler (desvios, soluções não-óbvias). `~/.canal/`, `.env` e chave de webhook ficam de fora.
4. **Commite por caminho explícito** — nunca `git add -A`. A passada de docs pode ir no último commit substantivo **ou** num `docs: fecho da F-xxx` sem código.
5. **Integre.** Siga `/integrar-fase`: `scripts/integrar-fase.sh --id F-xxx --titulo "…" --corpo docs/history/fases/F-xxx.md`. Saída diferente de 0 para a sequência. Conflito de lógica ou validação que falha não se contorna com merge na mão.
6. **Relate ao dono:** cada critério, o veredito da revisão, os docs tocados, e o resultado da integração (PR, ou a saída que parou). Em solitária, no fim o checkout útil é a `main`. Em paralela, as outras fases continuam nos worktrees delas.

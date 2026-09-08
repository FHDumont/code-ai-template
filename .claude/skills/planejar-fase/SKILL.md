---
name: planejar-fase
description: Abre o plan mode do método — inbox de achados, docs vivos, auditoria do código e grilling até a spec da próxima fase estar em docs/SETUP.md.
disable-model-invocation: true
---

Ritual de abertura do **plan mode**. As regras vivem em `AGENTS.md` (§O loop, §Docs vivos, §Inbox de achados); aqui está a ordem de execução.

Entre em plan mode antes do passo 1 — esta passada raciocina e escreve spec, e não toca em código.

1. **Esvazie o inbox.** `gh issue list --label achado --state open` e leia o que houver. Deixe a triagem pro passo 7: o achado pode caber na fase que você está prestes a desenhar, e você só saberá depois de auditar.
2. **Carregue os vivos quentes.** `docs/SETUP.md` (a fase atual — se tiver spec aberta, a fase ainda não fechou: pare e diga isso ao dono), `docs/ROADMAP.md` (o que vem) e `CONTEXT.md` (o vocabulário, uma linha por termo; o texto cheio está em `docs/reference/dominio.md`, frio — leia só o termo que a fase toca). Toque em área com débito conhecido? Some `docs/DEBITO-TECNICO.md`. `CHANGELOG`, `DECISOES`, as regras `R-NNN` e `docs/history/fases/` são frios: `grep` pelo ID quando precisar de um.
3. **Confira o ID da fase.** Próximo = maior `F-NNN` presente em `docs/CHANGELOG.md`, `docs/history/SETUP-HISTORICO.md` e `docs/ROADMAP.md`, mais um — não "o último que eu vi mais um": ID reusado só aparece na revisão de fecho.
4. **Audite o código real.** A fase candidata mexe em schema, enum ou estado persistido? Leia migrations, tipos e dados antes de qualquer pergunta — spec que presume estado inexistente custa uma fase inteira. Nomes de arquivo e símbolo que entrarem na spec saem daqui verificados. Antes de disparar um agente de auditoria, confira `docs/scratch/`: laudo já feito sobre o assunto se lê, não se refaz. Dispare subagentes pra varrer em paralelo.
5. **Declare seu model/effort** ao dono e, se ele estiver sub ou superdimensionado pra esta fase, **peça a troca antes de seguir** — sem esperar ele perguntar (`CLAUDE.md` §Model e effort).
6. **Rode o `grilling`** com o material dos passos 1–4 na mão. O passo zero dele — correção (zero ou uma rodada) ou modelagem (rodadas) — decide quanto interrogatório a fase merece; os achados abertos entram na árvore como galhos candidatos ao escopo. O grilling fecha gravando a spec (em `docs/SETUP.md`, ou no arquivo de plano quando a ferramenta não deixa o plan mode escrever no repo — `CLAUDE.md`).
7. **Feche o inbox.** Cada achado lido no passo 1 tem agora um destino: escopo da spec, linha nova no `ROADMAP.md`, item de `DEBITO-TECNICO.md`, regra `R-NNN`, ou ADR — inclusive ADR `rejeitado`, quando a resposta foi "não vamos fazer" e a recusa é arquitetural. `gh issue close` em cada um, citando pra onde foi.
8. **Entregue ao dono:** a spec gravada, os achados fechados e o que cada um virou, e o `Model/effort de execução` recomendado. Ele aprova, dá `/clear`, e a execução é outra sessão.

Pronto = a spec gravada e aprovada (no `SETUP.md`, ou no arquivo de plano que a execução copia pra lá), zero issue `achado` aberta sem destino, e o dono sabendo qual model/effort abrir.

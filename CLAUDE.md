# CLAUDE.md

`AGENTS.md` é a instrução canônica e a fonte única do método — **leia primeiro**, tudo lá vale aqui. Este arquivo só mapeia a mecânica do loop pros botões do Claude Code.

## Os rituais são skills

Os três momentos do loop têm skill própria em `.claude/skills/` — **é a forma preferida de acioná-los**, porque a ordem dos passos já vem dentro:

| Skill | Quando | O que faz |
| ----- | ------ | --------- |
| `/planejar-fase` | abrindo o plan mode | inbox de achados → docs vivos quentes → auditoria do código → `grilling` → spec em `docs/SETUP.md` |
| `/fechar-fase` | fim da fase em code mode | critérios → revisão de contexto fresco → passada de docs → PR/merge/limpeza, **sem pausa** — falha ainda para |
| `/verificar-referencia` | de tempos em tempos | novidades dos repos de `docs/reference/referencias.md` → issues `achado` → SHA avançado |

A quarta, `grilling`, é a primitiva model-invoked por trás do `/planejar-fase` — interroga o dono em rodadas até a fronteira de decisões esvaziar. Chame direto quando quiser estressar um raciocínio fora do ritual.

## Mecânica no Claude Code

- **Plan mode = a passada de raciocínio.** Nele você audita o código, discute o aberto e **redige a spec** no formato de `templates/spec-fase.md`. `docs/SETUP.md` continua sendo o plano canônico (`AGENTS.md`); a mecânica do Claude Code é que o plan mode **não grava arquivos do repo**, então a spec nasce no arquivo de plano da ferramenta e `ExitPlanMode` (aprovação do plano) = aprovação da spec. **Aprovada, o último ato do plan mode é copiá-la, sem alteração, pro `docs/SETUP.md`** — junto com os demais destinos da triagem (linhas do `ROADMAP.md`, item de `DEBITO-TECNICO.md`), tudo **não commitado**: o commit é da execução. Copiar não é tarefa do code mode porque **a fase pode ser executada por outro agente** (Cursor, Codex…), que não lê o arquivo de plano do Claude Code. O arquivo de plano é rascunho e não versiona. Não planeje o trivial: o passo zero do `grilling` decide se a fase é correção (zero ou uma rodada) ou modelagem (rodadas).
- **`/clear` entre os modos** (não `/compact`): aprovada a spec e gravada no `docs/SETUP.md` pelo plan mode, o dono limpa o contexto e a execução roda numa sessão nova: lê só o `SETUP.md`. Copiar a spec **não** é do code mode (bullet acima).
- **Inbox de achados no início do plan mode:** `gh issue list --label achado --state open` antes de auditar o código. Triagem e fecho de issue seguem `AGENTS.md` §Inbox de achados.
- **Subagentes = `Task`.** Os definidos em `.claude/agents/`: `varredura` (coordenadas `arquivo:linha`, modelo leve) e `revisor-fecho` (a revisão de fecho de contexto fresco). A revisão de fecho (`AGENTS.md` §O loop) e a etapa marcada `delegar a subagente` na spec rodam via `Task`. O código delegado volta pro working tree da sessão principal e segue o fluxo normal — diff revisado, critérios, commit por etapa. Delegar não é pular revisão.
- **Fecho da fase pela CLI `gh`.** A sequência inteira — critérios, revisão, docs, PR, merge, limpeza — está em `AGENTS.md` §Git, e o `/fechar-fase` a executa na ordem. O dono não toca no GitHub.
- **Git destrutivo é bloqueado por hook.** `.claude/hooks/block-dangerous-git.sh`, registrado como PreToolUse/Bash em `.claude/settings.json`, barra `push --force`, `reset --hard`, `clean -f`, `branch -D` e `commit` com o branch atual em `main` — as regras de `AGENTS.md` §Git viradas guardrail duro. A mensagem do bloqueio traz a rota certa; **siga por ela ou peça ao dono, sem contornar o hook**. `block-comandos-do-dono.sh` faz o mesmo com os comandos que só o dono roda (`git add` cego, mais os do projeto). Cada hook tem seu `.test.sh` ao lado.
- **Prompts curtos:** o dono aciona fases com instruções curtas (ex.: "planeja a próxima fase", "executa a fase do SETUP") ou pela skill do ritual. O contexto vem dos docs vivos, não do prompt.

## Model e effort

O dono seta **um** model/effort ao abrir a sessão, e ele vale a sessão inteira — o agente não troca o próprio model/effort no meio da execução. Guia neutro: **modelo forte** = raciocínio pesado / decisão aberta / design; **modelo médio** = execução envolvida padrão; **modelo leve** = mecânico trivial.

- **Toda spec fechada no plan mode termina com `Model/effort de execução: <modelo> · <effort>`** — a recomendação explícita pra sessão de code mode.
- **Variação por etapa vira delegação.** Etapa que pede model/effort diferente do da sessão entra na spec como **`delegar a subagente: <modelo> · <effort>`**, e o code mode obedece automaticamente via `Task`. Delegue a etapa **mecânica e autocontida** — a spec da etapa precisa carregar todo o contexto necessário, já que subagente não herda o fio da sessão; etapa que depende do fio fica na sessão principal.
- **O plan mode declara sob qual modelo/effort está rodando** e, se julgar o modelo sub ou superdimensionado pra tarefa, **avisa o dono pra trocar** antes de seguir — proativamente e sem condição, mesmo que o dono não pergunte.
- **Subagente escolhe o próprio model/effort.** Task disparada em plan mode (pesquisa, exploração, agente `Plan`) ou em code mode (revisão de fecho, investigação pontual) decide model/effort livremente, sem pedir aprovação antes e independente da sessão principal — cada subagente roda isolado. Quando a spec já nomeia `delegar a subagente: <modelo> · <effort>`, essa decisão gravada prevalece sobre a escolha livre.

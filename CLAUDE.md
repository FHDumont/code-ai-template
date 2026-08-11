# CLAUDE.md

`AGENTS.md` é a instrução canônica — **leia primeiro**, tudo lá vale aqui. Este arquivo só mapeia a mecânica do loop pros botões do Claude Code.

## Os rituais são skills

Os três momentos do loop têm skill própria em `.claude/skills/` — **é a forma preferida de acioná-los**, porque a ordem dos passos e as pausas já vêm dentro:

| Skill | Quando | O que faz |
| ----- | ------ | --------- |
| `/planejar-fase` | abrindo o plan mode | inbox de achados → docs vivos quentes → auditoria do código → `grilling` → spec em `docs/SETUP.md` |
| `/fechar-fase` | fim da fase em code mode | critérios → revisão de contexto fresco → passada de docs → **pausa pro dono** → PR/merge/limpeza |
| `/verificar-referencia` | de tempos em tempos | novidades dos repos de `docs/reference/referencias.md` → issues `achado` → SHA avançado |

A quarta, `grilling`, é a primitiva model-invoked por trás do `/planejar-fase` — interroga o dono em rodadas até a fronteira de decisões esvaziar. Chame direto quando quiser estressar um raciocínio fora do ritual.

## Mecânica no Claude Code

- **Plan mode = a passada de raciocínio.** Nele você audita o código, discute o aberto e **redige a spec no `docs/SETUP.md`**. `ExitPlanMode` (aprovação do plano) = aprovação da spec. Não planeje o trivial.
- **`/clear` entre os modos** (não `/compact`): aprovada a spec, o dono limpa o contexto e a execução roda numa sessão nova, lendo só o `SETUP.md`.
- **Inbox de achados no início do plan mode:** `gh issue list --label achado --state open` antes de auditar o código. Triagem e fecho de issue seguem `AGENTS.md` §Inbox de achados.
- **Subagentes = `Task`.** A revisão de fecho de contexto fresco (`AGENTS.md` §O loop) roda como subagente via `Task`, com só os docs vivos + o diff; etapa marcada `delegar a subagente` na spec também.
- **Fecho da fase via `gh`.** Rode os critérios + revisão de fecho e **pare** pra validação do dono; **depois de liberado**, execute o fecho inteiro sem parar: PR → merge `--rebase` → apaga a branch (remota + local) → `git switch main && git pull`. Ao terminar, `git branch` mostra só `main` atualizado. (Regra canônica: `AGENTS.md` §Git.)
- **Git destrutivo é bloqueado por hook.** `.claude/hooks/block-dangerous-git.sh`, registrado como PreToolUse/Bash em `.claude/settings.json`, barra `push --force`, `reset --hard`, `clean -f`, `branch -D` e `commit` com o branch atual em `main` — as regras de `AGENTS.md` §Git viradas guardrail duro. A mensagem do bloqueio traz a rota certa; siga por ela ou peça ao dono, sem contornar o hook.
- **Prompts curtos:** o dono aciona fases com instruções curtas (ex.: "planeja a próxima fase", "executa a fase do SETUP") ou pela skill do ritual. O contexto vem dos docs vivos, não do prompt.

## Model e effort

O dono seta **um** model/effort ao abrir a sessão, e ele vale a sessão inteira — o agente não troca o próprio model/effort no meio da execução. Guia neutro: **modelo forte** = raciocínio pesado / decisão aberta / design; **modelo médio** = execução envolvida padrão; **modelo leve** = mecânico trivial.

- **Toda spec fechada no plan mode termina com `Model/effort de execução: <modelo> · <effort>`** — a recomendação explícita pra sessão de code mode.
- **Variação por etapa vira delegação.** Etapa que pede model/effort diferente do da sessão entra na spec como **`delegar a subagente: <modelo> · <effort>`**, e o code mode obedece automaticamente via `Task`. Delegue a etapa **mecânica e autocontida** — a spec da etapa precisa carregar todo o contexto necessário, já que subagente não herda o fio da sessão; etapa que depende do fio fica na sessão principal.
- **O plan mode declara sob qual modelo/effort está rodando** e, se julgar o modelo sub ou superdimensionado pra tarefa, **avisa o dono pra trocar** antes de seguir — proativamente e sem condição, mesmo que o dono não pergunte.
- **Subagente escolhe o próprio model/effort.** Task disparada em plan mode (pesquisa, exploração, agente `Plan`) ou em code mode (revisão de fecho, investigação pontual) decide model/effort livremente, sem pedir aprovação antes e independente da sessão principal — cada subagente roda isolado. Quando a spec já nomeia `delegar a subagente: <modelo> · <effort>`, essa decisão gravada prevalece sobre a escolha livre.

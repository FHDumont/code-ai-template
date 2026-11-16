# F-metodo-v9 — corte anunciado e menu de execução no fim do planejamento

## Objetivo

O dono não precisa mais perguntar se o planejamento cogitou fases paralelas, e não fica preso ao "`/clear` e abra outra sessão". O planejador **decide o corte sozinho e o anuncia com o motivo**, e no fim **oferece um menu de execução**, que pode incluir uma sessão gerenciada também pra fase solitária.

## Escopo

1. **Corte anunciado, nunca perguntado.** O passo 7 do `/planejar-fase` e o grilling sempre avaliam primeiro se a leva cabe em paralelas. A decisão segue a regra de afinidade atual, que continua valendo (menos fases e mais etapas; produção numa fase só). A entrega diz **"Modo: solitária | paralela (N) — porque <motivo>"**, inclusive por que *não* paralelizou. Não há pergunta sobre isso.
2. **Menu de execução no passo 13** (`AskUserQuestion` no Claude Code; lista numerada nas outras ferramentas). Só aparecem as opções que valem pro modo:
   - **Executar aqui, sem limpar** (só na solitária). Esta sessão sai do plan mode e executa. Se o model/effort desta sessão diferir do `Model/effort de execução` da spec, a opção diz isso no texto e recomenda abrir um agente. O agente não troca o próprio modelo.
   - **Abrir agente** (solitária). `start_session` com `cwd` no checkout principal, `use_worktree: false`, o model/effort da spec e o prompt "Executa a fase <id> do SETUP… placa de estado". Esta sessão vira **gerenciadora**, como na leva: atende as notas, não edita o checkout enquanto a fase corre e arquiva com uma aprovação no fim (passo 14, generalizado pra solitária).
   - **Executar paralelo** (paralela). É o que o passo 13 já faz hoje, agora como opção clicável.
   - **Fazer nada.** Mostra como executar à mão. Na solitária: `/clear`, o modelo/effort sugerido e a frase "executa a fase do SETUP". Na paralela: os prompts do `abrir-fase.sh`.
3. **Fecho liberado ou não.** É uma 2ª pergunta na mesma chamada, que vale pra aqui, agente e paralelo. "Liberado" quer dizer que a execução roda `/fechar-fase` sozinha, e a decisão que ficar aberta vai pra `## Decisões em aberto` ou pra uma issue `achado`. "Não liberado" quer dizer que ela para com os critérios verdes e espera você testar. A fase de produção para antes do `/integrar-fase` nos dois casos, como já é hoje.
4. **Texto alinhado:** `AGENTS.md` §O loop (a fronteira dura: o padrão vira o menu, e "executar aqui" é escolha explícita do dono), `CLAUDE.md` §Mecânica (o bullet do `/clear`), `docs/reference/integracao.md` R-001 (solitária pode ter sessão gerenciada) e o passo 3 do fluxo, `README.md` §loop (o `/clear` vira uma das opções).
5. **Propagação.** Depois do merge, abrir uma issue por repo derivado: `FHDumont/amplug`, `FHDumont/vaulty`, `FHDumont/dumontech-videos`. Título `Atualizar método ao code-ai-template <sha> (corte anunciado, menu de execução)`, label `achado`. O corpo traz o que mudou, os arquivos pra portar e o SHA.

6. **Tabela do gerenciador com 4ª coluna:** `| Fase | Model/effort | Estado | Próximo |`, o valor é o que a sessão de fato roda (o passado no `start_session`). Em `AGENTS.md` §Placa de estado e no passo 14 do `planejar-fase`; vale na solitária gerenciada.

**NÃO entra:** mudar a regra de afinidade; trocar o model/effort da própria sessão; mexer no `abrir-fase.sh` (o prompt da solitária mora na skill); o item F-metodo-v7 do ROADMAP.

## Etapas

1. `.claude/skills/planejar-fase/SKILL.md` (passos 7, 13 e 14) + `.claude/skills/grilling/SKILL.md` (o corte é anunciado com o motivo). Commit `feat:`.
2. `AGENTS.md` §O loop, `CLAUDE.md` §Mecânica, `docs/reference/integracao.md` (R-001 e fluxo) e `README.md` (§loop, linhas ~98, 113, 124). Commit `docs:`.
3. Fecho: `/fechar-fase` (CHANGELOG, histórico, ROADMAP) e `/integrar-fase`.
4. Pós-merge: `gh issue create` nos 3 repos, com o SHA do merge. Os links vão no resumo final.

## Critério de pronto

- `grep -n '/clear' .claude/skills/planejar-fase/SKILL.md` mostra o `/clear` só dentro da opção "fazer nada".
- O passo 13 lista as 4 opções, o filtro por modo, a pergunta de fecho e o aviso de modelo. O passo 14 cobre a solitária gerenciada.
- `AGENTS.md`, `CLAUDE.md`, `integracao.md` e `README.md` não contradizem o menu (grep por "limpa o contexto" e "dono dá").
- `scripts/validar.sh` verde.
- `grep -n 'Model/effort' AGENTS.md .claude/skills/planejar-fase/SKILL.md` mostra a coluna nos dois pontos (placa de estado e passo 14).
- As 3 issues abertas, com os links no resumo.

Model/effort de execução: `claude-sonnet-5-5 · medium`

## Notas de implementação

- **Escopo 6 veio no meio da execução**, pedido do dono pela sessão gerenciadora: a tabela do gerenciador ganhou a coluna Model/effort (o que a sessão de fato roda), commit próprio antes do fecho.
- **Revisão de fecho, primeira passada: um defeito.** "Nunca termina só entregando prompts" contradizia a opção "fazer nada" da paralela (SKILL passo 13, `AGENTS.md`, `CLAUDE.md`); virou "salvo no fazer nada". A segunda passada, sobre a correção, bateu.
- **Divergência de redação da spec:** a opção "Executar aqui" não diz "sai do plan mode", porque no passo 13 a sessão já saiu dele no passo 9.
- **Fora do escopo, anotado:** `.cursor/rules/metodo.mdc:9` e o cabeçalho do `docs/SETUP.md` ainda falam de sessão nova pós-`/clear`, coerente no Cursor, que não inicia sessão. O prompt da paralela (`abrir-fase.sh`) não carrega o fecho liberado ou não: a gerenciadora o acrescenta ao `prompt:` impresso.


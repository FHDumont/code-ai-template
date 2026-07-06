# CLAUDE.md

`AGENTS.md` é a instrução canônica — **leia primeiro**, tudo lá vale aqui. Este arquivo só mapeia a mecânica do loop pros botões do Claude Code.

## Mecânica no Claude Code

- **Plan mode = a passada de raciocínio.** Nele você audita o código, discute o aberto e **redige a spec no `docs/SETUP.md`**. `ExitPlanMode` (aprovação do plano) = aprovação da spec. Effort alto quando há decisão em aberto (arquitetura, schema/estado, trade-off); modelo mais barato quando a spec já decidiu tudo e o trabalho é mecânico. Não planeje o trivial.
- **`/clear` entre os modos** (não `/compact`): aprovada a spec, o dono limpa o contexto e a execução roda numa sessão nova, lendo só o `SETUP.md`.
- **Revisão de fecho = subagente via Task.** Ao fechar a fase, dispare um subagente de **contexto fresco** com só os docs vivos + o diff, pra conferir entregue-vs-spec antes do commit.
- **Passada única de docs:** feche todos os docs vivos afetados (CHANGELOG, ROADMAP, SETUP, DECISOES/DEBITO se aplicável) numa passada antes do commit, pela regra de migração do `AGENTS.md`.
- **Prompts curtos:** o dono aciona fases com instruções curtas (ex.: "planeja a próxima fase", "executa a fase do SETUP"). O contexto vem dos docs vivos, não do prompt.

# CLAUDE.md

Este projeto usa `AGENTS.md` como instrução canônica do agente. **Leia** `AGENTS.md` **primeiro** — tudo que está lá vale aqui. Este arquivo só adiciona o que é específico do Claude Code.

## Extras do Claude Code

- **Plan mode:** use effort alto pra **planejar** quando a spec deixa uma decisão em aberto (arquitetura, trade-off não resolvido). Execute em modelo mais barato quando o trabalho é mecânico (a spec já decidiu tudo). Não planeje o trivial.
- **Passada única de docs:** ao fechar uma fase, atualize todos os docs vivos afetados (CHANGELOG, ROADMAP, SETUP, e DECISOES/DEBITO se aplicável) antes de encerrar, seguindo a regra de migração em `AGENTS.md`. Não deixe doc desatualizado entre commits.
- **Prompts curtos:** o dono costuma acionar fases com instruções curtas (ex.: "leia e execute a fase atual do SETUP.md"). O contexto vem dos docs vivos, não do prompt.

Tudo o mais — papel no loop, docs vivos, regra de migração, princípios — está em `AGENTS.md`.
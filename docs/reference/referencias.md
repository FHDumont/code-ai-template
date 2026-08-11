# Referências vigiadas

> Repos externos de onde o método deste template bebe, e que continuam evoluindo depois de a gente copiar deles. Uma entrada por repo, com o **SHA revisado** — o ponto até onde já olhamos.
> Vigilância pela skill `/verificar-referencia`: puxa o que entrou desde o SHA, classifica adotar/adaptar/ignorar, abre issues `achado` e avança o SHA. A triagem do que vira fase é do plan mode.

## mattpocock/skills

- **Remote:** https://github.com/mattpocock/skills
- **Clone local:** `/Users/fdumont/Developer/mattpocock/skills`
- **SHA revisado:** `84fdeffd12f2ee307994d1eb6feb48173b6e0502` (`84fdeff`, 2026-08-06) — revisado em 2026-08-11
- **Por que vigiamos:** é a fonte de skills de engenharia mais próxima da filosofia daqui — peças pequenas e adaptáveis em vez de framework que assume o processo. As primitivas de método (grilling, writing-for-agents, linguagem ubíqua) valem porte; as skills de engenharia estão disponíveis como plugin (ver README, §Complementos).
- **Já absorvido** (fase `F-metodo-v2`, ver `docs/history/SETUP-HISTORICO.md`): princípios de `productivity/writing-for-agents` aplicados na compressão do `AGENTS.md`; fork em pt-BR de `productivity/grilling` que fecha gravando a spec; formato de `CONTEXT.md` de `engineering/domain-modeling/CONTEXT-FORMAT.md`; hook de `misc/git-guardrails-claude-code` adaptado às regras de git daqui.
- **Deixado de fora por decisão:** changesets/versionamento, marketplace e plugin próprio, `agents/openai.yaml` dual-harness, contrato de docs pra site, e as skills `to-tickets`/`wayfinder`/`triage`/`teach`/`writing-*`.

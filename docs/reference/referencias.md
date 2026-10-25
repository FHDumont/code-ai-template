# Referências vigiadas

> Repos externos de onde o método deste template bebe, e que continuam evoluindo depois de a gente copiar deles. Uma entrada por repo, com o **SHA revisado** — o ponto até onde já olhamos.
> Vigilância pela skill `/verificar-referencia`: puxa o que entrou desde o SHA, classifica adotar/adaptar/ignorar, abre issues `achado` e avança o SHA. A triagem do que vira fase é do plan mode.
>
> **Só os repos vigiados entram na rodada.** A seção final, **Fontes avulsas**, guarda post/palestra/thread de onde absorvemos algo pontual: não tem SHA, não evolui, e a `/verificar-referencia` **pula** — o que ela registra é o argumento já fechado, pra ideia recusada não voltar sem fato novo.

## mattpocock/skills

- **Remote:** https://github.com/mattpocock/skills
- **Clone local:** `/Users/fdumont/Developer/mattpocock/skills`
- **SHA revisado:** `84fdeffd12f2ee307994d1eb6feb48173b6e0502` (`84fdeff`, 2026-08-06) — revisado em 2026-08-11
- **Por que vigiamos:** é a fonte de skills de engenharia mais próxima da filosofia daqui — peças pequenas e adaptáveis em vez de framework que assume o processo. As primitivas de método (grilling, writing-for-agents, linguagem ubíqua) valem porte; as skills de engenharia estão disponíveis como plugin (ver README, §Complementos).
- **Já absorvido** (fase `F-metodo-v2`, ver `docs/history/SETUP-HISTORICO.md`): princípios de `productivity/writing-for-agents` aplicados na compressão do `AGENTS.md`; fork em pt-BR de `productivity/grilling` que fecha gravando a spec; formato de `CONTEXT.md` de `engineering/domain-modeling/CONTEXT-FORMAT.md`; hook de `misc/git-guardrails-claude-code` adaptado às regras de git daqui.
- **Deixado de fora por decisão:** changesets/versionamento, marketplace e plugin próprio, `agents/openai.yaml` dual-harness, contrato de docs pra site, e as skills `to-tickets`/`wayfinder`/`triage`/`teach`/`writing-*`.

## Fontes avulsas (sem SHA — não são repo vigiado)

> Post, palestra ou thread de onde a gente absorveu algo pontual. Não entram na rodada da `/verificar-referencia` (não há SHA pra avançar); ficam aqui pro próximo que topar com a mesma ideia não reabrir a discussão do zero.

### "Portal by Spotify cut my Claude Code token usage by 90%"

- **Fonte:** Dimitri Mazmanov, Spotify Engineering, 2026-09-03.
- **Tese:** roteamento por hook — um hook barra o bulk read do agente forte e força a leitura a passar por um worker de modelo leve; `CLAUDE.md` e skill não seguram porque **aconselham**, só hook **enforça**.
- **Absorvido** (via projeto de origem, portado na F-metodo-v3 e F-metodo-v4):
  - **adaptar** — a tese "só hook enforça, skill é ordem de passos" virou regra do método (`AGENTS.md` §O loop) e o hook `.claude/hooks/block-comandos-do-dono.sh` sobre os comandos que só o dono roda — a tese é adotada, o hook deles não: os comandos são outros.
  - **adaptar** — o bulk-reader mode deles virou `.claude/agents/varredura.md` (`model: haiku`, só bullets `arquivo:linha`), configuração em vez de hook.
  - **ignorar** — o hook de 350 linhas (`check-file-size` / `check-bash-read`). **Medido** em 40 sessões do projeto de origem: zero `Read` de código >350 linhas sem `offset/limit`, `cat` inteiro com média de ~580 tokens, maior leitura única ~7k. O agente já faz grep → leitura por faixa, e com prompt caching o rebilhetado é ~10% do preço cheio. Os 90% do post são de um monorepo Java, não auditados (rodapé do próprio post). Reavaliar só com nova medição mostrando `cat` inteiro de arquivo grande.
  - **ignorar** — modo `code-write` (já é `delegar a subagente: <modelo> · <effort>` na spec) e scripts de transporte pro worker (já é `Agent`/`Task`).
  - **não delegar, como eles:** raciocínio, debug, revisão de fecho e edição — resumo barato não carrega linha confiável.

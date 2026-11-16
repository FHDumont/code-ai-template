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

## FHDumont/amplug

- **Remote:** https://github.com/FHDumont/amplug (privado)
- **Clone local:** `~/Developer/FHDumont/amplug`
- **SHA revisado:** `764c2a6d` (2026-11-15) — revisado em 2026-11-15
- **Por que vigiamos:** é o projeto derivado que mais exercita o método (fases paralelas, canal com bots, trilha de conteúdo, deploy no merge). O que ele aprende de método volta pra cá; o que é do produto (OCPP, banco, lab, deploy no host dele, migrations) fica lá.
- **Já absorvido** (fase `F-metodo-v8`, ver `docs/history/fases/F-metodo-v8.md`), com a fase de origem no Amplug:
  1. Observador de atrito — `AGENTS.md` §Observador de atrito, `docs/reference/atritos.md`, passo no `/fechar-fase` e no `/planejar-fase` (Amplug F-097).
  2. Placa de estado de fim de turno — `AGENTS.md` §Placa de estado, skills, prompt do `abrir-fase.sh`, `status: pronta-para-integrar` (Amplug F-120).
  3. Canal v1 em script — `scripts/canal-avisar.sh`; handoff, marcas e `proibido:` em `docs/reference/canal.md` e `templates/canal/` (Amplug F-097).
  4. Fases paralelas robustas — bash 3.2, trava solta na falha tardia, integração seguindo do checkout principal, versão do `main`, conflito de ledger ponta a ponta (Amplug F-098, F-104, F-106).
  5. Sessão da fase no checkout principal, trabalhando no worktree por caminho absoluto; fecho autônomo liberado no prompt (Amplug F-104, F-110).
  6. Leva paralela gerenciada — quem planejou inicia as sessões, fecha com resumo e arquiva com uma aprovação (Amplug F-107, F-113, F-115).
  7. Fase de produção só integra com o ok do dono; um restart por leva, `scripts/deploy-segurado.sh`, R-007 — os dois opcionais (Amplug F-110, F-116).
  8. Hooks endurecidos — `block-dangerous-git.sh` julga o alvo real do commit; casos de heredoc no `block-comandos-do-dono.sh` (Amplug F-110).
  9. Fecho comum por script — `scripts/fechar-pr.sh`, `scripts/conferir-fecho.sh` e os apoios de teste, ADR-003 (Amplug F-091, ADR-056 de lá).
  10. Trilha fora do ciclo como add-on — `AGENTS.md` §Trilha fora do ciclo, ADR-003 (Amplug F-086 e F-091, ADR-055 e ADR-056 de lá).
  11. Ajustes de texto — `revisor-fecho.md` (o que recebe, "não provado"), `grilling` (corte por afinidade, critério com `grep`, permissão é passo do dono), `templates/` e a linha de bot da issue de trabalho (Amplug F-097, F-098, F-113).
- **Deixado de fora por decisão:** tudo o que é do produto — `lab.sh`, `test-db.sh`, `prod.sh`, `clone-prod.sh`, os hooks `lint-arquivo` e `journal-em-ordem`, as skills `nova-migration` e `produzir-video`, o `auditor-migration`, a extensão "trilha de vídeo" do canal (status `parcial`, `clipes-prontos`, `bloqueado`) e o atalho do `validar.sh` que pula os testes de vídeo. O hook que valide a placa de estado segue candidato (issue #15): sem risco medido, não entra.

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

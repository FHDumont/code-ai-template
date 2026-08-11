# SETUP — histórico

> Specs de fases **concluídas**, na íntegra, cada uma com um bloco **"Notas de implementação"** anexado (desvios da spec, soluções não-óbvias, becos evitados — o que vale reler depois; não é log passo-a-passo). Append quando uma fase fecha.
>
> Imutável. Veja `examples/docs/history/SETUP-HISTORICO.md` pra um exemplo preenchido.

# F-metodo-v2 — Absorver o melhor do mattpocock/skills no template

## Objetivo

Instrumentar o método com o que a análise do repo `/Users/fdumont/Developer/mattpocock/skills` mostrou valer a pena: auditoria de escrita do `AGENTS.md`, glossário de linguagem ubíqua, skills executáveis pros rituais do loop, guardrails de git e vigilância contínua da referência. O método em si não muda de significado — ganha compressão e mecânica.

## Escopo

**Entra:**

- Auditoria/compressão do `AGENTS.md` pelos princípios de writing-for-agents (positivo em vez de negação, leading words, single source of truth entre `AGENTS.md` e flavors).
- **Ajuste de regra de model/effort (única mudança de significado autorizada nesta fase):** a linha `Model/effort de execução:` da spec passa a indicar **um único model/effort pra sessão** (o dono seta ao abrir o code mode — o agente não consegue trocar o próprio model/effort no meio da execução); variação por etapa vira **`delegar a subagente: <modelo> · <effort>`**, que a execução obedece automaticamente via Task. Critério de delegação: etapa mecânica e **autocontida** (a spec da etapa carrega todo o contexto necessário, pois subagente não herda o contexto da sessão) → delega; etapa que depende do fio da sessão → fica na sessão principal.
- `CONTEXT.md` (glossário de linguagem ubíqua) na raiz, esqueleto + exemplo em `examples/`.
- Status `rejeitado` de ADR como registro de "não vamos fazer" (sem estrutura nova).
- Skills em `.claude/skills/`: `grilling` (primitiva model-invoked, fork adaptado em pt-BR que termina gravando a spec no `docs/SETUP.md`), `planejar-fase` (wrapper: inbox de achados + docs vivos + grilling), `fechar-fase` (checklist do fecho com pausa pra validação do dono), `verificar-referencia` (vigilância do repo de referência → issues `achado`).
- Hook `.claude/hooks/block-dangerous-git.sh` + `.claude/settings.json` bloqueando git destrutivo e commit no `main` (adaptado de `skills/misc/git-guardrails-claude-code` do repo de referência).
- `docs/reference/referencias.md` com a primeira entrada (`mattpocock/skills`, caminho local, remote, SHA revisado, data).
- `README.md`: seção "Complementos" recomendando o plugin `mattpocock-skills` como biblioteca opcional (tdd, diagnosing-bugs, code-review, prototype, research) — não é dependência do método.

**NÃO entra (deixar explícito):**

- Mudança de significado de qualquer regra do `AGENTS.md` **além do ajuste de model/effort acima** (auditoria é compressão; outra regra que parecer errada vira nota em "Decisões em aberto", não edição silenciosa).
- Cópia das skills de engenharia do repo de referência (cobertas pelo plugin) — exceto o fork do `grilling`.
- Changesets/versionamento, marketplace/plugin próprio, `agents/openai.yaml` dual-harness, contrato de docs pra site, to-tickets/wayfinder/triage/teach/writing-* (ignorados por decisão desta fase).

## Passos

> Nomes de arquivo/símbolo abaixo auditados no plan mode contra os dois repos. Fontes no repo de referência: `skills/productivity/grilling/SKILL.md`, `skills/productivity/writing-for-agents/SKILL.md` (+ `SKILL-MECHANICS.md`), `skills/misc/git-guardrails-claude-code/scripts/block-dangerous-git.sh`, `skills/engineering/domain-modeling/CONTEXT-FORMAT.md`, `.agents/invocation.md`.

1. Reescrever `AGENTS.md` (e sincronizar `CLAUDE.md` e `.cursor/rules/metodo.mdc` onde citarem texto alterado): negação vira instrução positiva com proibição só como guardrail duro; redundâncias entre seções e entre arquivos colapsam pra uma única fonte; resultado mais curto que o atual. Incorporar o ajuste de regra de model/effort (sessão única + `delegar a subagente` como mecanismo de variação por etapa, com o critério de autocontenção) no `CLAUDE.md` §model/effort e no `templates/spec-fase.md` (linha final e nota das Etapas).
2. Criar `CONTEXT.md` (esqueleto: termos com definição de 1 linha + seção "Evitar") e `examples/CONTEXT.md` (preenchido pro projeto Recados); plan mode passa a pré-carregar `CONTEXT.md` junto de SETUP/ROADMAP; documentar status `rejeitado` no `docs/adr/TEMPLATE.md`, no `docs/DECISOES.md` e no `AGENTS.md` (§docs vivos e §inbox de achados — achado recusado fecha referenciando ADR-rejeitado).
3. Criar as 4 skills em `.claude/skills/<nome>/SKILL.md` seguindo o padrão wrapper-fino-sobre-primitiva: `grilling` (design tree, rounds sobre a frontier, formato `❓ Q1 … ➡️ recomendação`, fatos via subagente / decisões do dono, fecha gravando spec no `docs/SETUP.md` no formato `templates/spec-fase.md` com linha `Model/effort de execução`, atualizando `CONTEXT.md` quando termos forem afiados); `planejar-fase`; `fechar-fase`; `verificar-referencia` (lê `docs/reference/referencias.md`, `git -C <clone> pull`, diff de CHANGELOG/commits desde o SHA revisado, classifica adotar/adaptar/ignorar, abre issues `achado`, atualiza o SHA). Atualizar `CLAUDE.md` apontando as skills como forma preferida de acionar os rituais.
4. Adaptar o hook de git guardrails pra `.claude/hooks/block-dangerous-git.sh` + registro PreToolUse/Bash em `.claude/settings.json`: bloquear `push --force`, `reset --hard`, `clean -f`, `branch -D` e commit direto no `main`.
5. Criar `docs/reference/referencias.md` com a entrada do `mattpocock/skills` e o SHA atual do clone.
6. Passada única de docs: seção "Complementos" no `README.md`; no fecho, CHANGELOG/ROADMAP/SETUP→histórico conforme regra de migração.

## Etapas

1. **Etapa 1 — Auditoria writing-for-agents do AGENTS.md** · commit: `docs: comprime AGENTS.md pelos princípios de writing-for-agents`
2. **Etapa 2 — CONTEXT.md + ADR rejeitado** · commit: `docs: adiciona CONTEXT.md de linguagem ubíqua e status rejeitado de ADR`
3. **Etapa 3 — Skills do loop** · commit: `feat: adiciona skills grilling, planejar-fase, fechar-fase e verificar-referencia`
4. **Etapa 4 — Hook de git guardrails** · commit: `feat: adiciona hook que bloqueia git destrutivo e commit no main`
5. **Etapa 5 — Registro da referência** · commit: `docs: registra mattpocock/skills como referência vigiada`
6. **Etapa 6 — Passada de docs** · commit: `docs: recomenda plugin mattpocock-skills e fecha docs vivos da fase`

## Critério de pronto

- `AGENTS.md` mais curto que o atual e, na revisão de fecho, conferido item a item como semanticamente equivalente.
- `CONTEXT.md` esqueleto + `examples/CONTEXT.md`; status `rejeitado` documentado nos três lugares.
- 4 skills invocáveis: `/planejar-fase` roda inbox + grilling; `/fechar-fase` para na validação do dono; `/verificar-referencia` reporta "sem novidades" logo após o registro do SHA.
- Hook bloqueia `git commit` no `main` e `push --force` (testado sem efetivar nada destrutivo).
- `docs/reference/referencias.md` com SHA atual do clone.
- docs vivos atualizados (CHANGELOG, ROADMAP; DECISOES/DEBITO se aplicável).

## Decisões em aberto

- (nenhuma)

---

Model/effort de execução: `Opus 5 · high` (sessão). Etapa 4 — delegar a subagente: `Sonnet 5 · medium` (autocontida: adaptar script + registrar hook). Etapa 6 fica na sessão (fecho depende do fio da fase). Demais subagentes com autonomia de model/effort (CLAUDE.md).

## Notas de implementação

**A compressão do `AGENTS.md` precisou de duas passadas.** A etapa 1 cortou ~145 palavras (fundindo "Seu papel no loop" + "Fluxo plan ⇄ code" + "Uma fase de cada vez" numa seção só, e virando negações em instrução positiva), mas a etapa 2 devolveu ~124 em conteúdo novo — `CONTEXT.md` quente, status `rejeitado`, achado recusado. Medido no fim da etapa 6, o arquivo estava **maior** que o original, e o critério de pronto pedia menor. Segunda passada de corte na etapa 6 fechou em 2600 palavras contra 2632. Lição pra quem repetir: **critério de tamanho se mede na etapa que o fecha, não na que o produz** — etapa posterior que adiciona conteúdo come a compressão da anterior sem que ninguém perceba.

**A revisão de fecho pagou por si, duas vezes.** Ela pegou (a) um **homoglifo cirílico** (`U+0435`) no meio de uma instrução do `/planejar-fase`, invisível na leitura e fatal pra qualquer `grep`, e (b) duas regras que a reescrita positiva tinha **enfraquecido sem autorização**: o "Não coda" do plan mode, que sobrevivera só nos flavors (`.cursor` e a skill) — ou seja, uma regra canônica passou a morar só nos derivados —, e o "Nunca resuma sem ponteiro", virado frase descritiva. Ambas repostas. O padrão a vigiar numa auditoria de escrita: **virar negação em positivo é onde a regra perde força**, e o revisor tem que comparar regra a regra, não parágrafo a parágrafo.

**O script de guardrails da fonte bloqueava demais.** O original barra `git push` inteiro, `git checkout .` e `git restore .`. Aqui o agente **precisa** publicar a branch da fase e integrar o PR, então a adaptação restringe o bloqueio a `push --force`/`-f`/`--force-with-lease` e libera `checkout .`/`restore .`. O bloqueio de `commit` no `main` é dinâmico (consulta `git branch --show-current` via `$CLAUDE_PROJECT_DIR`), e não existia na fonte. Detalhe que quase mordeu: o script segmenta comandos compostos com `sed -E 's/(&&|\|\||;|\|)/\n/g'` — o `\n` no replacement é armadilha clássica de BSD sed; foi verificado com `od -c` que produz newline real neste macOS. Portar pra outro ambiente pede reteste desse ponto.

**`branch -D` bloqueado tem rota alternativa embutida.** Como o fecho apaga a branch da fase e ela vem rebaseada (o que faz `git branch -d` recusar), a mensagem de bloqueio aponta pra `gh pr merge --rebase --delete-branch`, que apaga remota e local de uma vez. Sem isso o guardrail travaria o próprio fecho do método.

**Duplicação que a fase não conseguiu zerar.** A sequência do fecho (PR → checks → merge → limpeza) aparece por extenso em `AGENTS.md` §Git e no `/fechar-fase`. O `CLAUDE.md` foi reduzido a ponteiro, mas a skill mantém os comandos de propósito: um runbook que só aponta pra outro arquivo deixa de ser executável. É duplicação consciente, não descuido — se `AGENTS.md` §Git mudar, a skill muda junto.

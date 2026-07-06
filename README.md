# project-template

Template de onboarding para novos projetos. Não traz stack nem framework — traz um **método de trabalho** que alterna dois modos do mesmo agente, raciocínio (**plan**) e execução (**code**), com **docs vivos** servindo de memória compartilhada entre os modos e entre sessões.

É agnóstico de ferramenta. O núcleo funciona com qualquer agente de código (Claude Code, Cursor, Copilot, Codex, etc.) via `AGENTS.md`. *Flavors* finos por ferramenta em `CLAUDE.md` (Claude Code) e `.cursor/rules/metodo.mdc` (Cursor).

---

## Por que funciona

Uma superfície, **dois modos** — os dois no agente, os dois com o repo na mão:

- **Plan mode (raciocínio):** lê os docs vivos e **audita o código real**, discute, decide, e **grava a spec da fase no `SETUP.md`**. Não coda. Nomes de arquivo/símbolo nascem verificados, não hipóteses.
- **Code mode (execução):** em sessão nova (contexto limpo), lê a spec, implementa aterrado, e atualiza os docs vivos numa passada. Ao fechar, uma **revisão de contexto fresco** (subagente que só vê docs vivos + diff) confere entregue-vs-spec antes do commit.

A fronteira entre planejar e executar — com o contexto limpo no meio — impede o agente de arrastar o raciocínio pra dentro da execução e entupir a janela, e mantém cada fase como tarefa independente. O handoff entre os modos, e a continuidade entre sessões, acontece pelos **docs vivos**.

## A regra que mantém tudo enxuto

Doc vivo responde **onde estamos / pra onde vamos / o que está aberto**, no menor número de palavras. Todo o resto — *como chegamos aqui* — vai pra histórico ou fica atrás de um ponteiro. Cada doc vivo fica curto por um de dois mecanismos:

- **expulsa** conteúdo quando ele fecha (SETUP, DEBITO-TECNICO), ou é um **ledger**: 1 linha por evento, com o detalhe pesado offloaded em outro arquivo (CHANGELOG → SETUP-HISTORICO; DECISOES → docs/adr).

Resumir só é seguro com **ponteiro**: cada linha resumida referencia onde está o detalhe. Resumo sem ponteiro é perda; resumo com ponteiro é compressão.

O "como/por quê" de uma fase tem três destinos por tipo: **decisão de arquitetura** → ADR; **narrativa de implementação** (desvios, soluções não-óbvias) → bloco de notas anexado à fase no SETUP-HISTORICO; **o diff literal** → git. As regras mecânicas de migração (quando mover o quê pra onde) estão em `AGENTS.md`.

---

## Estrutura

```
AGENTS.md                  instruções do agente (núcleo agnóstico) — use como está
CLAUDE.md                  flavor Claude Code (mecânica do loop) → aponta pro AGENTS.md
.cursor/rules/metodo.mdc   flavor Cursor (mesma mecânica) → aponta pro AGENTS.md
CONVENCOES.md              padrões de código/UI DESTE projeto (preencha; estável)

docs/                      ← só arquivos VIVOS (estado atual)
├─ ROADMAP.md              fases futuras + a atual; 1 linha por fase
├─ CHANGELOG.md            1 linha por fase entregue (ledger, append-only)
├─ DECISOES.md             índice de ADRs; 1 linha por decisão (ledger)
├─ DEBITO-TECNICO.md       só débito ABERTO
├─ SETUP.md                spec da fase ATUAL — exatamente uma
├─ adr/                    referência: texto cheio dos ADRs (imutável por entrada)
│  ├─ TEMPLATE.md          modelo de ADR
│  └─ ADR-000.md           convenção de numeração
├─ history/                arquivado (imutável)
│  ├─ SETUP-HISTORICO.md   specs concluídas + notas de implementação
│  └─ DEBITO-RESOLVIDO.md  débito fechado, com nota de resolução
├─ reference/              (sob demanda) referência durável: how-to, deploy, prompts…
└─ scratch/                (ignorado no git) investigações/spikes efêmeros

templates/                 scaffolding reutilizável
└─ spec-fase.md            formato de uma spec de fase (lido pelo plan mode)

examples/                  PREENCHIDO — leia pra ver o método rodando
├─ docs/                   espelho de docs/ com o projeto-brinquedo "Recados"
├─ CONVENCOES.md           exemplo de convenções (stack TypeScript)
└─ perfil-llm-agente.md    add-on opcional pra projetos de LLM/agentes (ver abaixo)
```

Os arquivos em `docs/` e o `CONVENCOES.md` vêm **vazios** (só estrutura + comentário).
Os de `examples/` vêm **preenchidos** com um projeto-brinquedo coerente ("Recados", uma API de notas) pra você ver como cada doc fica em uso e como as migrações acontecem.

> **`docs/` raiz = só docs vivos.** Os 5 vivos são um conjunto fixo. Doc auxiliar roteia por balde (decisão→ADR, convenção→CONVENCOES, referência durável→`docs/reference/`, investigação efêmera→`docs/scratch/`). Regra e tabela completa em `AGENTS.md`.

---

## Como começar

1. **Use este repo como template** no GitHub (botão *Use this template*) ou clone e
  `rm -rf .git && git init`.
2. **Leia `examples/`** uma vez pra entender o método em uso.
3. **Configure o agente:** o `AGENTS.md` é o núcleo — use como está, ajuste só a seção de stack/comandos. A mecânica por ferramenta já vem pronta: `CLAUDE.md` (Claude Code) e `.cursor/rules/metodo.mdc` (Cursor).
4. **Preencha o** `CONVENCOES.md` com os padrões de código/UI do seu projeto (use `examples/CONVENCOES.md` como molde). Sem convenções fortes ainda? Deixe mínimo e cresça depois.
5. **Defina o ROADMAP:** preencha `docs/ROADMAP.md` com as fases de um MVP enxuto, 1 linha cada.
6. **Rode o loop:** plan mode audita o código e grava a spec da fase em `docs/SETUP.md` → você aprova e limpa o contexto (`/clear` no Claude Code, New Chat no Cursor) → code mode executa, roda a revisão de fecho e atualiza os vivos → você aprova a fase → repete.
7. **(Opcional) apague `examples/`** quando não precisar mais da referência.

### Exemplo: as primeiras interações

O loop é um lugar só: você alterna plan e code com o mesmo agente (Claude Code ou Cursor). Abaixo, uma sequência real de arranque (ajuste os ‹trechos›).

**1) Plan mode — definir o ROADMAP e a primeira spec.** Não há docs vivos ainda; você começa descrevendo o projeto:

```
Estou começando um projeto novo. Projeto: ‹uma API self-hosted pra gerenciar meus links salvos›. Stack: ‹Bun + Hono + SQLite›.

Entre em plan mode: primeiro me proponha as fases de um MVP enxuto (YAGNI), uma linha cada, pro ROADMAP. Quando eu aprovar, audite o repo e grave a spec só da primeira fase em docs/SETUP.md.
```

**2) Limpe o contexto e execute.** Aprovada a spec, dê `/clear` (Claude Code) ou abra um New Chat (Cursor), e rode:

```
Leia e execute a fase atual do docs/SETUP.md, seguindo o AGENTS.md.
```

O agente implementa, roda a **revisão de fecho** (subagente de contexto fresco) e atualiza os docs vivos, parando pra você aprovar a fase.

**Daí em diante**, cada fase é esse par curto — o contexto está nos docs, não no prompt:

```
planeja a próxima fase     →  aprovo e /clear  →  executa a fase do SETUP
```

---

## Add-on opcional: projetos de LLM / agentes

**O que é.** Um perfil de princípios extras pra quem **constrói** software com LLM — orquestração de agentes, integração com modelos, custo de inferência. Fica em `examples/perfil-llm-agente.md`.

**Por que está separado do núcleo.** O `AGENTS.md` é agnóstico de domínio: não assume que você usa IA. Regras como "toda chamada de LLM grava tokens e custo" são valiosas num projeto de IA e puro ruído num site estático ou numa CLI. Por isso o perfil é opt-in, não default.

**Atenção — este é o único arquivo de** `examples/` **feito pra copiar e manter.** O resto de `examples/` é referência pra ler e (se quiser) apagar. Este você tira de lá e incorpora ao seu repo. Pra acoplar:

1. Copie `examples/perfil-llm-agente.md` pra raiz do seu repo, com um nome próprio — ex.: `PERFIL-LLM.md`.
2. Abra seu `AGENTS.md` e adicione uma linha apontando pra ele, na lista do topo: *"Projeto de LLM/agentes — veja também `PERFIL-LLM.md`."* (já há um lembrete lá). O plan mode lê o arquivo direto do repo quando a fase discute arquitetura de agente.

**O que tem dentro** (pra você julgar se precisa):

- **Cost-aware** — toda chamada de LLM captura tokens in/out e custo; estimativa por execução nos comentários.
- **Human-in-the-loop por padrão** — ação que gasta dinheiro ou mexe em recurso externo (email, post) pede aprovação por default.
- **Config-as-Code** — config de agente/tool persistida tem representação serializável; delete faz export antes.
- **Composability** — sem hardcode de prompt/modelo/tool; use registries; tool genérica > one-off.
- **Observability built-in** — cada chamada passa por uma camada de observability; cada execução grava input/output/tokens/custo/modelo/duração.
- **Eval antes de promover** — mudou system prompt em produção? roda eval de regressão (ou ao menos 3–5 inputs conhecidos) antes de marcar como ativo.
- **Custo em dois eixos** — separe custo cobrado por API de custo coberto por assinatura; conflar os dois engana.

As instruções de acoplamento também estão no topo do próprio arquivo, pra quem abrir ele direto sem passar pelo README.

---

## Quando escalar pra ecossistema multi-repo

O template nasce **single-repo** de propósito (YAGNI). Se um dia o projeto virar vários repos que publicam e consomem entre si, duas coisas entram em cena — e só então:

- `publica → consome`**:** mudança de contrato vai do produtor pro consumidor em sequência, nunca em paralelo (paralelo recria drift). O consumidor compila contra o artefato **publicado**, não contra um link em disco.
- **Namespace de ADR por repo:** cada repo ganha um prefixo próprio (`SDK-ADR-NNN`, `APP-ADR-NNN`) pra não colidir numeração. Referência cruzada sempre com prefixo completo. Veja `docs/adr/ADR-000.md`.

Não monte isso antes de ter o segundo repo de verdade.
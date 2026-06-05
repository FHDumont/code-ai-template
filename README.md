# project-template

Template de onboarding para novos projetos. Não traz stack nem framework — traz um **método de trabalho** entre uma superfície de raciocínio (um chat com IA) e uma de execução (um agente de código), com **docs vivos** servindo de memória compartilhada entre as duas e entre sessões.

É agnóstico de ferramenta. O núcleo funciona com qualquer agente de código (Claude Code, Cursor, Copilot, Codex, etc.) via `AGENTS.md`. Há um *flavor* opcional pra Claude Code em `CLAUDE.md`.

---

## Por que funciona

Duas superfícies, papéis separados:

- **Chat (raciocínio):** discute, decide, e emite uma **spec** de fase em texto. Não escreve no repo. Nomes de arquivo/símbolo que ele cita são hipóteses a confirmar.
- **Agente de código (execução):** recebe a spec, implementa aterrado no código real, e atualiza os docs vivos numa passada.

A separação é o que impede o agente de derivar na arquitetura e impede o chat de alucinar sobre o estado do código. O handoff entre os dois — e a continuidade entre sessões — acontece pelos **docs vivos**.

## A regra que mantém tudo enxuto

Doc vivo responde **onde estamos / pra onde vamos / o que está aberto**, no menor número de palavras. Todo o resto — *como chegamos aqui* — vai pra histórico ou fica atrás de um ponteiro. Cada doc vivo fica curto por um de dois mecanismos:

- **expulsa** conteúdo quando ele fecha (SETUP, DEBITO-TECNICO), ou é um **ledger**: 1 linha por evento, com o detalhe pesado offloaded em outro arquivo (CHANGELOG → SETUP-HISTORICO; DECISOES → docs/adr).

Resumir só é seguro com **ponteiro**: cada linha resumida referencia onde está o detalhe. Resumo sem ponteiro é perda; resumo com ponteiro é compressão.

O "como/por quê" de uma fase tem três destinos por tipo: **decisão de arquitetura** → ADR; **narrativa de implementação** (desvios, soluções não-óbvias) → bloco de notas anexado à fase no SETUP-HISTORICO; **o diff literal** → git. As regras mecânicas de migração (quando mover o quê pra onde) estão em `AGENTS.md`.

---

## Estrutura

```
AGENTS.md                  instruções do agente (núcleo agnóstico) — use como está
CLAUDE.md                  flavor Claude Code → aponta pro AGENTS.md
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
└─ history/                arquivado (imutável)
   ├─ SETUP-HISTORICO.md   specs concluídas + notas de implementação
   └─ DEBITO-RESOLVIDO.md  débito fechado, com nota de resolução

templates/                 scaffolding reutilizável
├─ project-instructions.md COLE nas instruções do projeto no chat (lado raciocínio)
└─ spec-fase.md            formato de uma spec de fase (SUBA nos files do projeto)

examples/                  PREENCHIDO — leia pra ver o método rodando
├─ docs/                   espelho de docs/ com o projeto-brinquedo "Recados"
├─ CONVENCOES.md           exemplo de convenções (stack TypeScript)
└─ perfil-llm-agente.md    add-on opcional pra projetos de LLM/agentes (ver abaixo)
```

Os arquivos em `docs/` e o `CONVENCOES.md` vêm **vazios** (só estrutura + comentário).
Os de `examples/` vêm **preenchidos** com um projeto-brinquedo coerente ("Recados", uma API de notas) pra você ver como cada doc fica em uso e como as migrações acontecem.

---

## Como começar

1. **Use este repo como template** no GitHub (botão *Use this template*) ou clone e
  `rm -rf .git && git init`.
2. **Leia `examples/`** uma vez pra entender o método em uso.
3. **Configure o lado do chat** (o chat não acessa o repo — o contexto entra por dois canais):
  - **Instruções do projeto:** copie o conteúdo de `templates/project-instructions.md` para as instruções do seu projeto no chat (claude.ai: Projects → instruções). Ajuste nome e stack.
  - **Files do projeto:** suba o `templates/spec-fase.md` nos files do projeto. É o formato de spec — estável, lido por todos os chats. (Os docs vivos **não** vão aqui; você os cola no chat a cada fase, porque mudam.)
4. **Configure o lado do agente:** o `AGENTS.md` (e o `CLAUDE.md`, se usar Claude Code) já está pronto — use como está. Ajuste só a seção de stack/comandos.
5. **Preencha o** `CONVENCOES.md` com os padrões de código/UI do seu projeto (use `examples/CONVENCOES.md` como molde). Se não tiver convenções fortes ainda, deixe  mínimo e cresça depois.
6. **Escreva sua primeira fase:** preencha `docs/ROADMAP.md` com as fases, e deixe o chat emitir a spec da primeira em `docs/SETUP.md`.
7. **Rode o loop:** chat emite spec → você passa pro agente → agente implementa e atualiza os vivos → você **cola os vivos atualizados no chat** → repete.
8. **(Opcional) apague `examples/`** quando não precisar mais da referência.

### Exemplo: as primeiras interações

O loop tem dois lados, então você digita em dois lugares. Abaixo, uma sequência real de arranque (ajuste os ‹trechos›).

**1) No chat — definir o ROADMAP e a primeira spec.** Não há docs vivos ainda; você começa descrevendo o projeto:

```
Estou começando um projeto novo e já configurei este Project (instruções + spec-fase nos files).

Projeto: ‹uma API self-hosted pra gerenciar meus links salvos›.
Stack: ‹Bun + Hono + SQLite›.

Primeiro vamos definir o ROADMAP: me proponha as fases de um MVP enxuto (YAGNI), uma linha cada. Quando eu aprovar, emita a spec só da primeira fase, no formato do spec-fase.
```

**2) Pro agente de código — executar a primeira fase.** Você pega a spec que o chat emitiu e entrega ao agente (no primeiro arranque, você cola a spec; o agente a grava no SETUP e executa):

```
A spec da primeira fase está abaixo. Coloque em docs/SETUP.md e execute seguindo o AGENTS.md (e CLAUDE.md). Ao terminar, atualize os docs vivos e pare pra eu aprovar.

‹cola aqui a spec que o chat emitiu›
```

**3) De volta ao chat — fechar o loop.** O agente atualizou os vivos; você os reenvia pro chat conferir se o resultado bateu com a intenção:

```
Fase concluída. Seguem os docs vivos atualizados (em anexo). Confere se bateu com a intenção e, se sim, emite a spec da próxima fase.
```

**Daí em diante**, o arranque de cada fase no agente é curto — o contexto está nos docs, não no prompt:

```
Leia e execute a fase atual do docs/SETUP.md.
```

---

## Add-on opcional: projetos de LLM / agentes

**O que é.** Um perfil de princípios extras pra quem **constrói** software com LLM — orquestração de agentes, integração com modelos, custo de inferência. Fica em `examples/perfil-llm-agente.md`.

**Por que está separado do núcleo.** O `AGENTS.md` é agnóstico de domínio: não assume que você usa IA. Regras como "toda chamada de LLM grava tokens e custo" são valiosas num projeto de IA e puro ruído num site estático ou numa CLI. Por isso o perfil é opt-in, não default.

**Atenção — este é o único arquivo de** `examples/` **feito pra copiar e manter.** O resto de `examples/` é referência pra ler e (se quiser) apagar. Este você tira de lá e incorpora ao seu repo. Pra acoplar:

1. Copie `examples/perfil-llm-agente.md` pra raiz do seu repo, com um nome próprio — ex.: `PERFIL-LLM.md`.
2. Abra seu `AGENTS.md` e adicione uma linha apontando pra ele, na lista do topo: *"Projeto de LLM/agentes — veja também `PERFIL-LLM.md`."* (já há um lembrete lá).
3. (lado chat) Se as conversas vão discutir arquitetura de agente, suba o arquivo também nos **files do projeto** — é conteúdo estável, igual o `CONVENCOES.md` e o `spec-fase`.

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
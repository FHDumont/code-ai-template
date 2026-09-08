# CHANGELOG

> Ledger append-only. **1 linha por fase entregue:** `F-xxx — o que entrou — AAAA-MM-DD`.
> O detalhe cheio da fase vive em `docs/history/SETUP-HISTORICO.md` (o ponteiro é o ID).
> Frio: consulte sob demanda, não pré-carregue.
> Escape hatch (YAGNI, só se o scan incomodar): secione por marco/ano dentro deste mesmo arquivo. Não criar `history` pra changelog — o ledger é a trilha.
> Veja `examples/docs/CHANGELOG.md` pra um exemplo preenchido.

- **F-metodo-v2** — `AGENTS.md` comprimido pelos princípios de writing-for-agents; `CONTEXT.md` de linguagem ubíqua (+ exemplo) e status `rejeitado` de ADR; rituais do loop como skills (`planejar-fase`, `fechar-fase`, `verificar-referencia`, `grilling`); hook que bloqueia git destrutivo e commit no `main`; `mattpocock/skills` registrado como referência vigiada — 2026-08-11
- **F-metodo-v3** — ADR vira exceção: teste "ADR ou regra?", regra de comportamento `R-NNN` em `docs/reference/` como quarto destino, emenda por rodapé (`## Emendas`) e `DECISOES.md` secionado por assunto; histórico fatiado em `docs/history/fases/<ID>.md` com `SETUP-HISTORICO.md` como índice (`scripts/split-historico.py`); `CONTEXT.md` quente (1 linha por termo) + `docs/reference/dominio.md` frio; spec com teto de 4 KB e sem a árvore do grilling; `grilling` proporcional ao tamanho da fase (passo zero, grep antes de perguntar, rodada ≥3 justificada, sem confirmação separada); fecho sem gate; regras de método que só viviam na memória do agente (teste falha no antigo, segunda revisão de fecho, commit por caminho, ID pelo maior, tela mostrada na execução, perf medida não é débito). Origem: releitura de 342 ADRs em 250 fases do Vaulty (F-261) — 2026-09-08


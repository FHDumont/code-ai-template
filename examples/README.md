# examples/

Conteúdo **preenchido** pra você ver o método rodando antes de começar o seu.

## `docs/` — espelho dos docs vivos

Projeto-brinquedo "Recados" (uma API de notas self-hosted). Leia nesta ordem pra acompanhar a história:

1. `docs/CHANGELOG.md` + `docs/history/SETUP-HISTORICO.md` — duas fases já entregues (F-base, F-auth), cada uma com a spec **e** o bloco "Notas de implementação" (repare em como ele guarda o desvio da spec sem repetir o que o git já tem).
2. `docs/ROADMAP.md` + `docs/SETUP.md` — a fase atual (F-tags) e o que vem depois.
3. `docs/DECISOES.md` + `docs/adr/ADR-001.md` — o índice de decisão e o ADR cheio por trás.
4. `docs/DEBITO-TECNICO.md` + `docs/history/DEBITO-RESOLVIDO.md` — um débito aberto, um resolvido. Note o D-validacao: saiu inteiro do ativo pro resolvido quando F-auth o fechou, sem deixar rastro no vivo.

Repare em como cada doc vivo fica curto e o detalhe mora atrás de um ponteiro (o ID da fase, o ID do ADR). Esse é o ponto todo.

## `CONVENCOES.md` — exemplo de convenções

Padrões de código/UI preenchidos pra um stack TypeScript. Mostra a forma; o conteúdo é por-projeto. Use como molde pro `CONVENCOES.md` da raiz.

## `perfil-llm-agente.md` — add-on opcional

Perfil de princípios pra projetos de LLM/agentes (cost-aware, observability, eval, etc.).
Não faz parte do núcleo. Como acoplar: veja o topo do arquivo e a seção no README da raiz.

---

Pode **apagar esta pasta** quando não precisar mais da referência.
# SETUP — histórico

> Specs de fases **concluídas**, na íntegra, com bloco "Notas de implementação". Mais recente no topo.

---

# F-auth — autenticação por token Bearer

## Objetivo

Proteger as rotas de notas com um token, já que a API vai expor dados pessoais.

## Escopo

**Entra:** middleware de auth Bearer; token lido de variável de ambiente; todas as rotas de notas protegidas. **NÃO entra:** múltiplos usuários, refresh de token, rate limiting.

## Passos

1. Middleware que valida `Authorization: Bearer <token>` contra `MC_TOKEN` do ambiente.
2. Aplicar em todas as rotas `/notas`.
3. Validar inputs do `POST /notas` (resolve D-validacao).

## Critério de pronto

- Requisição sem token válido → 401.
- Inputs do POST validados.
- docs vivos atualizados.

## Notas de implementação

- Desvio da spec: a spec assumia o token numa única var `MC_TOKEN`, mas como o middleware já precisava distinguir ausência de token (401) de token errado (403), separei em validação de presença + comparação. Comportamento externo igual ao pedido.
- Beco evitado: tentei reusar o validador de body do framework pra auth também; acoplava demais. Auth ficou num middleware próprio, validação de body no handler.
- D-validacao saiu junto: a validação de input que faltava entrou aqui de carona, já que o handler estava sendo tocado de qualquer forma.

---

# F-base — bootstrap + API mínima de notas

## Objetivo

Pôr de pé o projeto e a API mínima: criar, listar e ler notas.

## Escopo

**Entra:** bootstrap do projeto; persistência (ver ADR-001); rotas `POST /notas`,
`GET /notas`, `GET /notas/:id`. **NÃO entra:** auth, tags, busca.

## Passos

1. Bootstrap do projeto e do banco (SQLite, ADR-001).
2. Schema da nota: `id`, `body`, `createdAt`.
3. Rotas criar/listar/ler.

## Critério de pronto

- Criar uma nota e recuperá-la por id.
- Listar notas.
- docs vivos criados.

## Notas de implementação

- Sem desvios relevantes. A decisão de persistência virou ADR-001 (SQLite vs Postgres) — o raciocínio está lá, não aqui.
- Registrei D-paginacao: `GET /notas` devolve tudo; aceitável no MVP, vira problema com volume.


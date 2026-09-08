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

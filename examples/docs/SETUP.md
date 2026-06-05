# SETUP — fase atual

> **Exatamente uma** spec por vez: a fase em andamento.

# F-tags — tags nas notas

## Objetivo

Permitir associar tags a uma nota e listar notas por tag, pra organizar conforme o volume cresce.

## Escopo

**Entra:**

- Campo `tags` (lista de strings) na nota, na criação e na leitura.
- Filtro `GET /notas?tag=<x>`.

**NÃO entra (explícito):**

- Renomear/mesclar tags. Autocomplete de tags. (ficam pra depois se fizerem falta)

## Passos

1. Adicionar `tags` ao schema da nota e à migração do banco.
2. Aceitar `tags` no `POST /notas` e devolvê-las no `GET /notas/:id`.
3. Implementar o filtro `?tag=` no `GET /notas`.

> Nomes de arquivo/símbolo: o agente confirma no código (a spec assume `notes.ts` e a migração em `db/`, mas é hipótese).

## Critério de pronto

- Criar nota com tags e recuperá-las.
- `GET /notas?tag=x` retorna só as notas com a tag x.
- docs vivos atualizados (CHANGELOG, ROADMAP).

## Decisões em aberto

- (nenhuma)


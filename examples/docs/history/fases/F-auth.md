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

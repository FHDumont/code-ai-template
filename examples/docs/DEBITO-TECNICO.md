# DÉBITO TÉCNICO

> Só débito **aberto**. Cada item: `D-xxx — descrição em 1 linha — severidade`.
> 🔴 bloqueante | 🟡 importante | 🔵 baixo / aceito como limitação.

- **D-paginacao** — `GET /notas` devolve tudo sem paginação; degrada com volume — 🟡
- **D-rate-limit** — sem rate limiting na auth; aceito como limitação enquanto local-only — 🔵

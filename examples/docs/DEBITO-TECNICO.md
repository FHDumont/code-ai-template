# DÉBITO TÉCNICO

> Só débito **aberto**. Cada item: `D-xxx` + **no máximo 3 frases** — o defeito com `arquivo:linha`, a consequência, e `Correção:` nomeada — + severidade. O porquê histórico mora no ADR ou no `SETUP-HISTORICO`, com ponteiro.
> 🔴 bloqueante | 🟡 importante | 🔵 baixo / aceito como limitação.

- **D-paginacao** — `GET /notas` devolve tudo sem paginação; degrada com volume — 🟡
- **D-rate-limit** — sem rate limiting na auth; aceito como limitação enquanto local-only — 🔵

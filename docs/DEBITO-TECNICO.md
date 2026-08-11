# DÉBITO TÉCNICO

> Só débito **aberto**. Cada item: `D-xxx` + **no máximo 3 frases** — o defeito com `arquivo:linha`, a consequência, e `Correção:` nomeada — + severidade. O porquê histórico mora no ADR ou no `SETUP-HISTORICO`, com ponteiro.
> Severidade sugerida: 🔴 bloqueante | 🟡 importante | 🔵 baixo / aceito como limitação.
> Resolvido → move pra `docs/history/DEBITO-RESOLVIDO.md` com nota de como foi resolvido.
> Nada some em silêncio.
> Veja `examples/docs/DEBITO-TECNICO.md` pra um exemplo preenchido.

<!-- D-xxx — descrição — severidade -->

- **D-001** — `.claude/hooks/block-dangerous-git.sh:50-88` casa os padrões em qualquer ponto da cláusula, então um comando que apenas **contém** o literal (script que testa o guardrail, `echo` que o documenta) é barrado sem executar git nenhum. Na prática obriga a contornar — escrever o script por outra ferramenta ou quebrar a string — toda vez que se testa ou documenta o hook. `Correção:` casar o padrão só no **início** da cláusula (o comando efetivo), em vez de em qualquer posição. — 🔵 baixo

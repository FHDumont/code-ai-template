# DÉBITO RESOLVIDO

> Débito **fechado**, com nota de como/quando foi resolvido. Append quando um item sai de `docs/DEBITO-TECNICO.md`. Imutável.
> Veja `examples/docs/history/DEBITO-RESOLVIDO.md` pra um exemplo preenchido.

**D-001** — O guardrail de git casava os padrões em **qualquer ponto da cláusula**, então um comando que apenas *contém* o literal (o script que testa o hook, o `echo` que o documenta) era barrado sem executar git nenhum. **Resolvido:** `has_subcmd` ancora no **início** da cláusula (`^git…`), e tolera as opções globais que mudam o alvo sem mudar o comando (`git -C <dir>`, `git -c <k=v>`) — sem isso a âncora abriria um buraco pior do que fechou: `git -C /tmp/repo push --force` escapava inteiro. Nasce `.claude/hooks/block-dangerous-git.test.sh`, que o hook não tinha: a suíte falha em 4 casos contra a versão antiga e passa na nova (o vermelho foi provado com execução real, não por leitura). A ausência dessa rede é o que deixou o débito vivo desde o começo.

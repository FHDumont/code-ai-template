---
name: integrar-fase
description: Integra a fase no main, uma por vez — trava, rebase, conflito trivial de ledger, fragmento, validação, PR e o merge pelo fecho comum. Chamada pelo fechar-fase. Para em conflito de lógica, validação ou checks vermelhos.
---

Runbook da integração (ADR-002). As regras estão em `docs/reference/integracao.md` (R-004) e no `AGENTS.md` §Git. O script é quem faz; esta skill é a ordem e o que fazer com cada saída. **Não reimplemente o rebase na mão nem abra o PR antes.** Push forçado na mão continua barrado pelo hook — a rota é o script, e o `--force-with-lease` dele só vale em `fase/*` depois do rebase.

Rode depois dos critérios, da revisão de fecho e do commit de docs: do worktree da fase (paralela, `../<repo>-fases/<id>`) ou deste checkout na branch da fase (solitária). Na paralela a sessão está no checkout principal e entra no worktree por caminho, num subshell — o shell dela não fica na pasta que a integração apaga:

```bash
(cd ../<repo>-fases/F-xxx && scripts/integrar-fase.sh --id F-xxx --issue N --titulo "F-xxx — título" --corpo <arquivo com o corpo do PR>)
```

O corpo é o texto do PR (o que/por quê, os critérios, a referência à `F-xxx`), usado só se o PR ainda não existe; sem `--corpo`, o script abre um corpo curto que aponta `docs/history/fases/<id>.md`. `--issue` é a issue que o merge fecha. O merge é do fecho comum, `scripts/fechar-pr.sh` (ADR-003), que o script chama do checkout principal.

## Saídas — falha para, não pede licença pra desistir

- **0** — integrou: PR `MERGED`, trava solta, worktree e branch local da fase fora, `main` local em dia, e o `scripts/conferir-fecho.sh` que o script roda no fim, do checkout principal, deu `ok`.
- **3** — outra integração está com a trava. Não force: espere e rode de novo. Não é conflito do seu código.
- **4** — conflito de lógica, rebase parado (o stderr lista os arquivos). Mostre ao dono; não invente resolução. Com a decisão dele aplicada e os arquivos no índice, `--continuar`. Se ele desistir, `--abortar` (desfaz o rebase e solta a trava).
- **5** — `scripts/validar.sh` falhou, ou o PR não integrou no `fechar-pr.sh` (checks vermelhos). Volte pro código, corrija, commit, `--continuar`. A trava continua desta fase. Não faça merge.
- **6** — fragmento sem linha de changelog. Preencha `## changelog` em `docs/changes/<id>.md`, commit, `--continuar`.
- **1** — uso, branch ou git. Com `SETUP.md` ainda titulado `# F-`, o fecho não esvaziou a spec: devolva o do `origin/main` (`git show origin/main:docs/SETUP.md`), commit, `--continuar`. Com "integrada: … com pendência" ou "o conferir-fecho.sh acusou pendência" (as linhas `pendente: …` acima dela), o merge entrou e a trava já soltou: resolva o que o stderr diz (o worktree que não saiu, o `main` local que não andou por fast-forward por mudança sem commit no checkout principal) e confira — **não** rode `--continuar`.

Se o `integrar-fase.sh` da branch difere do `origin/main`, ele roda sozinho a versão do main, de uma cópia: a correção do script vale já pra fase cortada antes dela. Não apague `refs/integracao/lock` na mão. Trava alheia não se solta; `--abortar` só solta a desta fase, e roda também do checkout principal quando a branch já sumiu. O `main` só anda por este merge.

**Termine com a placa de estado** (`AGENTS.md` §Placa de estado): saída 0 e `conferir-fecho.sh` em `ok` → `**Estado:** integrada — PR #N` e `**Próximo:** gerenciador — arquivar esta sessão` (solitária: `ninguém`). Saída diferente de 0 → `bloqueada (<motivo>)` e quem destrava.

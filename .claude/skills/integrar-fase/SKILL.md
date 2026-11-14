---
name: integrar-fase
description: Integra a fase no main, uma por vez — rebase, conflito trivial, validação e só então o merge. Chamada pelo fechar-fase. Para em conflito de lógica ou validação que falha.
disable-model-invocation: true
---

Runbook da integração. As regras estão em `docs/reference/integracao.md` (R-004) e no `AGENTS.md` §Git. O script é quem faz; esta skill é a ordem e o que fazer com cada saída. **Não reimplemente o rebase na mão.** Force-push na mão continua barrado pelo hook — a rota é o script, e o `--force-with-lease` dele só vale em `fase/*`.

Rode a partir do worktree da fase (branch `fase/<id>-<slug>`), depois dos critérios, da revisão de fecho e do commit de docs.

```bash
scripts/integrar-fase.sh --id F-xxx --titulo "F-xxx — título" --corpo docs/history/fases/F-xxx.md
```

O corpo é o texto do PR, se o PR ainda não existir. Sem `--corpo`, o script abre um corpo curto. Não abra o PR antes: o script rebaseia primeiro e o PR nasce no commit que vai integrar.

## Saídas — falha para, não pede licença pra desistir

- **0** — integrou. No checkout da `main`: `git pull`. Se o worktree da fase ainda existir, a partir da `main`: `git worktree remove <caminho>`. Fase solitária que usava o checkout principal: `git switch main && git pull`, como antes.
- **3** — outra integração está com a trava. Não force. Espere e rode de novo. Não é conflito do seu código.
- **4** — conflito de lógica, rebase parado. Mostre ao dono os arquivos do stderr. Não invente resolução. Com a decisão dele aplicada e os arquivos no índice, `scripts/integrar-fase.sh --id F-xxx --continuar`. Se ele desistir, `--abortar` (desfaz o rebase e solta a trava).
- **5** — validação falhou. Volte pro código, corrija, commit, `--continuar`. A trava continua desta fase. Não faça merge.
- **6** — fragmento sem linha de changelog. Preencha `## changelog` em `docs/changes/<id>.md`, commit, `--continuar`.
- **1** com `SETUP.md` ainda titulado `# F-` — o fecho não esvaziou a spec. Devolva o template (`git show origin/main:docs/SETUP.md`), commit, `--continuar`.

Não apague `refs/integracao/lock` na mão. Trava alheia não se solta. `--abortar` só solta a trava desta fase.

`main` só anda por este merge. O workflow `.github/workflows/validar.yml` roda `scripts/validar.sh` e não integra.

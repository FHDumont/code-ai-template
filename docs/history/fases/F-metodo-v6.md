# F-metodo-v6 — Fases paralelas com integração serial

## Objetivo

Permitir planejar e executar várias fases ao mesmo tempo quando elas não se tocam, e entrar no `main` uma por vez, com conflito de lógica parado para o dono. A fase solitária — nada em execução, um corte só — continua o loop de hoje.

## O que entrou

- **ADR-002** — solitária inalterada; paralela com branch, worktree, registro e fragmento; integração serial. Emenda na ADR-001: os scripts do canal saem desta fase e vão para a F-metodo-v7. O contrato v1 não muda.
- **Regras R-001 a R-006** em `docs/reference/integracao.md`: modo, registro, fragmento, conflito trivial e trava, fila, canal com fases paralelas.
- **Scripts** `scripts/fases-ativas.sh`, `scripts/abrir-fase.sh`, `scripts/enfileirar.sh`, `scripts/integrar-fase.sh` e `scripts/validar.sh`. Testes no mesmo diretório, contra repo temporário. O workflow `.github/workflows/validar.yml` roda a validação e não mergeia.
- **Skills** `planejar-fase` (corta solitária, paralela ou fila), `fechar-fase` (fragmento na paralela; o merge sai daqui) e `integrar-fase`. `grilling` grava N specs quando o corte é paralelo.
- **Hook** de git: o bloqueio de push forçado aponta `scripts/integrar-fase.sh` como a única rota de `--force-with-lease`, e só em `fase/*`.
- **Ponteiros** em `AGENTS.md`, `CLAUDE.md`, `.cursor/rules/metodo.mdc`, `README.md`, `templates/spec-fase.md` e `docs/reference/canal.md`.

## Notas de implementação

- **Por que não um `docs/fases-ativas.md`.** O arquivo que todo mundo edita é o conflito. Um `F-xxx.md` por branch não se encontra no merge. A descoberta varre worktree e `fase/*`. Fase solitária sem esse arquivo reivindica o repo inteiro — assim o caso "nada muda" não precisa publicar registro, e a fase seguinte não abre em cima no escuro.
- **Fragmento só na paralela.** Na solitária os ledgers continuam editados na branch. O resolver de rebase cobre o caso em que duas solitárias mesmo assim se encontram no `CHANGELOG`: junta linha nova e recusa linha reescrita que não é da fase. Menção `depende de F-xxx` não autoriza apagar a linha de outra.
- **Bash e escopo dinâmico.** `local arquivos` no caller fazia `arquivos+=` do `registrar` escrever no local, não no array. Os arrays do `fases-ativas.sh` têm prefixo `fase_`.
- **Rebase e branch.** No meio do rebase `git branch --show-current` vem vazio. O script lê `rebase-merge/head-name` para `--continuar` e `--abortar`.
- **Trava.** `refs/integracao/lock` é um commit de árvore vazia. A mesma fase reentra; outra recebe exit 3. Não há roubo automático de trava velha.
- **O teste novo não tinha código antigo para ficar vermelho.** O comportamento nasce com o script. O que está provado, em repo temporário: duas fases entram uma depois da outra com os dois changelogs e sem merge commit; arquivo compartilhado sai 4 e o `main` não anda; trava alheia sai 3; validação que falha sai 5; `depende de` id ausente do changelog sai 2; diretório com barra cobre o filho e arquivo sem barra não cobre.
- **Renumeração.** A linha que era F-metodo-v6 no ROADMAP (scripts do canal) passou a F-metodo-v7. Não virou débito: é a fase seguinte, e o "não entra" não vai para `DEBITO-TECNICO.md`. O corpo da ADR-001 continua citando v6; a emenda é que corrige.

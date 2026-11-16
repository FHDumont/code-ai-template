#!/usr/bin/env bash
# Testa o `conferir-fecho.sh` : ok depois do fecho e cada pendência reprovada. Imprime `ok`.
set -euo pipefail
aqui=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=fecho-teste-comum.sh
. "$aqui/fecho-teste-comum.sh"

cenario
no_repo bash "$aqui/fechar-pr.sh" 7 --issue 9 > /dev/null
[ "$(no_repo bash "$aqui/conferir-fecho.sh" 7 --issue 9)" = ok ] || erro "conferir não deu ok depois do fecho"

# O conferir reprova cada pendência (com saída ≠ 0 e a linha certa).
reprova() { # <descrição> <trecho esperado> — o cenário já montado
  local saida rc=0
  saida=$(no_repo bash "$aqui/conferir-fecho.sh" 7 --issue 9) || rc=$?
  [ "$rc" != 0 ] || erro "conferir passou com $1"
  printf '%s' "$saida" | grep -q "pendente: .*$2" || erro "conferir não apontou $1 (saída: $saida)"
}
cenario; reprova "o PR aberto" "não MERGED"
cenario; no_repo bash "$aqui/fechar-pr.sh" 7 --issue 9 > /dev/null
no_repo git push -q origin main:fase/x; reprova "o branch na remota" "fase/x ainda existe na remota"
cenario; no_repo bash "$aqui/fechar-pr.sh" 7 --issue 9 > /dev/null
no_repo git branch -q sobra; reprova "o branch local que sobrou" "mais que o main: sobra"
cenario; no_repo bash "$aqui/fechar-pr.sh" 7 --issue 9 > /dev/null
(cd "$base/c" && git clone -q origin.git outro 2> /dev/null && cd outro && git commit -q --allow-empty -m depois && git push -q origin main)
no_repo git fetch -q origin; reprova "o main atrás" "main local difere"
cenario; no_repo bash "$aqui/fechar-pr.sh" 7 > /dev/null; reprova "a issue aberta" "issue #9 está OPEN"
cenario; no_repo bash "$aqui/fechar-pr.sh" 7 --issue 9 > /dev/null
no_repo git worktree add -q --detach "$FECHO_WT_TRILHA" main; reprova "o worktree da trilha" "sobrou o worktree"
# Sem a variável, o worktree de trilha não se olha.
[ "$(FECHO_WT_TRILHA='' no_repo bash "$aqui/conferir-fecho.sh" 7 --issue 9)" = ok ] || erro "conferir olhou o worktree de trilha sem FECHO_WT_TRILHA"

# Fase paralela em curso (branch `fase/*` com registro) não é sobra; outro branch é.
cenario; no_repo bash "$aqui/fechar-pr.sh" 7 --issue 9 > /dev/null
no_repo git worktree add -q -b fase/y "$base/c/wt-y" main
mkdir -p "$base/c/wt-y/docs/fases-ativas"; echo 'id: F-200' > "$base/c/wt-y/docs/fases-ativas/F-200.md"
(cd "$base/c/wt-y" && git add -- docs/fases-ativas/F-200.md && git commit -q -m "docs: abre F-200")
[ "$(no_repo bash "$aqui/conferir-fecho.sh" 7 --issue 9)" = ok ] || erro "conferir cobrou a fase/y com registro"
no_repo git branch -q fase/w; reprova "a fase/* sem registro" "mais que o main: fase/w"
cenario; no_repo bash "$aqui/fechar-pr.sh" 7 --issue 9 > /dev/null
no_repo git branch -q fix/z; reprova "o fix/z" "mais que o main: fix/z"

[ "$falhou" = 0 ] && echo ok
exit "$falhou"

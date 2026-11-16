#!/usr/bin/env bash
# Confere o fecho de um PR (ADR-003, Amplug F-091), depois do `fechar-pr.sh`: `conferir-fecho.sh <pr> [--issue N]`.
# Cobra o PR `MERGED`, o branch dele fora da remota e da local, `git branch` só com `main` (mais as `fase/*`
# que têm registro de fase ativa, `docs/fases-ativas/F-*.md`: as paralelas em curso), o `main` igual ao
# `origin/main` e a issue fechada. Projeto com trilha fora do ciclo que trabalha num worktree próprio aponta
# `FECHO_WT_TRILHA` pra ele: o worktree (ou a pasta) que sobrou também é pendência; sem a variável, não se olha.
# Tudo certo: imprime `ok` e sai 0. Senão, uma linha `pendente: …` por pendência e sai 1 — quem chama (a skill,
# o disparador) relata isso como falha, nunca como sucesso.
set -uo pipefail

uso() { echo "uso: conferir-fecho.sh <pr> [--issue N]" >&2; exit 2; }
pr=${1:-}
case "$pr" in '' | *[!0-9]*) uso ;; esac
shift
issue=
while [ $# -gt 0 ]; do
  case "$1" in
    --issue) issue=${2:-}; case "$issue" in '' | *[!0-9]*) uso ;; esac; shift 2 ;;
    *) uso ;;
  esac
done

pendencias=()
pendente() { pendencias+=("$1"); }

wt=${FECHO_WT_TRILHA:-}

git fetch -q --prune origin 2> /dev/null || pendente "git fetch --prune falhou"

if dados=$(gh pr view "$pr" --json state,headRefName -q '.state + " " + .headRefName' 2> /dev/null); then
  estado=${dados%% *}; branch=${dados#* }
  [ "$estado" = MERGED ] || pendente "PR #$pr está $estado, não MERGED"
  if [ -n "$branch" ] && [ "$branch" != main ]; then
    if [ -n "$(git ls-remote --heads origin "refs/heads/$branch" 2> /dev/null)" ]; then pendente "o branch $branch ainda existe na remota"; fi
    if git show-ref --verify -q "refs/heads/$branch"; then pendente "o branch $branch ainda existe na local"; fi
  fi
else
  pendente "não consegui ler o PR #$pr"
fi

# Branch de fase paralela em curso (com o registro dela) não é sobra; qualquer outra é.
outros=
for b in $(git for-each-ref --format='%(refname:short)' refs/heads | grep -vx main); do
  case "$b" in
    fase/*) git ls-tree -r --name-only "refs/heads/$b" -- docs/fases-ativas 2> /dev/null | grep -q '^docs/fases-ativas/F-.*\.md$' && continue ;;
  esac
  outros="$outros$b "
done
[ -z "$outros" ] || pendente "git branch tem mais que o main: ${outros% }"

if ! git show-ref --verify -q refs/heads/main; then
  pendente "não há main local"
elif [ "$(git rev-parse main)" != "$(git rev-parse origin/main 2> /dev/null)" ]; then
  pendente "o main local difere do origin/main"
fi

if [ -n "$issue" ]; then
  ei=$(gh issue view "$issue" --json state -q .state 2> /dev/null || echo "?")
  [ "$ei" = CLOSED ] || pendente "a issue #$issue está ${ei}, não CLOSED"
fi

if [ -n "$wt" ]; then
  wt_real=$(cd "$wt" 2> /dev/null && pwd -P || echo "$wt")
  if git worktree list --porcelain | grep -qxF "worktree $wt_real"; then
    pendente "sobrou o worktree da trilha ($wt)"
  elif [ -d "$wt" ]; then
    pendente "sobrou a pasta do worktree da trilha ($wt)"
  fi
fi

if [ ${#pendencias[@]} -eq 0 ]; then echo ok; exit 0; fi
printf 'pendente: %s\n' "${pendencias[@]}"
exit 1

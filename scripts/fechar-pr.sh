#!/usr/bin/env bash
# O fecho comum (ADR-003, Amplug F-091): a única rota de encerramento de um PR, usada pelo `/integrar-fase`
# e pela skill de trilha fora do ciclo, quando o projeto tem uma. `fechar-pr.sh <pr> [--issue N]`, rodado do
# checkout principal:
#   1. espera os checks do PR (vermelho para aqui, sem merge);
#   2. com o branch atrás do `main` (o `main` protegido exige o PR em dia), `gh pr update-branch --rebase`
#      e espera o CI de novo;
#   3. integra com `gh pr merge --rebase --delete-branch` (nunca `--admin`, nunca `--merge`/`--squash`);
#   4. fecha a issue, se veio `--issue` e ela ainda está aberta;
#   5. `git fetch --prune` e o `main` local em dia só por fast-forward.
# Quem confere o resultado é o `conferir-fecho.sh`. Sem force push e sem `reset --hard` (AGENTS.md §Git).
set -euo pipefail

uso() { echo "uso: fechar-pr.sh <pr> [--issue N]" >&2; exit 2; }
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

espera=${FECHAR_PR_ESPERA:-20}      # segundos entre consultas
tentativas=${FECHAR_PR_TENTATIVAS:-30} # quantas vezes espera o check aparecer (ou o head mudar)
falhar() { echo "fechar-pr: $1" >&2; exit 1; }

# Espera os checks do PR. `gh pr checks --watch` sai 0 com tudo verde; logo depois de um push o PR pode
# ainda não ter check nenhum ("no checks reported"), e aí se espera ele nascer.
esperar_checks() {
  local n=0 saida rc
  while :; do
    set +e
    saida=$(gh pr checks "$pr" --watch --interval "$espera" 2>&1)
    rc=$?
    set -e
    if [ "$rc" = 0 ]; then echo "checks verdes no PR #$pr"; return 0; fi
    if printf '%s' "$saida" | grep -qi 'no checks reported' && [ "$n" -lt "$tentativas" ]; then
      n=$((n + 1)); sleep "$espera"; continue
    fi
    printf '%s\n' "$saida" >&2
    falhar "checks do PR #$pr não estão verdes"
  done
}

estado=$(gh pr view "$pr" --json state -q .state)
[ "$estado" = OPEN ] || falhar "o PR #$pr está $estado, não OPEN"

# O `mergeStateStatus` sai `UNKNOWN` enquanto o GitHub ainda calcula; espera ele assentar.
estado_merge() {
  local n=0 e
  while :; do
    e=$(gh pr view "$pr" --json mergeStateStatus -q .mergeStateStatus)
    if [ "$e" != UNKNOWN ] || [ "$n" -ge "$tentativas" ]; then echo "$e"; return; fi
    n=$((n + 1)); sleep "$espera"
  done
}

# Atrás do main (o `strict` do main protegido): update-branch --rebase e o CI do head novo.
em_dia() {
  [ "$(estado_merge)" = BEHIND ] || return 0
  local antes n=0
  antes=$(gh pr view "$pr" --json headRefOid -q .headRefOid)
  echo "o PR #$pr está atrás do main: update-branch --rebase"
  gh pr update-branch "$pr" --rebase
  while [ "$(gh pr view "$pr" --json headRefOid -q .headRefOid)" = "$antes" ]; do
    [ "$n" -lt "$tentativas" ] || falhar "o head do PR #$pr não mudou depois do update-branch"
    n=$((n + 1)); sleep "$espera"
  done
  sleep "$espera"   # o CI do head novo nasce alguns segundos depois do push
  esperar_checks
}

esperar_checks
em_dia
# O merge pode recusar um check obrigatório que ainda não tinha nascido (job com `needs`) ou um main que
# andou no meio: espera, põe em dia e tenta de novo, poucas vezes.
n=0
until gh pr merge "$pr" --rebase --delete-branch; do
  # O merge pode ter entrado no GitHub e falhado só na parte local (a troca de branch do --delete-branch).
  if [ "$(gh pr view "$pr" --json state -q .state)" = MERGED ]; then echo "o PR #$pr já está integrado" >&2; break; fi
  n=$((n + 1))
  [ "$n" -le 3 ] || falhar "o merge do PR #$pr recusou 4 vezes"
  echo "o merge recusou; espero os checks e tento de novo ($n/3)" >&2
  sleep "$espera"
  esperar_checks
  em_dia
done
echo "PR #$pr integrado"

if [ -n "$issue" ] && [ "$(gh issue view "$issue" --json state -q .state)" = OPEN ]; then
  gh issue close "$issue" --comment "Integrado pelo PR #$pr."
fi

git fetch --prune origin
if [ "$(git branch --show-current)" = main ]; then
  git merge --ff-only origin/main
elif ! git worktree list --porcelain | grep -qx 'branch refs/heads/main'; then
  git fetch origin main:main   # só fast-forward: o git recusa o que não for
else
  echo "o main está em uso noutro worktree; não sincronizei daqui" >&2
fi
echo "fecho do PR #$pr feito; confira com scripts/conferir-fecho.sh $pr${issue:+ --issue $issue}"

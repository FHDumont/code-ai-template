#!/usr/bin/env bash
# Disparador de uma trilha fora do ciclo (`AGENTS.md` §Trilha fora do ciclo, ADR-003; `docs/reference/canal.md`
# §Trilha): roda a skill da trilha em `claude -p` até o PR fechar, sem ninguém no meio.
#   disparar-trilha.sh --skill <skill> --modelo <id> --effort <nível> [--bot <bot>] <issue>
# Skill, modelo e effort vêm da chamada ou de `TRILHA_SKILL`, `TRILHA_MODELO`, `TRILHA_EFFORT`. **Não há valor
# de fábrica:** falta um deles, o disparo não roda (sai 2 e, com bot, avisa `falha`). O `claude` nunca roda no
# padrão da conta nem com `--fallback-model`. O modelo é o id inteiro; o primeiro evento `init` do stream tem de
# trazer o mesmo id, senão `falha`. A primeira linha do log grava modelo e effort.
# A skill grava `$CANAL/issue-<n>/estado.json`: `{"estado":"esperando|pronto|falha", "espera":"<resposta>",
# "pr":N, "motivo":"…"}`. Em `esperando` o disparador chama o `canal-esperar.sh` e dispara de novo (teto de
# `TRILHA_VOLTAS` voltas, 8); `pronto` pede o `pr` e é conferido pelo `conferir-fecho.sh`. Um aviso por disparo,
# só com `--bot`/`TRILHA_BOT`: `fim` (ok|pendente, com as pendências) ou `falha` (o motivo) — nunca o código de
# saída do `claude`. Bloqueio do `claude` (saída ≠ 0 ou sem estado) tenta uma vez de novo na mesma volta.
# Logs em `${TRILHA_LOG_DIR:-$CANAL/issue-<n>/logs}`. Pede `jq`. Sai 0 em `fim ok`; 1 em `pendente` ou `falha`.
set -uo pipefail
aqui=$(cd "$(dirname "$0")" && pwd)
skill=${TRILHA_SKILL:-}; modelo=${TRILHA_MODELO:-}; effort=${TRILHA_EFFORT:-}; bot=${TRILHA_BOT:-}; args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --skill) skill=${2:-}; shift 2 || exit 2 ;;
    --modelo) modelo=${2:-}; shift 2 || exit 2 ;;
    --effort) effort=${2:-}; shift 2 || exit 2 ;;
    --bot) bot=${2:-}; shift 2 || exit 2 ;;
    *) args+=("$1"); shift ;;
  esac
done
set -- "${args[@]+"${args[@]}"}"
uso="uso: disparar-trilha.sh --skill <skill> --modelo <id> --effort <nível> [--bot <bot>] <issue>"
issue=${1:-}
case "$issue" in '' | *[!0-9]*) echo "$uso" >&2; exit 2 ;; esac
avisar=${TRILHA_AVISAR:-$aqui/canal-avisar.sh}; esperar=${TRILHA_ESPERAR:-$aqui/canal-esperar.sh}
conferir=${TRILHA_CONFERIR:-$aqui/conferir-fecho.sh}
voltas=${TRILHA_VOLTAS:-8}
case "$voltas" in '' | *[!0-9]*) voltas=8 ;; esac

falha() { # <motivo> [saída] — o único caminho de falha: um aviso, uma linha no stderr
  echo "trilha #$issue falhou: $1" >&2
  if [ -n "$bot" ]; then "$avisar" --para "$bot" --falha "$issue" "$1" ${log:+--log "$log"} > /dev/null 2>&1 || echo "o aviso de falha não saiu" >&2; fi
  exit "${2:-1}"
}
log=
for v in skill modelo effort; do
  val=${!v}
  [ -n "$val" ] || falha "sem --$v (ou TRILHA_$(echo "$v" | tr '[:lower:]' '[:upper:]')): o disparador não tem valor de fábrica" 2
done
command -v jq > /dev/null 2>&1 || falha "o disparador pede jq" 2

if [ -z "${CANAL_DIR:-}" ]; then
  comum=$(git rev-parse --path-format=absolute --git-common-dir 2> /dev/null) || falha "fora de um repositório git, defina CANAL_DIR" 2
  projeto=$(basename "$(dirname "$comum")")
fi
canal=${CANAL_DIR:-${CANAL_HOME:-$HOME/.canal}/$projeto}
estado_arq="$canal/issue-$issue/estado.json"
logdir=${TRILHA_LOG_DIR:-$canal/issue-$issue/logs}
mkdir -p "$logdir" "$(dirname "$estado_arq")" || falha "não consegui criar $logdir" 2
estado() { jq -r ".$1 // empty" "$estado_arq" 2> /dev/null; }

rodar() { # <volta> — um `claude -p`; 0 se rodou, o modelo conferiu e há estado
  log="$logdir/$(date '+%Y%m%d-%H%M%S')-volta$1.log"
  echo "modelo=$modelo effort=$effort skill=$skill issue=$issue volta=$1" > "$log"
  rm -f "$estado_arq"
  claude -p "/$skill $issue" --model "$modelo" --effort "$effort" --output-format stream-json --verbose >> "$log" 2>&1 || return 1
  usado=$(grep '"subtype":"init"' "$log" | head -n 1 | jq -r '.model // empty' 2> /dev/null)
  [ "$usado" = "$modelo" ] || falha "o claude rodou em '${usado:-nenhum}', não em $modelo"
  [ -f "$estado_arq" ]
}

volta=1
while [ "$volta" -le "$voltas" ]; do
  rodar "$volta" || rodar "$volta" || falha "o claude não deixou estado.json (volta $volta, depois de repetir)"
  case "$(estado estado)" in
    falha) falha "$(estado motivo)" ;;
    esperando)
      resp=$(estado espera); [ -n "$resp" ] || falha "estado esperando sem o campo espera"
      "$esperar" "$resp" > /dev/null 2>&1 || falha "sem resposta em $resp (espera esgotada)"
      ;;
    pronto)
      pr=$(estado pr); case "$pr" in '' | *[!0-9]*) falha "estado pronto sem o número do pr" ;; esac
      sai=$("$conferir" "$pr" --issue "$issue" 2>&1); rc=$?
      pend=(); while IFS= read -r l; do [ -n "$l" ] && pend+=("${l#pendente: }"); done <<< "$sai"
      if [ "$rc" = 0 ]; then res=ok; pend=(); else res=pendente; [ ${#pend[@]} -gt 0 ] || pend=("conferir-fecho saiu $rc")
      fi
      echo "trilha #$issue: fim $res"
      if [ -n "$bot" ]; then "$avisar" --para "$bot" --fim "$issue" "$res" --log "$log" ${pend[@]+"${pend[@]}"} > /dev/null 2>&1 || echo "o aviso de fim não saiu" >&2; fi
      [ "$res" = ok ]; exit $?
      ;;
    *) falha "estado.json com estado '$(estado estado)' fora de esperando, pronto e falha" ;;
  esac
  volta=$((volta + 1))
done
falha "teto de $voltas voltas sem chegar a pronto"

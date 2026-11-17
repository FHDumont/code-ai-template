#!/usr/bin/env bash
# Espera a resposta de um pedido do canal em shell, sem turno do modelo (`docs/reference/canal.md` §Custo e
# §Trilha): `canal-esperar.sh <unidade>/<bot>/respostas/<nome>.md` (relativo à raiz do canal, ou absoluto dentro
# dela). A resposta só vale com a primeira linha `status:` e estável (o conteúdo igual em duas leituras com
# `CANAL_ESPERA_ESTAVEL` s, padrão 2, de intervalo); o `.tmp` do escritor e arquivo sem `status:` são ignorados.
# Confere de `CANAL_ESPERA_INTERVALO` em `CANAL_ESPERA_INTERVALO` s (120) até `CANAL_ESPERA_TETO` s (14400, 4 h).
# Valeu: imprime o valor do `status:` e sai 0. Estourou o teto: uma linha no stderr e sai 1. Uso errado: 2.
# A raiz do canal é a do `canal-avisar.sh` (`CANAL_DIR` ou `$CANAL_HOME/<projeto>`, projeto = checkout principal).
set -uo pipefail
uso="uso: canal-esperar.sh <unidade>/<bot>/respostas/<nome>.md"
[ $# -eq 1 ] || { echo "$uso" >&2; exit 2; }
if [ -z "${CANAL_DIR:-}" ]; then
  comum=$(git rev-parse --path-format=absolute --git-common-dir 2> /dev/null) || { echo "espera falhou: fora de um repositório git, defina CANAL_DIR" >&2; exit 1; }
  projeto=$(basename "$(dirname "$comum")")
fi
canal=${CANAL_DIR:-${CANAL_HOME:-$HOME/.canal}/$projeto}
rel=${1#"$canal"/}
case "$rel" in /* | ../* | */../* | */./* | ./*) echo "espera falhou: o caminho '$rel' sai da raiz do canal" >&2; exit 2 ;; esac
case "$rel" in */*/respostas/*.md) ;; *) echo "$uso" >&2; exit 2 ;; esac
for v in INTERVALO TETO ESTAVEL; do
  eval "val=\${CANAL_ESPERA_$v:-}"
  case "$val" in *[!0-9]*) echo "espera falhou: CANAL_ESPERA_$v '$val' não é número" >&2; exit 2 ;; esac
done
intervalo=${CANAL_ESPERA_INTERVALO:-120}; teto=${CANAL_ESPERA_TETO:-14400}; estavel=${CANAL_ESPERA_ESTAVEL:-2}
arq="$canal/$rel"

leitura() { # imprime o conteúdo se o arquivo existe e a primeira linha é `status:`
  [ -f "$arq" ] || return 1
  head -n 1 "$arq" | grep -q '^status:' || return 1
  cat "$arq"
}

esperado=0
while :; do
  a=$(leitura) && {
    sleep "$estavel"
    b=$(leitura) && [ "$a" = "$b" ] && {
      v=$(printf '%s\n' "$b" | head -n 1); v=${v#status:}; v=${v#"${v%%[![:space:]]*}"}; v=${v%"${v##*[![:space:]]}"}
      printf '%s\n' "$v"; exit 0
    }
  }
  [ "$esperado" -lt "$teto" ] || { echo "espera falhou: sem resposta estável em $rel depois de ${teto}s" >&2; exit 1; }
  sleep "$intervalo"; esperado=$((esperado + intervalo))
  [ "$intervalo" -gt 0 ] || esperado=$((esperado + 1))
done

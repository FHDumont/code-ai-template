#!/usr/bin/env bash
# Testa o `canal-esperar.sh`: só vale a resposta com `status:` na primeira linha e estável; `.tmp` e arquivo sem
# `status:` são ignorados; a resposta que chega durante a espera é pega; o teto sai com 1 e a mensagem no stderr.
# Imprime `ok`.
set -euo pipefail
aqui=$(cd "$(dirname "$0")" && pwd)
base=$(mktemp -d)
trap 'rm -rf "$base"' EXIT
falhou=0
erro() { echo "FALHOU: $1" >&2; falhou=1; }
export CANAL_DIR="$base/canal" CANAL_ESPERA_INTERVALO=1 CANAL_ESPERA_ESTAVEL=0 CANAL_ESPERA_TETO=2
R=issue-9/marketing/respostas/2026-11-17-1000-roteiro-qa.md
mkdir -p "$CANAL_DIR/issue-9/marketing/respostas"
esperar() { bash "$aqui/canal-esperar.sh" "$@" > "$base/saida" 2> "$base/erro"; }

printf 'status: aprovado\ntask: x\n' > "$CANAL_DIR/$R"
esperar "$R" || erro "a resposta pronta não saiu com 0"
[ "$(cat "$base/saida")" = aprovado ] || erro "valor do status: $(cat "$base/saida")"
esperar "$CANAL_DIR/$R" || erro "o caminho absoluto dentro do canal não valeu"

rm "$CANAL_DIR/$R"
printf 'status: aprovado\n' > "$CANAL_DIR/$R.tmp"
if esperar "$R"; then erro "o .tmp valeu como resposta"; fi
grep -q "sem resposta estável" "$base/erro" || erro "o teto não disse o motivo"

printf 'task: sem status\nstatus: aprovado\n' > "$CANAL_DIR/$R"
if esperar "$R"; then erro "arquivo sem status: na primeira linha valeu"; fi

( sleep 1; printf 'status: pendente\n' > "$CANAL_DIR/$R.tmp"; mv "$CANAL_DIR/$R.tmp" "$CANAL_DIR/$R" ) &
CANAL_ESPERA_TETO=10 esperar "$R" || erro "a resposta que chegou durante a espera não foi pega"
wait
[ "$(cat "$base/saida")" = pendente ] || erro "status da resposta tardia: $(cat "$base/saida")"

rc=0; esperar ../fora.md || rc=$?; [ "$rc" = 2 ] || erro "caminho fora do canal saiu com $rc"
rc=0; esperar "issue-9/marketing/pedidos/x.md" || rc=$?; [ "$rc" = 2 ] || erro "pedido no lugar da resposta saiu com $rc"
rc=0; CANAL_ESPERA_TETO=abc esperar "$R" || rc=$?; [ "$rc" = 2 ] || erro "teto não numérico saiu com $rc"
rc=0; bash "$aqui/canal-esperar.sh" > /dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] || erro "sem argumento saiu com $rc"

[ "$falhou" = 0 ] && echo ok
exit "$falhou"

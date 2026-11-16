#!/usr/bin/env bash
# Testa o `canal-avisar.sh` com um `curl` falso e um canal temporário: o pedido por unidade e bot
# vai como ponteiro no envelope v1, `falha` e `fim` também, e cada trava de custo segura o que o contrato
# manda: resposta não avisa, os pedidos da janela saem num POST só, o `teto_diario` corta (e sem ele não há
# aviso), o pedido já avisado não reenvia, o POST que falhou não o marca. A chave nunca aparece no argv do
# curl, no stdout nem no log. Imprime `ok`.
set -euo pipefail
aqui=$(cd "$(dirname "$0")" && pwd)
base=$(mktemp -d)
trap 'rm -rf "$base"' EXIT
falhou=0
erro() { echo "FALHOU: $1" >&2; falhou=1; }

canal="$base/canal"
mkdir -p "$base/bin" "$canal/issue-261/marketing/pedidos" "$canal/issue-261/marketing/respostas" \
  "$canal/sem-issue/marketing/pedidos" "$canal/F-012/marketing/pedidos" "$canal/segredos"
cat > "$base/bin/curl" << 'EOF'
#!/usr/bin/env bash
# curl falso: guarda os argumentos, a config da entrada padrão e o corpo (um por linha); responde o código
# que `$CURL_LOG.codigo` manda (padrão 200).
printf '%s\n' "$*" >> "$CURL_LOG.args"
cat >> "$CURL_LOG.config"
while [ $# -gt 0 ]; do if [ "$1" = --data ]; then printf '%s\n' "$2" >> "$CURL_LOG.corpos"; fi; shift; done
if [ -f "$CURL_LOG.codigo" ]; then cat "$CURL_LOG.codigo"; else printf 200; fi
EOF
chmod +x "$base/bin/curl"
CHAVE=segredo-de-teste-9f3a
printf 'CANAL_WEBHOOK_URL=https://exemplo.invalid/gancho\nCANAL_WEBHOOK_CHAVE=%s\n' "$CHAVE" > "$canal/segredos/marketing.env"
chmod 600 "$canal/segredos/marketing.env"
export PATH="$base/bin:$PATH" CANAL_DIR="$canal" CANAL_AVISO_INTERVALO=0 CURL_LOG="$base/curl"

bots() { # <teto|-> <janela> — grava o bots.yaml (teto `-` = sem a chave)
  { echo "projeto: teste"; [ "$1" = - ] || echo "teto_diario: $1"; echo "agrupar_segundos: $2"
    printf 'bots:\n  marketing:\n    env: %s/segredos/marketing.env\n    tipos: [qa, arte, duvida]\n    para_que: teste\n    proibido:\n      - chamar o webhook\n' "$canal"
    printf '  infraestrutura:\n    env: %s/segredos/nada.env\n    tipos: [duvida]\n' "$canal"; } > "$canal/bots.yaml"
}
avisar() { bash "$aqui/canal-avisar.sh" "$@" > "$base/saida" 2>&1; }
posts() { if [ -f "$base/curl.corpos" ]; then wc -l < "$base/curl.corpos" | tr -d ' '; else echo 0; fi; }
ultimo() { tail -1 "$base/curl.corpos"; }
pedido() { mkdir -p "$(dirname "$canal/$1")"; touch "$canal/$1"; }

bots 40 0
P1=issue-261/marketing/pedidos/2026-11-12-2000-tema-qa.md
pedido "$P1"

# --- o pedido por unidade e bot: o envelope v1, só ponteiro ---------------------------------------------
avisar "$P1" || erro "o pedido por issue não avisou"
[ "$(ultimo)" = '{"canal":"v1","para":"marketing","avisos":[{"tipo":"qa","pedido":"issue-261/marketing/pedidos/2026-11-12-2000-tema-qa.md","fase":null,"issue":261}]}' ] || erro "corpo do qa: $(ultimo)"
grep -q "$CHAVE" "$base/curl.args" && erro "a chave apareceu na linha de comando do curl"
grep -q "Bearer $CHAVE" "$base/curl.config" || erro "a chave não foi pela config do curl"
grep -rq "$CHAVE" "$base/saida" "$canal/avisos.log" && erro "a chave vazou no stdout ou no avisos.log"
grep -qE ' (-k|--insecure)( |$)' "$base/curl.args" && erro "o curl rodou sem verificar o certificado"

P2=F-012/marketing/pedidos/2026-11-14-1000-prova-duvida.md; pedido "$P2"
avisar "$canal/$P2" || erro "o caminho absoluto dentro do canal não avisou"
[ "$(ultimo)" = '{"canal":"v1","para":"marketing","avisos":[{"tipo":"duvida","pedido":"F-012/marketing/pedidos/2026-11-14-1000-prova-duvida.md","fase":"F-012","issue":null}]}' ] || erro "corpo da fase: $(ultimo)"
P3=sem-issue/marketing/pedidos/2026-11-14-1100-prova-arte.md; pedido "$P3"
avisar --para marketing "$P3" || erro "o pedido sem issue não avisou"
[ "$(ultimo)" = '{"canal":"v1","para":"marketing","avisos":[{"tipo":"arte","pedido":"sem-issue/marketing/pedidos/2026-11-14-1100-prova-arte.md","fase":null,"issue":null}]}' ] || erro "corpo do sem-issue: $(ultimo)"
[ "$(posts)" = 3 ] || erro "esperava 3 POSTs até aqui, houve $(posts)"

# --- trava: resposta não gera aviso ---------------------------------------------------------------------
R=issue-261/marketing/respostas/2026-11-12-2000-tema-qa.md; touch "$canal/$R"
avisar "$R" || erro "o caminho de uma resposta devia sair com 0"
[ "$(posts)" = 3 ] || erro "a resposta gerou POST"
grep -q 'resposta não gera aviso' "$base/saida" || erro "a resposta não disse que não avisa"

# --- trava: pedido já avisado não reenvia ---------------------------------------------------------------
avisar "$P1" || erro "o pedido repetido devia sair com 0"
[ "$(posts)" = 3 ] || erro "o pedido repetido reenviou"
grep -q 'já avisado' "$base/saida" || erro "o pedido repetido não disse que já foi avisado"

# --- formas que reprovam, sem chamar o curl -------------------------------------------------------------
antes=$(posts)
if avisar 2026-11-12-2000-tema-qa.md; then erro "a forma antiga (só o nome) passou"; fi
if avisar pedidos/2026-11-12-2000-tema-qa.md; then erro "pedidos/ na raiz passou"; fi
if avisar 261/pedidos/2026-11-12-2000-tema-qa.md; then erro "a pasta de issue sem bot passou"; fi
if avisar --para infraestrutura "$P1"; then erro "--para diferente do bot do caminho passou"; fi
pedido issue-261/marketing/pedidos/2026-11-12-2100-tema-roteiro.md
if avisar issue-261/marketing/pedidos/2026-11-12-2100-tema-roteiro.md; then erro "tipo fora dos tipos do bot passou"; fi
pedido issue-261/ninguem/pedidos/2026-11-12-2100-tema-qa.md
if avisar issue-261/ninguem/pedidos/2026-11-12-2100-tema-qa.md; then erro "bot fora do bots.yaml passou"; fi
if avisar issue-261/marketing/pedidos/nao-existe-qa.md; then erro "pedido sem arquivo passou"; fi
[ "$(posts)" = "$antes" ] || erro "chamou o curl num pedido reprovado"

# --- falha e fim ----------------------------------------------------------------------------------------
avisar --para marketing --falha 261 "o render reprovou" || erro "a falha não avisou"
[ "$(ultimo)" = '{"canal":"v1","para":"marketing","avisos":[{"tipo":"falha","issue":261,"motivo":"o render reprovou"}]}' ] || erro "corpo da falha: $(ultimo)"
avisar --para marketing --fim 261 ok || erro "o fim ok não avisou"
[ "$(ultimo)" = '{"canal":"v1","para":"marketing","avisos":[{"tipo":"fim","issue":261,"resultado":"ok","pendencias":[]}]}' ] || erro "corpo do fim ok: $(ultimo)"
avisar --para marketing --fim 261 pendente "PR #9 está OPEN, não MERGED" "a issue #261 está OPEN, não CLOSED" || erro "o fim pendente não avisou"
[ "$(ultimo)" = '{"canal":"v1","para":"marketing","avisos":[{"tipo":"fim","issue":261,"resultado":"pendente","pendencias":["PR #9 está OPEN, não MERGED","a issue #261 está OPEN, não CLOSED"]}]}' ] || erro "corpo do fim pendente: $(ultimo)"
avisar --para marketing --fim 261 ok --log out/logs/a.jsonl || erro "o fim com log não avisou"
[ "$(ultimo)" = '{"canal":"v1","para":"marketing","avisos":[{"tipo":"fim","issue":261,"resultado":"ok","pendencias":[],"log":"out/logs/a.jsonl"}]}' ] || erro "corpo do fim com log: $(ultimo)"
avisar --para marketing --falha 261 "timeout" --log out/logs/a.jsonl || erro "a falha com log não avisou"
[ "$(ultimo)" = '{"canal":"v1","para":"marketing","avisos":[{"tipo":"falha","issue":261,"motivo":"timeout","log":"out/logs/a.jsonl"}]}' ] || erro "corpo da falha com log: $(ultimo)"
if avisar --para marketing --fim 261 pendente; then erro "fim pendente sem pendência passou"; fi
if avisar --falha 261 "sem bot"; then erro "falha sem --para passou"; fi

# --- trava: os pedidos da janela saem num POST só -------------------------------------------------------
rm -f "$base/curl.corpos"; rm -rf "$canal/.fila" "$canal/.avisados" "$canal/avisos.log"
bots 40 2
A=issue-262/marketing/pedidos/2026-11-14-1200-a-arte.md; B=issue-262/marketing/pedidos/2026-11-14-1200-b-qa.md
pedido "$A"; pedido "$B"
avisar "$A" &
sleep 0.4
avisar "$B"
wait
[ "$(posts)" = 1 ] || erro "dois pedidos na janela deviam sair num POST, houve $(posts)"
[ "$(jq '.avisos | length' < "$base/curl.corpos")" = 2 ] || erro "o POST do lote devia ter 2 itens: $(ultimo)"
jq -e '.avisos | map(.pedido) | sort == ["issue-262/marketing/pedidos/2026-11-14-1200-a-arte.md","issue-262/marketing/pedidos/2026-11-14-1200-b-qa.md"]' "$base/curl.corpos" > /dev/null || erro "os ponteiros do lote: $(ultimo)"
avisar "$A"; avisar "$B"
[ "$(posts)" = 1 ] || erro "o lote já avisado reenviou"

# --- trava: o teto_diario corta e registra --------------------------------------------------------------
rm -f "$base/curl.corpos"; rm -rf "$canal/.fila" "$canal/.avisados" "$canal/avisos.log"
bots 2 0
for n in 1 2 3; do pedido "issue-263/marketing/pedidos/2026-11-14-130$n-t$n-duvida.md"; done
avisar issue-263/marketing/pedidos/2026-11-14-1301-t1-duvida.md || erro "o 1º pedido sob o teto não avisou"
avisar issue-263/marketing/pedidos/2026-11-14-1302-t2-duvida.md || erro "o 2º pedido sob o teto não avisou"
if avisar issue-263/marketing/pedidos/2026-11-14-1303-t3-duvida.md; then erro "o pedido acima do teto avisou"; fi
[ "$(posts)" = 2 ] || erro "acima do teto não devia haver POST: $(posts)"
grep -q 'CORTE teto_diario=2' "$canal/avisos.log" || erro "o log não registrou o corte"
[ -f "$canal/issue-263/marketing/pedidos/2026-11-14-1303-t3-duvida.md" ] || erro "o pedido cortado sumiu do disco"
if avisar --para marketing --falha 263 "acima do teto"; then erro "a falha acima do teto avisou"; fi
[ "$(posts)" = 2 ] || erro "a falha acima do teto gerou POST"

# --- sem teto_diario não há aviso -----------------------------------------------------------------------
rm -f "$base/curl.corpos"; rm -rf "$canal/.fila" "$canal/.avisados" "$canal/avisos.log"
bots - 0
if avisar issue-263/marketing/pedidos/2026-11-14-1301-t1-duvida.md; then erro "sem teto_diario o aviso saiu"; fi
[ "$(posts)" = 0 ] || erro "sem teto_diario houve POST"
grep -q 'teto_diario' "$base/saida" || erro "sem teto_diario a saída não disse o porquê"

# --- o POST que falha não marca o pedido; o próximo aviso o leva junto ----------------------------------
rm -f "$base/curl.corpos" "$base/curl.args"; rm -rf "$canal/.fila" "$canal/.avisados" "$canal/avisos.log"
bots 40 0
printf 500 > "$base/curl.codigo"
if avisar issue-263/marketing/pedidos/2026-11-14-1301-t1-duvida.md; then erro "o POST com HTTP 500 saiu com 0"; fi
[ "$(wc -l < "$base/curl.args" | tr -d ' ')" = 3 ] || erro "esperava 3 tentativas, houve $(wc -l < "$base/curl.args")"
grep -q FALHOU "$canal/avisos.log" || erro "o log não registrou a falha"
rm -f "$base/curl.codigo" "$base/curl.corpos"
avisar issue-263/marketing/pedidos/2026-11-14-1302-t2-duvida.md || erro "o pedido seguinte não avisou"
[ "$(jq '.avisos | length' < "$base/curl.corpos")" = 2 ] || erro "o pedido que falhou devia ir junto com o seguinte: $(ultimo)"

# --- o líder morto não prende o lote: o próximo chamador assume e leva tudo ---------------------------------
rm -f "$base/curl.corpos"; rm -rf "$canal/.fila" "$canal/.avisados" "$canal/avisos.log"
bots 40 3
L1=issue-264/marketing/pedidos/2026-11-14-1400-l1-duvida.md; L2=issue-264/marketing/pedidos/2026-11-14-1401-l2-duvida.md
pedido "$L1"; pedido "$L2"
bash "$aqui/canal-avisar.sh" "$L1" > /dev/null 2>&1 &
lider=$!
sleep 0.6
kill -9 "$lider" 2> /dev/null || true
wait "$lider" 2> /dev/null || true
bots 40 0
avisar "$L2" || erro "o chamador depois do líder morto não avisou"
[ "$(posts)" = 1 ] || erro "depois do líder morto devia sair 1 POST, houve $(posts)"
[ "$(jq '.avisos | length' < "$base/curl.corpos")" = 2 ] || erro "o pedido do líder morto devia ir junto: $(ultimo)"

# --- a trava velha com o pid reaproveitado (processo vivo) também cai ----------------------------------------
rm -f "$base/curl.corpos"; rm -rf "$canal/.fila" "$canal/.avisados" "$canal/avisos.log"
bots 40 0
mkdir -p "$canal/.fila/marketing.lider"
sleep 30 &
vivo=$!
echo "$vivo" > "$canal/.fila/marketing.lider/pid"; touch -t 202601010000 "$canal/.fila/marketing.lider"
avisar issue-265/marketing/pedidos/2026-11-14-1500-v1-duvida.md 2> /dev/null || true
pedido issue-265/marketing/pedidos/2026-11-14-1500-v1-duvida.md
avisar issue-265/marketing/pedidos/2026-11-14-1500-v1-duvida.md || erro "a trava de 15 min com pid vivo prendeu o aviso"
kill "$vivo" 2> /dev/null; wait "$vivo" 2> /dev/null || true
[ "$(posts)" = 1 ] || erro "a trava velha devia deixar sair 1 POST, houve $(posts)"

# --- a guarda de um chamador morto cai; e a trava morta com chamadores juntos não duplica pedido -------------
rm -f "$base/curl.corpos"; rm -rf "$canal/.fila" "$canal/.avisados" "$canal/avisos.log"
bots 40 0
mkdir -p "$canal/.fila/marketing.lider" "$canal/.fila/marketing.guarda"
echo 99999 > "$canal/.fila/marketing.lider/pid"; touch -t 202601010000 "$canal/.fila/marketing.guarda"
for n in 1 2 3 4 5 6 7 8; do pedido "issue-266/marketing/pedidos/2026-11-14-160$n-g$n-duvida.md"; done
for n in 1 2 3 4 5 6 7 8; do bash "$aqui/canal-avisar.sh" "issue-266/marketing/pedidos/2026-11-14-160$n-g$n-duvida.md" > /dev/null 2>&1 & done
wait
avisar issue-266/marketing/pedidos/2026-11-14-1601-g1-duvida.md || true
repetidos=$(jq -r '.avisos[].pedido' "$base/curl.corpos" | sort | uniq -d | wc -l | tr -d ' ')
[ "$repetidos" = 0 ] || erro "pedido enviado em mais de um POST com a trava morta e chamadores juntos: $(jq -c '[.avisos[].pedido | .[-12:]]' "$base/curl.corpos" | paste -sd' ' -) | log: $(tr '\n' '|' < "$canal/avisos.log")"
[ "$(jq -r '.avisos[].pedido' "$base/curl.corpos" | sort -u | wc -l | tr -d ' ')" = 8 ] || erro "faltou pedido avisado (8 esperados): $(jq -c '.avisos | length' "$base/curl.corpos" | paste -sd, -)"

# --- o POST que nunca saiu (sem env) não gasta o teto ---------------------------------------------------
rm -f "$base/curl.corpos"; rm -rf "$canal/.fila" "$canal/.avisados" "$canal/avisos.log"
bots 2 0
rm -f "$canal/segredos/marketing.env.guardado"; mv "$canal/segredos/marketing.env" "$canal/segredos/marketing.env.guardado"
for n in 1 2 3; do avisar "issue-263/marketing/pedidos/2026-11-14-130$n-t$n-duvida.md" && erro "avisou sem o env"; done
mv "$canal/segredos/marketing.env.guardado" "$canal/segredos/marketing.env"
avisar issue-263/marketing/pedidos/2026-11-14-1301-t1-duvida.md || erro "o teto foi gasto por POST que nunca saiu: $(cat "$base/saida")"
[ "$(posts)" = 1 ] || erro "esperava 1 POST depois de corrigir o env"

# --- o env do bot precisa de permissão 600 --------------------------------------------------------------
rm -f "$base/curl.corpos"; rm -rf "$canal/.fila" "$canal/.avisados"
chmod 644 "$canal/segredos/marketing.env"
if avisar issue-263/marketing/pedidos/2026-11-14-1301-t1-duvida.md; then erro "o env com 644 passou"; fi
[ "$(posts)" = 0 ] || erro "o env com 644 chamou o curl"
chmod 600 "$canal/segredos/marketing.env"

[ "$falhou" = 0 ] && echo ok
exit "$falhou"

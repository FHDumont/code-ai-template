#!/usr/bin/env bash
# Testa o `disparar-trilha.sh` com `claude`, `canal-esperar`, `conferir-fecho` e `canal-avisar` falsos: sem skill,
# modelo ou effort não roda (sai 2, o `claude` não é chamado); modelo diferente no `init` vira `falha`; o
# fluxo esperando → espera → pronto → conferido; teto de voltas; bloqueio tenta uma vez de novo; `fim pendente`
# leva as pendências do conferir; um aviso só por disparo. Imprime `ok`.
set -euo pipefail
aqui=$(cd "$(dirname "$0")" && pwd)
base=$(mktemp -d)
trap 'rm -rf "$base"' EXIT
falhou=0
erro() { echo "FALHOU: $1" >&2; falhou=1; }

export CANAL_DIR="$base/canal" TRILHA_LOG_DIR="$base/logs"
mkdir -p "$base/bin" "$CANAL_DIR"
# claude falso: conta as chamadas, grava os argumentos e escreve o estado da volta (FAKE_ESTADOS, um por linha;
# `-` = não escreve nada); o init traz FAKE_MODELO ou o --model recebido.
cat > "$base/bin/claude" << 'EOF2'
#!/usr/bin/env bash
n=$(( $(cat "$BASE/chamadas" 2> /dev/null || echo 0) + 1 )); echo "$n" > "$BASE/chamadas"
echo "$*" >> "$BASE/claude.args"
modelo=; while [ $# -gt 0 ]; do [ "$1" = --model ] && modelo=$2; shift; done
printf '{"type":"system","subtype":"init","model":"%s"}\n' "${FAKE_MODELO:-$modelo}"
e=$(sed -n "${n}p" "$BASE/estados"); [ -z "$e" ] && e=$(tail -n 1 "$BASE/estados")
[ "$e" = - ] || printf '%s\n' "$e" > "$CANAL_DIR/issue-7/estado.json"
[ "${FAKE_SAIDA:-0}" = 0 ] || exit "$FAKE_SAIDA"
EOF2
chmod +x "$base/bin/claude"
cat > "$base/esperar" << 'EOF2'
#!/usr/bin/env bash
echo "$*" >> "$BASE/esperar.args"; exit "${FAKE_RC_ESPERAR:-0}"
EOF2
cat > "$base/conferir" << 'EOF2'
#!/usr/bin/env bash
echo "$*" >> "$BASE/conferir.args"
if [ "${FAKE_RC_CONFERIR:-0}" != 0 ]; then echo "pendente: o branch fase/x ainda existe na remota"; echo "pendente: a issue 7 continua aberta"; fi
exit "${FAKE_RC_CONFERIR:-0}"
EOF2
cat > "$base/avisar" << 'EOF2'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$BASE/avisar.args"
EOF2
chmod +x "$base/esperar" "$base/conferir" "$base/avisar"
export BASE="$base" PATH="$base/bin:$PATH" TRILHA_ESPERAR="$base/esperar" TRILHA_CONFERIR="$base/conferir" TRILHA_AVISAR="$base/avisar"
unset TRILHA_SKILL TRILHA_MODELO TRILHA_EFFORT TRILHA_BOT TRILHA_VOLTAS
M=modelo-de-teste-1
zerar() { rm -rf "$base/chamadas" "$base"/*.args "$CANAL_DIR/issue-7" "$base/logs"; mkdir -p "$CANAL_DIR/issue-7"; printf '%s\n' "$@" > "$base/estados"; unset FAKE_MODELO FAKE_SAIDA FAKE_RC_ESPERAR FAKE_RC_CONFERIR; }
disparar() { rc=0; bash "$aqui/disparar-trilha.sh" "$@" > "$base/saida" 2>&1 || rc=$?; }
chamadas() { cat "$base/chamadas" 2> /dev/null || echo 0; }

# --- sem skill, modelo ou effort: não roda --------------------------------------------------------------
for faltando in skill modelo effort; do
  zerar '{"estado":"pronto","pr":5}'
  a=(--skill trilha --modelo "$M" --effort medium --bot marketing); i=0; novo=()
  while [ $i -lt ${#a[@]} ]; do if [ "${a[$i]}" = "--$faltando" ]; then i=$((i + 2)); else novo+=("${a[$i]}"); i=$((i + 1)); fi; done
  disparar "${novo[@]}" 7
  [ "$rc" = 2 ] || erro "sem $faltando saiu com $rc, não 2"
  [ "$(chamadas)" = 0 ] || erro "sem $faltando o claude rodou"
  grep -q -- '--falha 7' "$base/avisar.args" || erro "sem $faltando não avisou a falha"
done
zerar '{"estado":"pronto","pr":5}'; TRILHA_MODELO=$M TRILHA_EFFORT=medium TRILHA_SKILL=trilha disparar 7
[ "$rc" = 0 ] || erro "as variáveis TRILHA_* não bastaram (rc $rc): $(cat "$base/saida")"
grep -q -- "--model $M --effort medium" "$base/claude.args" || erro "o claude não recebeu modelo e effort"
grep -q -- '--fallback-model' "$base/claude.args" && erro "o claude rodou com --fallback-model"

# --- o fluxo completo: esperando → espera → pronto → fim ok ---------------------------------------------
zerar '{"estado":"esperando","espera":"issue-7/marketing/respostas/a-qa.md"}' '{"estado":"pronto","pr":42}'
disparar --skill trilha --modelo "$M" --effort medium --bot marketing 7
[ "$rc" = 0 ] || erro "o fluxo ok saiu com $rc: $(cat "$base/saida")"
[ "$(chamadas)" = 2 ] || erro "esperava 2 voltas, houve $(chamadas)"
grep -q 'issue-7/marketing/respostas/a-qa.md' "$base/esperar.args" || erro "não esperou a resposta do estado"
grep -q '^42 --issue 7' "$base/conferir.args" || erro "o conferir não recebeu pr e issue: $(cat "$base/conferir.args")"
[ "$(wc -l < "$base/avisar.args" | tr -d ' ')" = 1 ] || erro "mais de um aviso por disparo"
grep -q -- '--para marketing --fim 7 ok --log ' "$base/avisar.args" || erro "aviso de fim ok: $(cat "$base/avisar.args")"
head -n 1 "$base"/logs/*volta1.log | grep -q "modelo=$M effort=medium" || erro "a primeira linha do log não grava modelo e effort"

# --- fim pendente leva as pendências do conferir ---------------------------------------------------------
zerar '{"estado":"pronto","pr":42}'; export FAKE_RC_CONFERIR=1
disparar --skill trilha --modelo "$M" --effort medium --bot marketing 7
[ "$rc" = 1 ] || erro "fim pendente saiu com $rc"
grep -q -- '--fim 7 pendente' "$base/avisar.args" || erro "aviso de fim pendente: $(cat "$base/avisar.args")"
grep -q 'a issue 7 continua aberta' "$base/avisar.args" || erro "as pendências não foram no aviso"
unset FAKE_RC_CONFERIR

# --- modelo diferente no init: falha ---------------------------------------------------------------------
zerar '{"estado":"pronto","pr":42}'; export FAKE_MODELO=outro-modelo
disparar --skill trilha --modelo "$M" --effort medium --bot marketing 7
[ "$rc" = 1 ] || erro "modelo trocado saiu com $rc"
grep -q -- '--falha 7 o claude rodou em' "$base/avisar.args" || erro "modelo trocado não virou falha: $(cat "$base/avisar.args")"
[ -f "$base/conferir.args" ] && erro "conferiu o fecho com o modelo errado"
unset FAKE_MODELO

# --- estado falha, teto de voltas e bloqueio -------------------------------------------------------------
zerar '{"estado":"falha","motivo":"QA reprovou"}'
disparar --skill trilha --modelo "$M" --effort medium --bot marketing 7
grep -q -- '--falha 7 QA reprovou' "$base/avisar.args" || erro "estado falha não foi avisado: $(cat "$base/avisar.args")"

zerar '{"estado":"esperando","espera":"issue-7/marketing/respostas/a-qa.md"}'
TRILHA_VOLTAS=3 disparar --skill trilha --modelo "$M" --effort medium --bot marketing 7
[ "$(chamadas)" = 3 ] || erro "o teto de 3 voltas deixou rodar $(chamadas)"
grep -q 'teto de 3 voltas' "$base/avisar.args" || erro "o teto não virou falha"

zerar '{"estado":"esperando","espera":"issue-7/marketing/respostas/a-qa.md"}'; export FAKE_RC_ESPERAR=1
disparar --skill trilha --modelo "$M" --effort medium --bot marketing 7
grep -q 'espera esgotada' "$base/avisar.args" || erro "a espera esgotada não virou falha"
unset FAKE_RC_ESPERAR

zerar - '{"estado":"pronto","pr":42}'
disparar --skill trilha --modelo "$M" --effort medium --bot marketing 7
[ "$rc" = 0 ] || erro "o bloqueio não tentou de novo (rc $rc): $(cat "$base/saida")"
[ "$(chamadas)" = 2 ] || erro "o bloqueio devia repetir uma vez, houve $(chamadas)"
zerar -
disparar --skill trilha --modelo "$M" --effort medium --bot marketing 7
[ "$(chamadas)" = 2 ] || erro "o bloqueio repetiu mais de uma vez: $(chamadas)"

# --- sem bot: não avisa ----------------------------------------------------------------------------------
zerar '{"estado":"pronto","pr":42}'
disparar --skill trilha --modelo "$M" --effort medium 7
[ "$rc" = 0 ] || erro "sem bot saiu com $rc"
[ -f "$base/avisar.args" ] && erro "avisou sem bot"
rc=0; bash "$aqui/disparar-trilha.sh" --skill trilha --modelo "$M" --effort medium abc > /dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || erro "issue não numérica saiu com $rc"

[ "$falhou" = 0 ] && echo ok
exit "$falhou"

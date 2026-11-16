#!/usr/bin/env bash
# Avisa um bot do canal pelo webhook da rotina dele (ADR-001; contrato em `docs/reference/canal.md`; portado do
# Amplug F-097). Três formas, todas com o bot por `--para <bot>` (num pedido o bot sai do caminho e `--para`, se
# vier, tem de casar):
#   canal-avisar.sh [--para <bot>] [--tipo <tipo>] <unidade>/<bot>/pedidos/<nome>.md   um pedido novo, logo
#       depois de gravá-lo. A unidade é `F-<id>`, `issue-<n>` ou `sem-issue`. O aviso é só ponteiro:
#       `{"canal":"v1","para":"<bot>","avisos":[{"tipo","pedido","fase","issue"}]}`; o tipo sai do fim do nome
#       (`…-<tipo>.md`) e tem de estar nos `tipos` do bot no `bots.yaml`.
#   canal-avisar.sh --para <bot> --falha <issue> <motivo> [--log <caminho>]   a trilha parou e não segue sozinha.
#   canal-avisar.sh --para <bot> --fim <issue> ok|pendente [--log <caminho>] [pendência…]   o fim da trilha.
# `falha` e `fim` saem só do disparador de uma trilha fora do ciclo (`AGENTS.md` §Trilha fora do ciclo), um por
# disparo, sem agrupar. Projeto sem trilha não usa as duas.
# As travas de custo (o contrato, §Aviso):
#   - resposta não gera aviso (um caminho em `respostas/` sai com 0 sem POST);
#   - pedidos ao mesmo bot dentro de `agrupar_segundos` saem num POST só: o primeiro chamador espera a janela
#     e leva a fila, os outros entram na fila e voltam;
#   - `teto_diario` é o máximo de POSTs do projeto no dia; acima dele não há POST e o `avisos.log` registra o
#     corte (o pedido fica no disco); sem a chave não há aviso;
#   - pedido já avisado (`.avisados`) não reenvia; o POST que falhou não o marca.
# A raiz do canal é `CANAL_DIR` ou `$CANAL_HOME/<projeto>` (`CANAL_HOME`, padrão `~/.canal`; o projeto é o nome
# da pasta do checkout principal). Pede `jq` e `curl`. O `bots.yaml` (awk, sem dependência nova) diz o `env` do bot, os `tipos`, o `teto_diario` e o `agrupar_segundos`. O `env` (fora do
# repo, permissão 600) traz `CANAL_WEBHOOK_URL`, `CANAL_WEBHOOK_CHAVE` e, opcionais, `CANAL_WEBHOOK_CABECALHO`
# (padrão `Authorization`) e `CANAL_WEBHOOK_PREFIXO` (padrão `Bearer `). A chave vai pro curl pela entrada padrão
# (`-K -`), com o endereço: nenhum dos dois aparece na linha de comando, no `ps`, no stdout nem no log. A
# verificação do certificado fica ligada. Falhou: mais 2 tentativas com `CANAL_AVISO_INTERVALO` s (30) de
# intervalo; sem sucesso, registra no `avisos.log` e sai com 1. Uma linha de saída por chamada.
# shellcheck disable=SC2016 # os $ entre aspas simples são do jq e do awk
set -uo pipefail
if [ -z "${CANAL_DIR:-}" ]; then
  # O checkout principal, mesmo quando quem chama está num worktree de fase.
  comum=$(git rev-parse --path-format=absolute --git-common-dir 2> /dev/null) || { echo "aviso falhou: fora de um repositório git, defina CANAL_DIR" >&2; exit 1; }
  projeto=$(basename "$(dirname "$comum")")
fi
canal=${CANAL_DIR:-${CANAL_HOME:-$HOME/.canal}/$projeto}
config="$canal/bots.yaml"
registro="$canal/avisos.log"
rotulo=${1:-}
agora() { date '+%Y-%m-%d %H:%M:%S'; }
falhar() { echo "$(agora) $rotulo: $1" >> "$registro" 2> /dev/null; echo "aviso falhou ($rotulo): $1" >&2; exit 1; }
numero() { case "$1" in '' | *[!0-9]*) return 1 ;; esac; }
permissao() { if stat --version > /dev/null 2>&1; then stat -c %a "$1"; else stat -f %Lp "$1"; fi; }

# --- bots.yaml ---------------------------------------------------------------------------------------------
raiz_val() { # <chave> — escalar da raiz
  awk -v k="$1" '$0 ~ "^" k ":" { sub("^" k ":[ ]*", ""); sub(/[ ]+#.*$/, ""); print; exit }' "$config"
}
bot_val() { # <bot> <chave> — escalar do bot, dentro de `bots:`
  awk -v bot="$1" -v k="$2" '
    /^bots:/ { em = 1; next }
    em && /^[^ #]/ { em = 0 }
    em && $0 ~ "^  " bot ":[ ]*$" { dentro = 1; next }
    em && /^  [^ ]/ { dentro = 0 }
    em && dentro && $0 ~ "^    " k ":" { sub("^    " k ":[ ]*", ""); sub(/[ ]+#.*$/, ""); print; exit }
  ' "$config"
}

# --- os argumentos -----------------------------------------------------------------------------------------
para=; tipo_forcado=; modo=pedido; args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --para) para=${2:-}; shift 2 || { echo "uso: --para <bot>" >&2; exit 2; } ;;
    --tipo) tipo_forcado=${2:-}; shift 2 || { echo "uso: --tipo <tipo>" >&2; exit 2; } ;;
    --falha) modo=falha; shift ;;
    --fim) modo=fim; shift ;;
    *) args+=("$1"); shift ;;
  esac
done
uso="uso: canal-avisar.sh [--para <bot>] <unidade>/<bot>/pedidos/<nome>.md | --para <bot> --falha <issue> <motivo> [--log <caminho>] | --para <bot> --fim <issue> ok|pendente [--log <caminho>] [pendência…]"
set -- "${args[@]+"${args[@]}"}"
[ $# -gt 0 ] || { echo "$uso" >&2; exit 2; }
[ -d "$canal" ] || { echo "aviso falhou: não há a raiz do canal em $canal" >&2; exit 1; }
[ -f "$config" ] || falhar "sem o bots.yaml em $config"

item=; rels=
case "$modo" in
  falha)
    issue=${1:-}; motivo=${2:-}; rotulo="falha #$issue"
    [ -n "$para" ] || falhar "--falha pede --para <bot>"
    numero "$issue" || falhar "issue '$issue' não é número"
    [ -n "$motivo" ] || falhar "sem o motivo"
    log=; if [ "${3:-}" = --log ]; then log=${4:-}; fi
    item=$(jq -cn --argjson i "$issue" --arg m "$motivo" --arg l "$log" '{tipo: "falha", issue: $i, motivo: $m} + (if $l == "" then {} else {log: $l} end)')
    ;;
  fim)
    issue=${1:-}; resultado=${2:-}; rotulo="fim #$issue"
    [ -n "$para" ] || falhar "--fim pede --para <bot>"
    numero "$issue" || falhar "issue '$issue' não é número"
    case "$resultado" in ok | pendente) ;; *) falhar "resultado '$resultado' fora de ok e pendente" ;; esac
    shift 2
    log=; if [ "${1:-}" = --log ]; then log=${2:-}; shift 2; fi
    [ "$resultado" = ok ] || [ $# -gt 0 ] || falhar "fim pendente sem as pendências"
    item=$(jq -cn --argjson i "$issue" --arg r "$resultado" --arg l "$log" '{tipo: "fim", issue: $i, resultado: $r, pendencias: $ARGS.positional} + (if $l == "" then {} else {log: $l} end)' --args "$@")
    ;;
  pedido)
    rel=${1#"$canal"/}
    case "$rel" in /* | ../* | */../* | */./* | ./*) falhar "o caminho '$rel' sai da raiz do canal" ;; esac
    case "$rel" in
      */*/respostas/*.md) echo "resposta não gera aviso: $rel"; exit 0 ;;
    esac
    case "$rel" in
      */*/pedidos/*.md) ;;
      *) falhar "o pedido tem a forma <unidade>/<bot>/pedidos/<nome>.md (unidade: F-<id>, issue-<n> ou sem-issue)" ;;
    esac
    case "$rel" in */*/*/*/*) falhar "o pedido tem a forma <unidade>/<bot>/pedidos/<nome>.md" ;; esac
    unidade=${rel%%/*}; resto=${rel#*/}; bot_do_caminho=${resto%%/*}
    if [ -n "$para" ] && [ "$para" != "$bot_do_caminho" ]; then rotulo=$rel; falhar "--para $para não é o bot do caminho ($bot_do_caminho)"; fi
    para=$bot_do_caminho; rotulo=$rel
    fase=null; issue=null
    case "$unidade" in
      sem-issue) ;;
      issue-*) numero "${unidade#issue-}" || falhar "a unidade '$unidade' não é issue-<n>"; issue=${unidade#issue-} ;;
      F-*) case "$unidade" in *[!A-Za-z0-9-]*) falhar "a unidade '$unidade' tem caractere fora de [A-Za-z0-9-]" ;; esac; fase=$(jq -cn --arg f "$unidade" '$f') ;;
      *) falhar "a unidade '$unidade' não é F-<id>, issue-<n> nem sem-issue" ;;
    esac
    [ -f "$canal/$rel" ] || falhar "não há $rel no canal"
    nome=${rel##*/}; tipo=${nome%.md}; tipo=${tipo##*-}
    if [ -n "$tipo_forcado" ]; then tipo=$tipo_forcado; fi
    tipos=$(bot_val "$para" tipos | tr -d '[]' | tr ',' ' ')
    [ -n "$tipos" ] || falhar "o bot '$para' não está no bots.yaml (ou não tem tipos)"
    case " $tipos " in *" $tipo "*) ;; *) falhar "tipo '$tipo' fora dos tipos de $para ($tipos); o nome termina em -<tipo>.md" ;; esac
    item=$(jq -cn --arg t "$tipo" --arg p "$rel" --argjson f "$fase" --argjson i "$issue" '{tipo: $t, pedido: $p, fase: $f, issue: $i}')
    rels=$rel
    ;;
esac
case "$para" in '' | *[!a-z0-9-]*) falhar "o bot '$para' fora de [a-z0-9-]" ;; esac

# --- as travas e o POST ------------------------------------------------------------------------------------
teto=$(raiz_val teto_diario)
numero "${teto:-}" || falhar "sem teto_diario numérico no bots.yaml: teto ausente não vira ilimitado, e não há aviso"
janela=$(raiz_val agrupar_segundos); janela=${janela:-0}
numero "$janela" || falhar "agrupar_segundos '$janela' não é número"
fila_dir="$canal/.fila"; fila="$fila_dir/$para"; lider="$fila_dir/$para.lider"; avisados="$canal/.avisados"
mkdir -p "$fila_dir"; touch "$avisados"

enviar() { # <bot> <avisos-json> <rotulo-do-log> — teto, POST com 3 tentativas, log; devolve 0, 1 (falhou) ou 4 (teto)
  local bot=$1 avisos=$2 oque=$3 env_bot feitos
  feitos=$(grep -c "^$(date +%F) [0-9:]* POST " "$registro" 2> /dev/null || true)
  if [ "${feitos:-0}" -ge "$teto" ]; then
    echo "$(agora) CORTE teto_diario=$teto $bot $oque" >> "$registro"
    echo "aviso cortado pelo teto_diario ($teto): o pedido fica no disco"
    return 4
  fi
  env_bot=$(bot_val "$bot" env); env_bot=${env_bot/#\~/$HOME}
  [ -n "$env_bot" ] || { echo "$(agora) NAO-ENVIADO $bot $oque SEM-ENV" >> "$registro"; echo "aviso falhou: o bot '$bot' não tem env no bots.yaml (sem webhook: responda em respostas/)" >&2; return 1; }
  [ -f "$env_bot" ] || { echo "$(agora) NAO-ENVIADO $bot $oque SEM-ENV" >> "$registro"; echo "aviso falhou: não há o env do bot '$bot'" >&2; return 1; }
  [ "$(permissao "$env_bot")" = 600 ] || { echo "$(agora) NAO-ENVIADO $bot $oque ENV-SEM-600" >> "$registro"; echo "aviso falhou: o env do bot '$bot' precisa de permissão 600" >&2; return 1; }
  (
    # shellcheck disable=SC1090 # fora do repo, por bot
    . "$env_bot"
    : "${CANAL_WEBHOOK_URL:?}" "${CANAL_WEBHOOK_CHAVE:?}"
    cabecalho=${CANAL_WEBHOOK_CABECALHO:-Authorization}
    prefixo=${CANAL_WEBHOOK_PREFIXO-Bearer }
    corpo=$(jq -cn --arg b "$bot" --argjson a "$avisos" '{canal: "v1", para: $b, avisos: $a}')
    for tentativa in 1 2 3; do
      codigo=$(printf 'url = "%s"\nheader = "%s: %s%s"\n' "$CANAL_WEBHOOK_URL" "$cabecalho" "$prefixo" "$CANAL_WEBHOOK_CHAVE" \
        | curl -sS -o /dev/null -w '%{http_code}' --max-time 20 -K - \
          -H 'Content-Type: application/json' -X POST --data "$corpo" 2> /dev/null)
      case "$codigo" in 2??) echo "$(agora) POST $bot $oque HTTP $codigo" >> "$registro"; exit 0 ;; esac
      echo "aviso: tentativa $tentativa sem sucesso (HTTP ${codigo:-sem resposta})" >&2
      if [ "$tentativa" -lt 3 ]; then sleep "${CANAL_AVISO_INTERVALO:-30}"; fi
    done
    echo "$(agora) POST $bot $oque HTTP ${codigo:-sem resposta} FALHOU em 3 tentativas" >> "$registro"
    exit 1
  )
}

if [ "$modo" != pedido ]; then # falha e fim: um POST, sem fila
  enviar "$para" "[$item]" "$rotulo"; rc=$?
  if [ "$rc" = 0 ]; then echo "$para avisado ($rotulo)"; exit 0; fi
  [ "$rc" = 4 ] || echo "aviso falhou ($rotulo)" >&2
  exit 1
fi

if grep -qxF "$rels" "$avisados" 2> /dev/null; then echo "já avisado: $rels"; exit 0; fi
grep -qF "$rels"$'\t' "$fila" 2> /dev/null || printf '%s\t%s\n' "$rels" "$item" >> "$fila"

# o primeiro chamador é o líder: espera a janela e leva a fila; os outros entram na fila e voltam
# Líder morto (kill, timeout do Bash): a trava com o pid de um processo que não existe mais, com mais de 15 min
# (o pid pode ter sido reaproveitado; o líder vivo a renova a cada volta) ou sem pid há mais de 1 min cai, e este
# chamador vira o líder; senão o lote preso engoliria os avisos. A decisão e a remoção se fazem dentro de uma
# guarda (`mkdir` atômico), pra dois chamadores não derrubarem a trava nova um do outro.
trava_velha() {
  local pid_lider; pid_lider=$(cat "$lider/pid" 2> /dev/null || true)
  [ -d "$lider" ] || return 1
  if [ -n "$(find "$lider" -maxdepth 0 -mmin +15 2> /dev/null)" ]; then return 0; fi
  if [ -n "$pid_lider" ]; then ! kill -0 "$pid_lider" 2> /dev/null; return; fi
  [ -n "$(find "$lider" -maxdepth 0 -mmin +1 2> /dev/null)" ]
}
if [ -d "$lider" ]; then
  if mkdir "$lider.guarda" 2> /dev/null; then
    if trava_velha; then rm -rf "$lider"; fi
    rmdir "$lider.guarda" 2> /dev/null
  elif [ -n "$(find "$lider.guarda" -maxdepth 0 -mmin +1 2> /dev/null)" ]; then
    rmdir "$lider.guarda" 2> /dev/null # a guarda de um chamador morto
  fi
fi
if ! mkdir "$lider" 2> /dev/null; then echo "agrupado no lote em andamento: $rels"; exit 0; fi
echo $$ > "$lider/pid"
solta_lider() { if [ "$(cat "$lider/pid" 2> /dev/null)" = "$$" ]; then rm -rf "$lider"; fi; }
trap solta_lider EXIT
trap 'exit 1' INT TERM

resultado=0
# Cada líder leva a fila pro próprio `$fila.enviando.<pid>` (o `mv` é atômico, então dois líderes, se a trava
# falhar numa corrida rara, levam itens diferentes e nenhum pedido sai em dois POSTs). O lote de um líder morto
# volta pra fila.
for orfao in "$fila".enviando.*; do
  [ -f "$orfao" ] || continue
  kill -0 "${orfao##*.}" 2> /dev/null && continue
  cat "$orfao" >> "$fila"; rm -f "$orfao"
done
lote="$fila.enviando.$$"
levar_fila() {
  while :; do
    touch "$lider" 2> /dev/null # renova a trava: o líder vivo não cai pela idade
    [ "$janela" -gt 0 ] && sleep "$janela"
    mv "$fila" "$lote" 2> /dev/null || break
    todos=$(cut -f1 "$lote" | grep -vxF -f "$avisados" || true)
    if [ -z "$todos" ]; then rm -f "$lote"; break; fi
    avisos=$(cut -f2- "$lote" | jq -cs --arg r "$todos" '($r | split("\n")) as $ok | map(select(.pedido as $p | $ok | index($p)))')
    junto=$(printf '%s' "$todos" | paste -sd, -)
    enviar "$para" "$avisos" "$junto"; rc=$?
    if [ "$rc" = 0 ]; then
      printf '%s\n' "$todos" >> "$avisados"
      echo "$para avisado: $(jq 'length' <<< "$avisos") pedido(s) num POST"
      rm -f "$lote"
    elif [ "$rc" = 4 ]; then
      rm -f "$lote" # cortado pelo teto: o pedido fica no disco; a rotina varre as pastas
      resultado=1
    else
      cat "$lote" >> "$fila" 2> /dev/null; rm -f "$lote" # o POST falhou: os pedidos voltam pra fila, pro próximo aviso
      resultado=1
      break
    fi
    [ -s "$fila" ] || break
  done
}
levar_fila
solta_lider
# Quem entrou na fila depois da última checagem e viu a trava ainda de pé voltou como "agrupado": confira de novo.
while [ "$resultado" = 0 ] && [ -s "$fila" ] && mkdir "$lider" 2> /dev/null; do
  echo $$ > "$lider/pid"
  levar_fila
  solta_lider
done
exit "$resultado"

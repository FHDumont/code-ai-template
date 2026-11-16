#!/usr/bin/env bash
# Testa o `deploy-segurado.sh` (R-007) com um `gh` falso no PATH. Nunca toca o repositório real.
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=test-lib.sh
source "${AQUI}/test-lib.sh"

TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/e"
export GH_ESTADO="$TMP/e"
export DEPLOY_SEGURADO_PAUSA=0

cat > "$TMP/bin/gh" <<'F'
#!/usr/bin/env bash
set -euo pipefail
e=${GH_ESTADO:?}
echo "gh $*" >> "$e/log"
case "$1 ${2:-}" in
  "variable get") [ -f "$e/var" ] && cat "$e/var" || exit 1 ;;
  "variable list") [ -f "$e/var" ] && echo DEPLOY_SEGURADO || true ;;
  "variable set") while [ $# -gt 0 ]; do [ "$1" = --body ] && printf '%s' "$2" > "$e/var"; shift; done ;;
  "variable delete") rm -f "$e/var" ;;
  "run list")
    [ ! -f "$e/falha" ] || { echo "HTTP 502" >&2; exit 1; }
    case "$*" in
      *"--status success"*) cat "$e/runs" ;;   # linhas "<id>" já filtradas pelo teste
      *"--status in_progress"*)
        case "$*" in
          *deploy-on-build*) [ ! -f "$e/andamento-onbuild" ] || cat "$e/andamento-onbuild" ;;
          *) [ ! -f "$e/andamento" ] || cat "$e/andamento" ;;
        esac ;;
    esac ;;
  "run watch") [ ! -f "$e/watch-falha" ] || exit 1; echo "$3" >> "$e/assistidos"; rm -f "$e/andamento" "$e/andamento-onbuild"; echo 13 > "$e/runs"; echo 1 > "$e/jobs-13" ;;
  "run view") cat "$e/jobs-$3" ;;
  "workflow run") : ;;
  *) echo "gh falso: $*" >&2; exit 1 ;;
esac
F
chmod +x "$TMP/bin/gh"
export PATH="$TMP/bin:$PATH"

S="${AQUI}/deploy-segurado.sh"
disparos() { grep -c '^gh workflow run' "$TMP/e/log" || true; }
: > "$TMP/e/log"

if [ "$(bash "$S" estado)" = livre ]; then teste_ok "estado livre"; else teste_falha "estado devia ser livre"; fi

bash "$S" segurar > /dev/null
h1=$(cat "$TMP/e/var")
sleep 1
bash "$S" segurar > /dev/null
if [ "$(cat "$TMP/e/var")" = "$h1" ]; then teste_ok "segurar duas vezes mantém a hora"; else teste_falha "a hora mudou no segundo segurar"; fi
if [ "$(bash "$S" estado)" = "segurado desde $h1" ]; then teste_ok "estado segurado"; else teste_falha "estado segurado errado"; fi

# Sem imagem: a run existe mas nenhum job build* teve sucesso.
echo 11 > "$TMP/e/runs"; echo 0 > "$TMP/e/jobs-11"
bash "$S" soltar > /dev/null
if [ ! -f "$TMP/e/var" ] && [ "$(disparos)" = 0 ]; then teste_ok "soltar sem imagem não dispara"; else teste_falha "soltar sem imagem"; fi

# Com imagem nova.
bash "$S" segurar > /dev/null
echo 12 > "$TMP/e/runs"; echo 2 > "$TMP/e/jobs-12"
bash "$S" soltar > /dev/null
if [ ! -f "$TMP/e/var" ] && [ "$(disparos)" = 1 ] && grep -q 'workflow run deploy.yml -f reason=fim da leva' "$TMP/e/log"; then
  teste_ok "soltar com imagem nova dispara o deploy"
else teste_falha "soltar com imagem"; fi

# Falha do gh no soltar: a variável fica, nada dispara, sai 1.
bash "$S" segurar > /dev/null
touch "$TMP/e/falha"
teste_rc "soltar com gh falhando sai 1" 1 bash "$S" soltar
rm -f "$TMP/e/falha"
if [ -f "$TMP/e/var" ] && [ "$(disparos)" = 1 ]; then teste_ok "gh falhando mantém a variável e não dispara"; else teste_falha "gh falhando soltou a variável"; fi

# Build do main em andamento: espera e só então decide (a imagem dele conta).
echo 0 > "$TMP/e/jobs-12"; echo 12 > "$TMP/e/runs"
echo 13 > "$TMP/e/andamento"
bash "$S" soltar > /dev/null
if [ ! -f "$TMP/e/var" ] && [ "$(disparos)" = 2 ] && grep -qx 13 "$TMP/e/assistidos"; then
  teste_ok "soltar espera o build em andamento e dispara com a imagem dele"
else teste_falha "soltar com build em andamento"; fi

# O deploy automático disparado pelo build ainda roda: o soltar espera ele antes de apagar a variável.
bash "$S" segurar > /dev/null
echo 21 > "$TMP/e/andamento-onbuild"; echo 12 > "$TMP/e/runs"; echo 2 > "$TMP/e/jobs-12"
bash "$S" soltar > /dev/null
if [ ! -f "$TMP/e/var" ] && grep -qx 21 "$TMP/e/assistidos"; then
  teste_ok "soltar espera o deploy automático em andamento antes de apagar a variável"
else teste_falha "soltar não esperou o on-build"; fi

# gh run watch falhando: sai 1 e a variável fica.
bash "$S" segurar > /dev/null
echo 22 > "$TMP/e/andamento"; touch "$TMP/e/watch-falha"
teste_rc "watch falhando sai 1" 1 bash "$S" soltar
rm -f "$TMP/e/watch-falha" "$TMP/e/andamento"
if [ -f "$TMP/e/var" ]; then teste_ok "watch falhando mantém a variável"; else teste_falha "watch falhando soltou"; fi
bash "$S" soltar > /dev/null

# Livre: soltar não faz nada.
antes=$(disparos)
bash "$S" soltar > /dev/null
if [ "$(disparos)" = "$antes" ]; then teste_ok "soltar livre não dispara"; else teste_falha "soltar livre disparou"; fi

teste_rc "uso inválido" 2 bash "$S" voar

[ "$teste_falhou" = 0 ] && echo ok || exit 1

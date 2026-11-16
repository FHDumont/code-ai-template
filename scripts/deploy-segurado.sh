#!/usr/bin/env bash
# Add-on opcional (R-007, portado do Amplug F-116): segura o deploy automático durante uma leva de fases
# paralelas e o solta no fim, com um restart só. Serve a projeto em que o merge no main publica imagem e um
# workflow faz o deploy sozinho; projeto sem deploy automático não usa este script.
# Uso: scripts/deploy-segurado.sh segurar|soltar|estado
#   segurar  grava a hora na variável DEPLOY_SEGURADO do repositório (idempotente: mantém a hora antiga).
#   soltar   apaga a variável e, se algum build do main publicou imagem depois da hora gravada (job cujo
#            nome começa com o prefixo de build, com sucesso), dispara o deploy manual. Sem imagem nova,
#            não dispara: zero restart.
#   estado   imprime "segurado desde <hora>" ou "livre".
# O que o projeto fornece (troque os padrões abaixo ou defina as variáveis de ambiente):
#   - o workflow de build (DEPLOY_SEGURADO_BUILD_WORKFLOW) e o prefixo dos jobs que publicam imagem
#     (DEPLOY_SEGURADO_JOB_PREFIXO);
#   - o workflow de deploy manual (DEPLOY_SEGURADO_DEPLOY_WORKFLOW), que aceita a entrada `reason`;
#   - o workflow de deploy automático depois do build (DEPLOY_SEGURADO_ON_BUILD_WORKFLOW), com um passo que
#     lê `vars.DEPLOY_SEGURADO` e, com ela preenchida, termina verde sem recriar nada.
set -euo pipefail

VAR=DEPLOY_SEGURADO
BUILD_WORKFLOW=${DEPLOY_SEGURADO_BUILD_WORKFLOW:-build-images.yml}
DEPLOY_WORKFLOW=${DEPLOY_SEGURADO_DEPLOY_WORKFLOW:-deploy.yml}
ON_BUILD_WORKFLOW=${DEPLOY_SEGURADO_ON_BUILD_WORKFLOW:-deploy-on-build.yml}
JOB_PREFIXO=${DEPLOY_SEGURADO_JOB_PREFIXO:-build}

uso() { echo "uso: deploy-segurado.sh segurar|soltar|estado" >&2; exit 2; }
[ $# -eq 1 ] || uso

# A hora gravada, ou vazio se livre. Falha do gh para o script: "livre" por engano soltaria um deploy.
hora_gravada() {
  local saida
  if ! saida=$(gh variable get "$VAR" 2> /dev/null); then
    # `gh variable get` sai 1 quando a variável não existe; confirma pela lista antes de achar livre.
    local lista
    lista=$(gh variable list --json name --jq '.[].name') || { echo "erro: não consegui ler as variáveis do repositório" >&2; exit 1; }
    if printf '%s\n' "$lista" | grep -qx "$VAR"; then
      echo "erro: não consegui ler $VAR" >&2; exit 1
    fi
    return 0
  fi
  printf '%s' "$saida"
}

# Espera os runs de $1 (um workflow) ainda na fila ou rodando. Sem --exit-status o `gh run watch` só falha
# por erro de verdade (rede, auth): vira exit 1 com a variável preenchida, nunca decisão às cegas.
esperar_em_andamento() {
  local wf=$1 st ids id
  for st in queued in_progress; do
    ids=$(gh run list --workflow "$wf" --branch main --status "$st" --json databaseId --jq '.[].databaseId') \
      || { echo "erro: não consegui listar as runs $st de $wf; a variável segue preenchida" >&2; exit 1; }
    for id in $ids; do
      echo "esperando a run $id de $wf terminar…"
      gh run watch "$id" > /dev/null \
        || { echo "erro: o gh run watch da run $id falhou; a variável segue preenchida" >&2; exit 1; }
    done
  done
}

# Antes de decidir: os builds do main ainda rodando (o deploy do fim da leva tem de puxar a `latest` deles) e,
# depois, os deploys automáticos que esses builds dispararam ao terminar. Esses ainda leem a variável
# preenchida e saem verdes sem recriar nada; se o `soltar` apagasse a variável antes deles, eles recriariam
# os containers depois do deploy manual: o segundo restart (R-007).
esperar_builds_em_andamento() {
  esperar_em_andamento "$BUILD_WORKFLOW"
  sleep "${DEPLOY_SEGURADO_PAUSA:-5}" # o GitHub cria a run do workflow_run uns segundos depois do build
  esperar_em_andamento "$ON_BUILD_WORKFLOW"
}

# Imprime "sim" ou "nao": houve job de build bem-sucedido num build do main concluído depois de $1?
# Falha do gh para o script (nunca vira "nao": soltaria sem deploy uma leva que tem imagem).
houve_imagem() {
  local desde=$1 ids id n
  ids=$(gh run list --workflow "$BUILD_WORKFLOW" --branch main --status success --limit 100 \
    --json databaseId,updatedAt --jq ".[] | select(.updatedAt >= \"$desde\") | .databaseId") \
    || { echo "erro: não consegui listar os builds do main; a variável segue preenchida" >&2; exit 1; }
  for id in $ids; do
    n=$(gh run view "$id" --json jobs \
      --jq "[.jobs[] | select(.name | startswith(\"$JOB_PREFIXO\")) | select(.conclusion == \"success\")] | length") \
      || { echo "erro: não consegui ler os jobs da run $id; a variável segue preenchida" >&2; exit 1; }
    if [ "${n:-0}" -gt 0 ]; then echo sim; return 0; fi
  done
  echo nao
}

case "$1" in
  segurar)
    atual=$(hora_gravada)
    if [ -n "$atual" ]; then
      echo "já segurado desde $atual (mantida)"
    else
      agora=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      gh variable set "$VAR" --body "$agora"
      echo "segurado desde $agora"
    fi ;;
  soltar)
    atual=$(hora_gravada)
    if [ -z "$atual" ]; then echo "livre: nada a soltar"; exit 0; fi
    esperar_builds_em_andamento
    imagem=$(houve_imagem "$atual")
    if [ "$imagem" = sim ]; then
      gh workflow run "$DEPLOY_WORKFLOW" -f reason="fim da leva (segurado desde $atual)"
      gh variable delete "$VAR"
      echo "solto: houve imagem desde $atual; deploy disparado (acompanhe: gh run list --workflow $DEPLOY_WORKFLOW)"
    else
      gh variable delete "$VAR"
      echo "solto: sem imagem nova desde $atual; nenhum deploy (zero restart)"
    fi ;;
  estado)
    atual=$(hora_gravada)
    if [ -n "$atual" ]; then echo "segurado desde $atual"; else echo livre; fi ;;
  *) uso ;;
esac

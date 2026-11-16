#!/usr/bin/env bash
# Lista fases em execução e a fila do que depende delas.
# Roda no bash 3.2 (R-002; F-metodo-v8, Amplug F-098): o que era mapa associativo é lista em texto.
# Uso:
#   scripts/fases-ativas.sh [--fetch] [--sobrepor caminho...]
# --fetch atualiza os refs remotos (se falhar, segue com o que já está local).
# --sobrepor sai 1 se alguma fase reivindica algum dos caminhos.
# Fase solitária sem registro reivindica o repo inteiro.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
# shellcheck source=lib/integracao.sh
source "${SCRIPT_DIR}/lib/integracao.sh"

fetch=0
sobrepor=0
declare -a caminhos=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fetch) fetch=1; shift ;;
    --sobrepor) sobrepor=1; shift ;;
    --) shift; break ;;
    -*)
      echo "argumento desconhecido: $1" >&2
      exit 1
      ;;
    *)
      caminhos+=("$1")
      shift
      ;;
  esac
done
while [[ $# -gt 0 ]]; do
  caminhos+=("$1")
  shift
done

if [[ $fetch -eq 1 ]]; then
  if ! git fetch origin --prune >/dev/null 2>&1; then
    echo "aviso: git fetch origin falhou; listo só o que já está local" >&2
  fi
fi

if [[ $sobrepor -eq 1 && ${#caminhos[@]} -eq 0 ]]; then
  echo "uso: scripts/fases-ativas.sh --sobrepor caminho..." >&2
  exit 1
fi

# Nomes com prefixo: o caller tem `local arquivos` e o bash enxerga o local do pai.
declare -a fase_ids=() fase_modos=() fase_situacoes=() fase_branches=() fase_worktrees=()
declare -a fase_arquivos=() fase_areas=() fase_bots=() fase_depende=() fase_escopos=()
declare -a fila=() fila_roadmap=() fila_fragmento=() fila_issue=()
fila_crua=$'\n'

# A mesma linha não entra duas vezes. A ordem de impressão é outra função.
guardar_fila() {
  local crua="$1" item="$2" balde="$3"
  if [[ "$fila_crua" == *$'\n'"$crua"$'\n'* ]]; then
    return 0
  fi
  fila_crua="${fila_crua}${crua}"$'\n'
  case "$balde" in
    roadmap) fila_roadmap+=("$item") ;;
    fragmento) fila_fragmento+=("$item") ;;
    issue) fila_issue+=("$item") ;;
  esac
}

registrar() {
  local id="$1"
  local i=0
  while [[ $i -lt ${#fase_ids[@]} ]]; do
    if [[ "${fase_ids[$i]}" == "$id" ]]; then
      return 1
    fi
    i=$((i + 1))
  done
  fase_ids+=("$id")
  fase_modos+=("$2")
  fase_situacoes+=("$3")
  fase_branches+=("$4")
  fase_worktrees+=("$5")
  fase_arquivos+=("$6")
  fase_areas+=("$7")
  fase_bots+=("$8")
  fase_depende+=("$9")
  fase_escopos+=("${10}")
}

ler_claim() {
  local arquivo="$1" wt="$2" branch="$3"
  local id="" titulo="" modo="paralela" status="executando" arquivos="-" areas="-" bots="-" depende="-" escopo="-"
  local linha chave valor
  while IFS= read -r linha || [[ -n "$linha" ]]; do
    [[ "$linha" =~ ^([a-z_]+):[[:space:]]*(.*)$ ]] || continue
    chave="${BASH_REMATCH[1]}"
    valor="${BASH_REMATCH[2]}"
    case "$chave" in
      id) id="$valor" ;;
      titulo) titulo="$valor" ;;
      modo) modo="$valor" ;;
      status) status="$valor" ;;
      branch) branch="$valor" ;;
      arquivos) arquivos="$valor" ;;
      areas) areas="$valor" ;;
      bots) bots="$valor" ;;
      depende_de) depende="$valor" ;;
      escopo) escopo="$valor" ;;
    esac
  done < "$arquivo"
  [[ -n "$id" ]] || return 0
  if [[ "$escopo" == "-" && -n "$titulo" ]]; then
    escopo="$titulo"
  fi
  registrar "$id" "$modo" "$status" "$branch" "$wt" "$arquivos" "$areas" "$bots" "$depende" "$escopo" || true
}

ler_claim_de_ref() {
  local ref="$1" branch="$2" arq
  local lista
  lista="$(git ls-tree -r --name-only "$ref" -- docs/fases-ativas 2>/dev/null || true)"
  [[ -n "$lista" ]] || return 0
  while IFS= read -r arq; do
    [[ "$arq" == docs/fases-ativas/F-*.md ]] || continue
    local tmp
    tmp="$(mktemp)"
    git show "${ref}:${arq}" > "$tmp"
    ler_claim "$tmp" "-" "$branch"
    rm -f "$tmp"
  done <<< "$lista"
}

ler_fragmento_fila() {
  local ref="$1" origem="$2" secao="" linha
  local conteudo
  local arq
  local lista
  lista="$(git ls-tree -r --name-only "$ref" -- docs/changes 2>/dev/null || true)"
  [[ -n "$lista" ]] || return 0
  while IFS= read -r arq; do
    [[ "$arq" == docs/changes/F-*.md ]] || continue
    conteudo="$(git show "${ref}:${arq}" 2>/dev/null || true)"
    secao=""
    while IFS= read -r linha || [[ -n "$linha" ]]; do
      if [[ "$linha" =~ ^##[[:space:]]+([a-z0-9-]+)[[:space:]]*$ ]]; then
        secao="${BASH_REMATCH[1]}"
        continue
      fi
      [[ "$secao" == "roadmap-add" ]] || continue
      [[ -z "$linha" || "$linha" == '#'* || "$linha" == '<!--'* ]] && continue
      guardar_fila "$linha" "${linha} — na ${origem}, ainda fora do main" fragmento
    done <<< "$conteudo"
  done <<< "$lista"
}

branch_vista=$'\n'

while IFS= read -r bloco; do
  [[ -n "$bloco" ]] || continue
  wt="${bloco%%|*}"
  br="${bloco#*|}"
  if [[ -d "${wt}/docs/fases-ativas" ]]; then
    for arq in "${wt}/docs/fases-ativas"/F-*.md; do
      [[ -f "$arq" ]] || continue
      ler_claim "$arq" "$wt" "$br"
    done
  fi
  if [[ "$br" == fase/* ]]; then
    branch_vista="${branch_vista}${br}"$'\n'
  fi
done < <(git worktree list --porcelain | awk '
  /^worktree / { wt=$0; sub(/^worktree /, "", wt) }
  /^branch / { br=$0; sub(/^branch refs\/heads\//, "", br); print wt "|" br }
  /^detached / { print wt "|DETACHED" }
')

base_ref="main"
if git rev-parse --verify --quiet origin/main >/dev/null; then
  base_ref="origin/main"
fi

varrer_refs() {
  local consulta="$1" ref curto
  while IFS= read -r ref; do
    [[ -n "$ref" ]] || continue
    curto="$ref"
    curto="${curto#origin/}"
    [[ "$curto" == fase/* ]] || continue
    ler_fragmento_fila "$ref" "$curto"
    if [[ "$branch_vista" == *$'\n'"$curto"$'\n'* ]]; then
      continue
    fi
    branch_vista="${branch_vista}${curto}"$'\n'
    ler_claim_de_ref "$ref" "$curto"
    if ! git ls-tree -r --name-only "$ref" -- docs/fases-ativas 2>/dev/null | grep -q '^docs/fases-ativas/F-'; then
      if ! git merge-base --is-ancestor "$ref" "$base_ref" 2>/dev/null; then
        registrar "$curto" "solitaria" "sem-registro" "$curto" "-" "repo-inteiro" "-" "-" "-" "branch sem docs/fases-ativas; trata como o repo inteiro" || true
      fi
    fi
  done < <(git for-each-ref --format='%(refname:short)' "$consulta")
}

varrer_refs "refs/heads"
varrer_refs "refs/remotes/origin"

# Spec solitária ainda não commitada no checkout da main.
main_wt=""
while IFS= read -r bloco; do
  wt="${bloco%%|*}"
  br="${bloco#*|}"
  if [[ "$br" == "main" ]]; then
    main_wt="$wt"
  fi
done < <(git worktree list --porcelain | awk '
  /^worktree / { wt=$0; sub(/^worktree /, "", wt) }
  /^branch / { br=$0; sub(/^branch refs\/heads\//, "", br); print wt "|" br }
')
if [[ -n "$main_wt" && -f "${main_wt}/docs/SETUP.md" ]] && grep -q '^# F-' "${main_wt}/docs/SETUP.md"; then
  spec_id="$(grep -m1 '^# F-' "${main_wt}/docs/SETUP.md" | sed -E 's/^# (F-[A-Za-z0-9]+(-[A-Za-z0-9]+)*).*/\1/')"
  registrar "${spec_id:-spec-local}" "solitaria" "nao-commitada" "(working tree)" "$main_wt" "repo-inteiro" "-" "-" "-" "spec no SETUP.md da main; fase solitária ainda não saiu deste checkout" || true
fi

if [[ -f "${ROOT}/docs/ROADMAP.md" && -f "${ROOT}/docs/CHANGELOG.md" ]]; then
  while IFS= read -r linha; do
    [[ "$linha" == *"depende de "* ]] || continue
    bloqueada=0
    while IFS= read -r dep; do
      [[ -n "$dep" ]] || continue
      if ! grep -F -q -- "**${dep}**" "${ROOT}/docs/CHANGELOG.md" && ! grep -E -q "^- ${dep} " "${ROOT}/docs/CHANGELOG.md"; then
        bloqueada=1
      fi
    done < <(integracao_ids_depende "$linha")
    if [[ $bloqueada -eq 1 ]]; then
      guardar_fila "$linha" "${linha} — no ROADMAP; a dependência ainda não está no CHANGELOG" roadmap
    fi
  done < "${ROOT}/docs/ROADMAP.md"
fi

# Corpo de issue aberta com "depende de". Fora do GitHub, ou se o gh falhar, a fila segue sem essa fonte.
ler_issues_fila() {
  local url json n body linha dep bloqueada
  url="$(git remote get-url origin 2>/dev/null || true)"
  if [[ "${FASES_ATIVAS_GH:-}" != 1 && "$url" != *github.com* && "$url" != *github.com:* ]]; then
    return 0
  fi
  command -v gh >/dev/null 2>&1 || return 0
  command -v jq >/dev/null 2>&1 || return 0
  if ! json="$(GH_PROMPT_DISABLED=1 gh issue list --state open --limit 100 --json number,body 2>/dev/null)"; then
    echo "aviso: não li issues abertas; a fila pode estar incompleta" >&2
    return 0
  fi
  [[ -n "$json" && "$json" != "[]" ]] || return 0
  [[ -f "${ROOT}/docs/CHANGELOG.md" ]] || return 0
  while IFS= read -r obj; do
    [[ -n "$obj" ]] || continue
    n="$(jq -r '.number' <<<"$obj")"
    body="$(jq -r '.body // ""' <<<"$obj")"
    while IFS= read -r linha || [[ -n "$linha" ]]; do
      [[ "$linha" == *"depende de "* ]] || continue
      bloqueada=0
      while IFS= read -r dep; do
        [[ -n "$dep" ]] || continue
        if ! grep -F -q -- "**${dep}**" "${ROOT}/docs/CHANGELOG.md" && ! grep -E -q "^- ${dep} " "${ROOT}/docs/CHANGELOG.md"; then
          bloqueada=1
        fi
      done < <(integracao_ids_depende "$linha")
      if [[ $bloqueada -eq 1 ]]; then
        guardar_fila "$linha" "${linha} — na issue #${n}; a dependência ainda não está no CHANGELOG" issue
      fi
    done <<< "$body"
  done < <(jq -c '.[]' <<<"$json")
}
ler_issues_fila

fila=()
[[ ${#fila_roadmap[@]} -eq 0 ]] || fila+=("${fila_roadmap[@]}")
[[ ${#fila_fragmento[@]} -eq 0 ]] || fila+=("${fila_fragmento[@]}")
[[ ${#fila_issue[@]} -eq 0 ]] || fila+=("${fila_issue[@]}")

echo "# fases ativas"
if [[ ${#fase_ids[@]} -eq 0 ]]; then
  echo "(nenhuma)"
else
  i=0
  while [[ $i -lt ${#fase_ids[@]} ]]; do
    echo
    echo "## ${fase_ids[$i]}"
    echo "modo: ${fase_modos[$i]}"
    echo "status: ${fase_situacoes[$i]}"
    echo "branch: ${fase_branches[$i]}"
    echo "worktree: ${fase_worktrees[$i]}"
    echo "arquivos: ${fase_arquivos[$i]}"
    echo "areas: ${fase_areas[$i]}"
    echo "bots: ${fase_bots[$i]}"
    echo "depende_de: ${fase_depende[$i]}"
    echo "escopo: ${fase_escopos[$i]}"
    i=$((i + 1))
  done
fi

echo
echo "# fila"
if [[ ${#fila[@]} -eq 0 ]]; then
  echo "(nenhuma)"
else
  for linha in "${fila[@]}"; do
    if [[ "$linha" == "- "* ]]; then
      echo "$linha"
    else
      echo "- ${linha}"
    fi
  done
fi

# Alarme do esquecido (R-007): deploy segurado e ninguém mais na leva. Só com gh e o remoto do GitHub
# (ou FASES_ATIVAS_GH=1, o teste); qualquer falha em ler a variável cala o aviso, nunca quebra a listagem.
if [[ ${#fase_ids[@]} -eq 0 && ${#fila[@]} -eq 0 ]]; then
  url_origem="$(git remote get-url origin 2>/dev/null || true)"
  if [[ "${FASES_ATIVAS_GH:-}" == 1 || "$url_origem" == *github.com* ]] && command -v gh >/dev/null 2>&1; then
    segurado_desde="$(GH_PROMPT_DISABLED=1 gh variable get DEPLOY_SEGURADO 2>/dev/null || true)"
    if [[ -n "$segurado_desde" ]]; then
      echo
      echo "aviso: deploy segurado sem leva (desde ${segurado_desde}): rode scripts/deploy-segurado.sh soltar"
    fi
  fi
fi

if [[ $sobrepor -eq 1 ]]; then
  cruzou=0
  i=0
  while [[ $i -lt ${#fase_ids[@]} ]]; do
    reiv="${fase_arquivos[$i]}"
    for caminho in ${caminhos[@]+"${caminhos[@]}"}; do
      if [[ "$reiv" == "repo-inteiro" ]]; then
        echo "sobrepõe ${fase_ids[$i]} (repo inteiro): ${caminho}" >&2
        cruzou=1
        continue
      fi
      partes=()
      IFS=',' read -ra partes <<< "$reiv"
      for parte in ${partes[@]+"${partes[@]}"}; do
        parte="${parte#"${parte%%[![:space:]]*}"}"
        parte="${parte%"${parte##*[![:space:]]}"}"
        [[ -n "$parte" ]] || continue
        if integracao_sobrepoe "$parte" "$caminho"; then
          echo "sobrepõe ${fase_ids[$i]} em ${parte}: ${caminho}" >&2
          cruzou=1
        fi
      done
    done
    i=$((i + 1))
  done
  if [[ $cruzou -eq 1 ]]; then
    exit 1
  fi
fi

exit 0

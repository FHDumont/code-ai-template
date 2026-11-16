#!/usr/bin/env bash
# Abre uma fase paralela (R-001): worktree, branch fase/<id>-<slug>, registro, fragmento e spec.
# Não abre pull request. Fase solitária não usa este script.
# O worktree nasce em ../<repo>-fases/<id> pronto pra rodar, com três ganchos do projeto derivado:
#   ABRIR_FASE_SO_SOLITARIA  caminhos (vírgula) que só fase solitária toca — recurso que não se divide, como
#                            o schema e as migrations de um banco de desenvolvimento único; `--arquivos` que
#                            cruze um deles é recusado. Vazio por padrão.
#   ABRIR_FASE_LINKS         arquivos fora do git (espaço) que o worktree recebe por link do checkout
#                            principal. Padrão: `.claude/settings.local.json`.
#   scripts/preparar-worktree.sh   se existe, roda dentro do worktree novo (instalar dependências, por exemplo).
# O projeto fixa os dois primeiros trocando o padrão nas linhas `SO_SOLITARIA=` e `LINKS=` abaixo.
# Uso: scripts/abrir-fase.sh --id F-012 --slug tags --spec spec.md --arquivos 'src/tags/' \
#        [--titulo T] [--escopo E] [--areas A] [--bots B] [--depende-de F-010] \
#        [--enfileirar '**F-020** — ... — depende de F-012'] [--destino DIR] [--base REF] [--sem-push]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
# shellcheck source=lib/integracao.sh
source "${SCRIPT_DIR}/lib/integracao.sh"

SO_SOLITARIA="${ABRIR_FASE_SO_SOLITARIA:-}"
LINKS="${ABRIR_FASE_LINKS:-.claude/settings.local.json}"

id="" slug="" spec="" arquivos="" titulo="" escopo="" areas="-" bots="-" depende="-" destino="" base="" sem_push=0
declare -a enfileirar=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) id="$2"; shift 2 ;;
    --slug) slug="$2"; shift 2 ;;
    --spec) spec="$2"; shift 2 ;;
    --arquivos) arquivos="$2"; shift 2 ;;
    --titulo) titulo="$2"; shift 2 ;;
    --escopo) escopo="$2"; shift 2 ;;
    --areas) areas="$2"; shift 2 ;;
    --bots) bots="$2"; shift 2 ;;
    --depende-de) depende="$2"; shift 2 ;;
    --destino) destino="$2"; shift 2 ;;
    --base) base="$2"; shift 2 ;;
    --sem-push) sem_push=1; shift ;;
    --enfileirar) enfileirar+=("$2"); shift 2 ;;
    *)
      echo "argumento desconhecido: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$id" || -z "$slug" || -z "$spec" || -z "$arquivos" ]]; then
  echo "obrigatório: --id --slug --spec --arquivos" >&2
  exit 1
fi
if ! integracao_id_valido "$id"; then
  echo "id inválido: ${id}" >&2
  exit 1
fi
if ! [[ "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "slug inválido: ${slug}" >&2
  exit 1
fi
if [[ ! -f "$spec" ]]; then
  echo "spec não encontrada: ${spec}" >&2
  exit 1
fi

partes=()
IFS=',' read -ra partes <<< "$arquivos"
for parte in ${partes[@]+"${partes[@]}"}; do
  parte="${parte#"${parte%%[![:space:]]*}"}"
  parte="${parte%"${parte##*[![:space:]]}"}"
  [[ -n "$parte" ]] || continue
  so_solitaria=()
  IFS=',' read -ra so_solitaria <<< "$SO_SOLITARIA"
  for unico in ${so_solitaria[@]+"${so_solitaria[@]}"}; do
    unico="${unico#"${unico%%[![:space:]]*}"}"
    unico="${unico%"${unico##*[![:space:]]}"}"
    [[ -n "$unico" ]] || continue
    if integracao_sobrepoe "$parte" "$unico"; then
      echo "não abri ${id}: ${parte} cruza ${unico}; fase que toca esse caminho é sempre solitária (R-001)" >&2
      exit 1
    fi
  done
done

if [[ $sem_push -eq 0 ]]; then
  git fetch origin main >/dev/null 2>&1
fi
if [[ -z "$base" ]]; then
  if git rev-parse --verify --quiet origin/main >/dev/null; then
    base="origin/main"
  else
    base="main"
  fi
fi

changelog_base="$(git show "${base}:docs/CHANGELOG.md" 2>/dev/null || true)"
if [[ "$changelog_base" == *"**${id}**"* ]]; then
  echo "${id} já está no CHANGELOG" >&2
  exit 1
fi

if [[ "$depende" != "-" && -n "$depende" ]]; then
  while IFS= read -r dep; do
    [[ -n "$dep" ]] || continue
    if [[ "$changelog_base" != *"**${dep}**"* ]]; then
      echo "dependência ${dep} ainda não está no CHANGELOG; deixe na fila, não abra a fase" >&2
      exit 2
    fi
  done < <(integracao_ids_depende "depende de ${depende}")
  # também aceita um id cru, sem a frase "depende de"
  if [[ "$depende" != *"depende de"* ]] && integracao_id_valido "$depende"; then
    if [[ "$changelog_base" != *"**${depende}**"* ]]; then
      echo "dependência ${depende} ainda não está no CHANGELOG; deixe na fila, não abra a fase" >&2
      exit 2
    fi
  fi
fi

if bash "${SCRIPT_DIR}/fases-ativas.sh" 2>/dev/null | grep -q "^## ${id}$"; then
  echo "${id} já está ativa" >&2
  exit 1
fi

for parte in ${partes[@]+"${partes[@]}"}; do
  parte="${parte#"${parte%%[![:space:]]*}"}"
  parte="${parte%"${parte##*[![:space:]]}"}"
  [[ -n "$parte" ]] || continue
  if ! bash "${SCRIPT_DIR}/fases-ativas.sh" --sobrepor "$parte" >/dev/null; then
    echo "não abri ${id}: sobreposição em ${parte}" >&2
    exit 1
  fi
done

branch="fase/${id}-${slug}"
if git show-ref --verify --quiet "refs/heads/${branch}"; then
  echo "branch já existe: ${branch}" >&2
  exit 1
fi

if [[ -z "$destino" ]]; then
  pai="$(cd "$(dirname "$ROOT")" && pwd)"
  nome="$(basename "$ROOT")"
  destino="${pai}/${nome}-fases/${id}"
fi
if [[ -e "$destino" ]]; then
  echo "destino já existe: ${destino}" >&2
  exit 1
fi
mkdir -p "$(dirname "$destino")"

git worktree add -b "$branch" "$destino" "$base" >/dev/null 2>&1

[[ -n "$titulo" ]] || titulo="$id"
[[ -n "$escopo" ]] || escopo="$titulo"

cp "$spec" "${destino}/docs/SETUP.md"
mkdir -p "${destino}/docs/fases-ativas" "${destino}/docs/changes"
cat > "${destino}/docs/fases-ativas/${id}.md" <<EOF
id: ${id}
titulo: ${titulo}
modo: paralela
status: executando
branch: ${branch}
depende_de: ${depende}
arquivos: ${arquivos}
areas: ${areas}
bots: ${bots}
escopo: ${escopo}
EOF
integracao_escrever_fragmento_vazio "${destino}/docs/changes/${id}.md" "$id"
for linha in ${enfileirar[@]+"${enfileirar[@]}"}; do
  integracao_enfileirar_no_fragmento "${destino}/docs/changes/${id}.md" "$linha"
done

git -C "$destino" add -- \
  docs/SETUP.md \
  "docs/fases-ativas/${id}.md" \
  "docs/changes/${id}.md"
git -C "$destino" commit --quiet -m "docs: abre ${id}"

if [[ $sem_push -eq 0 ]]; then
  git -C "$destino" push -u origin "$branch" >/dev/null 2>&1
fi

# O worktree pronto pra rodar: os arquivos fora do git vêm por link do checkout principal.
for local_ in $LINKS; do
  if [[ -e "${ROOT}/${local_}" && ! -e "${destino}/${local_}" ]]; then
    mkdir -p "$(dirname "${destino}/${local_}")"
    ln -s "${ROOT}/${local_}" "${destino}/${local_}"
  fi
done
if [[ -f "${destino}/scripts/preparar-worktree.sh" ]]; then
  if ! (cd "$destino" && bash scripts/preparar-worktree.sh >/dev/null); then
    echo "o worktree ${destino} nasceu, mas o scripts/preparar-worktree.sh falhou; rode de novo lá" >&2
    exit 1
  fi
fi
echo "branch: ${branch}"
echo "worktree: ${destino}"

# A sessão da fase nasce no checkout principal, com o trust dele, e trabalha no worktree por caminho
# absoluto; o fecho tira o worktree sem matar a sessão (Amplug F-110). Pra ela editar lá sem pedir, a pasta
# dos worktrees tem de estar no `additionalDirectories` do settings local — passo do dono, só conferido aqui.
pasta_fases="$(cd "$(dirname "$destino")" && pwd)"
coberta=0
settings_local="${ROOT}/.claude/settings.local.json"
if [[ -f "$settings_local" ]]; then
  if command -v jq >/dev/null 2>&1; then
    dirs="$(jq -r '.permissions.additionalDirectories[]? // empty' "$settings_local" 2>/dev/null || true)"
  else
    dirs="$(grep -oE '"/[^"]+"' "$settings_local" | tr -d '"' || true)"
  fi
  while IFS= read -r d; do
    d="${d%/}"
    [[ -n "$d" ]] || continue
    if [[ "$pasta_fases" == "$d" || "$pasta_fases" == "$d"/* ]]; then
      coberta=1
    fi
  done <<< "$dirs"
fi
if [[ $coberta -eq 0 ]]; then
  {
    echo "aviso: ${pasta_fases} não está no permissions.additionalDirectories de ${settings_local}."
    echo "  A sessão no checkout principal pediria permissão a cada edição no worktree. Passo do dono, uma vez:"
    echo "  \"${pasta_fases}\""
  } >&2
fi
echo "sessão: abra no checkout principal (${ROOT}), não no worktree"
echo "prompt: Executa a fase ${id} do SETUP em ${destino}/docs/SETUP.md. A sessão fica no checkout principal; trabalhe no worktree por caminho absoluto (edição em ${destino}/…, comando com \`cd ${destino} && …\` ou \`git -C ${destino}\`). Termine todo turno com a placa de estado (\`AGENTS.md\` §Placa de estado)."

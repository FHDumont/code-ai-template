#!/usr/bin/env bash
# Abre uma fase paralela: worktree, branch fase/<id>-<slug>, registro, fragmento e spec.
# Não abre pull request. Fase solitária não usa este script.
# Uso: scripts/abrir-fase.sh --id F-012 --slug tags --spec spec.md --arquivos 'src/tags/' \
#        [--titulo T] [--escopo E] [--areas A] [--bots B] [--depende-de F-010] \
#        [--enfileirar '- **F-020** — ... — depende de F-012'] [--destino DIR] [--base REF] [--sem-push]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
# shellcheck source=lib/integracao.sh
source "${SCRIPT_DIR}/lib/integracao.sh"

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

changelog="$(git show "${base}:docs/CHANGELOG.md" 2>/dev/null || true)"
if [[ "$changelog" == *"**${id}**"* ]]; then
  echo "${id} já está no CHANGELOG" >&2
  exit 1
fi

if [[ "$depende" != "-" && -n "$depende" ]]; then
  while IFS= read -r dep; do
    [[ -n "$dep" ]] || continue
    if [[ "$changelog" != *"**${dep}**"* ]]; then
      echo "dependência ${dep} ainda não está no CHANGELOG; deixe na fila, não abra a fase" >&2
      exit 2
    fi
  done < <(integracao_ids_depende "depende de ${depende}")
  # também aceita um id cru, sem a frase "depende de"
  if [[ "$depende" != *"depende de"* ]] && integracao_id_valido "$depende"; then
    if [[ "$changelog" != *"**${depende}**"* ]]; then
      echo "dependência ${depende} ainda não está no CHANGELOG; deixe na fila, não abra a fase" >&2
      exit 2
    fi
  fi
fi

if bash "${SCRIPT_DIR}/fases-ativas.sh" 2>/dev/null | grep -q "^## ${id}$"; then
  echo "${id} já está ativa" >&2
  exit 1
fi

IFS=',' read -ra partes <<< "$arquivos"
for parte in "${partes[@]}"; do
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
for linha in "${enfileirar[@]+"${enfileirar[@]}"}"; do
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

echo "branch: ${branch}"
echo "worktree: ${destino}"

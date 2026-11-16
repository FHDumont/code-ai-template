#!/usr/bin/env bash
# Acrescenta um item na fila de uma fase paralela já aberta, no fragmento dela (R-005).
# Recusa se o worktree estiver sujo — a fase em execução não leva commit alheio no meio.
# Uso: scripts/enfileirar.sh --na F-012 --linha '**F-020** — exportar — depende de F-012' [--sem-push]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
# shellcheck source=lib/integracao.sh
source "${SCRIPT_DIR}/lib/integracao.sh"

na="" linha="" sem_push=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --na) na="$2"; shift 2 ;;
    --linha) linha="$2"; shift 2 ;;
    --sem-push) sem_push=1; shift ;;
    *)
      echo "argumento desconhecido: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$na" || -z "$linha" ]]; then
  echo "obrigatório: --na --linha" >&2
  exit 1
fi
if ! integracao_id_valido "$na"; then
  echo "id inválido: ${na}" >&2
  exit 1
fi

wt=""
atual=""
while IFS= read -r bloco; do
  caminho="${bloco%%|*}"
  br="${bloco#*|}"
  if [[ -f "${caminho}/docs/fases-ativas/${na}.md" ]]; then
    wt="$caminho"
    atual="$br"
  fi
done < <(git worktree list --porcelain | awk '
  /^worktree / { wt=$0; sub(/^worktree /, "", wt) }
  /^branch / { br=$0; sub(/^branch refs\/heads\//, "", br); print wt "|" br }
')

if [[ -z "$wt" ]]; then
  echo "não achei worktree com docs/fases-ativas/${na}.md" >&2
  exit 1
fi
if [[ -n "$(git -C "$wt" status --porcelain)" ]]; then
  echo "worktree de ${na} está sujo (${wt}); não enfileirei. Deixe a linha no corpo da issue e no fragmento no fecho." >&2
  exit 1
fi

fragmento="${wt}/docs/changes/${na}.md"
if [[ ! -f "$fragmento" ]]; then
  echo "fragmento ausente: ${fragmento}" >&2
  exit 1
fi
integracao_enfileirar_no_fragmento "$fragmento" "$linha"
git -C "$wt" add -- "docs/changes/${na}.md"
if git -C "$wt" diff --cached --quiet; then
  echo "fila já tinha essa linha"
  exit 0
fi
git -C "$wt" commit -m "docs: enfileira depois de ${na}"
if [[ $sem_push -eq 0 ]]; then
  git -C "$wt" push origin "$atual"
fi
echo "enfileirado em ${atual}"

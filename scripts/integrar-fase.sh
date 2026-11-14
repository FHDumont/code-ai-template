#!/usr/bin/env bash
# Integra uma fase no main, uma por vez.
# Atualiza a branch com a main, resolve conflito trivial de ledger, roda a validação
# e só então faz o merge. Conflito de lógica ou validação que falha: para, segura a trava
# e pede decisão. A trava é refs/integracao/lock no remoto.
#
# Uso, a partir do worktree da fase:
#   scripts/integrar-fase.sh --id F-012 [--titulo T] [--corpo arquivo.md]
#   scripts/integrar-fase.sh --id F-012 --continuar
#   scripts/integrar-fase.sh --id F-012 --abortar
#
# Saídas: 0 integrou; 1 uso ou git; 3 trava de outra fase; 4 conflito de lógica
# (rebase parado); 5 validação falhou; 6 fragmento sem changelog.
# INTEGRACAO_SEM_GITHUB=1 fast-forward na worktree da main (teste). Sem isso, gh pr merge --rebase.
# INTEGRACAO_VALIDAR, se definida, substitui scripts/validar.sh (teste).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/integracao.sh
source "${SCRIPT_DIR}/lib/integracao.sh"

id="" titulo="" corpo="" abortar=0
remote="${INTEGRACAO_REMOTE:-origin}"
base="${INTEGRACAO_BASE:-origin/main}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) id="$2"; shift 2 ;;
    --titulo) titulo="$2"; shift 2 ;;
    --corpo) corpo="$2"; shift 2 ;;
    --abortar) abortar=1; shift ;;
    --continuar) shift ;;
    *)
      echo "argumento desconhecido: $1" >&2
      exit 1
      ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if [[ -z "$id" ]]; then
  shopt -s nullglob
  claims=(docs/fases-ativas/F-*.md)
  shopt -u nullglob
  if [[ ${#claims[@]} -eq 1 ]]; then
    id="$(basename "${claims[0]}" .md)"
  else
    echo "passe --id (não há um único docs/fases-ativas/F-*.md neste worktree)" >&2
    exit 1
  fi
fi
if ! integracao_id_valido "$id"; then
  echo "id inválido: ${id}" >&2
  exit 1
fi

branch="$(git branch --show-current || true)"
if [[ -z "$branch" ]]; then
  head_name="$(git rev-parse --git-path rebase-merge)/head-name"
  if [[ -f "$head_name" ]]; then
    branch="$(cat "$head_name")"
    branch="${branch#refs/heads/}"
  fi
fi
if [[ "$branch" != fase/* ]]; then
  echo "integração roda na branch da fase; esta é '${branch}'" >&2
  exit 1
fi

rebase_em_andamento() {
  [[ -d "$(git rev-parse --git-path rebase-merge)" || -d "$(git rev-parse --git-path rebase-apply)" ]]
}

worktree_da_branch() {
  local alvo="refs/heads/$1" wt="" br="" linha
  while IFS= read -r linha; do
    case "$linha" in
      worktree\ *) wt="${linha#worktree }" ;;
      branch\ *)
        br="${linha#branch }"
        if [[ "$br" == "$alvo" ]]; then
          printf '%s\n' "$wt"
          return 0
        fi
        ;;
    esac
  done < <(git worktree list --porcelain)
  return 1
}

trava_msg() {
  git fetch "$remote" refs/integracao/lock:refs/integracao/lock-vista >/dev/null 2>&1 || return 1
  git log -1 --format=%s refs/integracao/lock-vista
  git update-ref -d refs/integracao/lock-vista >/dev/null
}

adquirir_trava() {
  local empty commit err
  empty="$(git mktree </dev/null)"
  commit="$(git commit-tree "$empty" -m "lock ${id}")"
  err="$(mktemp)"
  if git push "$remote" "${commit}:refs/integracao/lock" >/dev/null 2>"$err"; then
    rm -f "$err"
    return 0
  fi
  local msg
  msg="$(trava_msg || true)"
  if [[ "$msg" == "lock ${id}" ]]; then
    rm -f "$err"
    return 0
  fi
  echo "trava ocupada por outra integração${msg:+: ${msg}}" >&2
  if [[ -s "$err" ]]; then
    cat "$err" >&2
  fi
  rm -f "$err"
  return 3
}

soltar_trava() {
  local msg
  msg="$(trava_msg || true)"
  if [[ -z "$msg" ]]; then
    return 0
  fi
  if [[ "$msg" != "lock ${id}" ]]; then
    echo "não solto trava alheia: ${msg}" >&2
    return 1
  fi
  git push --quiet "$remote" :refs/integracao/lock >/dev/null
}

if [[ $abortar -eq 1 ]]; then
  if rebase_em_andamento; then
    git rebase --abort
  fi
  soltar_trava
  echo "integração de ${id} abortada"
  exit 0
fi

if ! adquirir_trava; then
  exit 3
fi

resolver_um() {
  local f="$1" fase="$2"
  local base_tmp main_tmp phase_tmp
  base_tmp="$(mktemp)"
  main_tmp="$(mktemp)"
  phase_tmp="$(mktemp)"
  if ! git show ":1:${f}" >"$base_tmp" 2>/dev/null; then
    : >"$base_tmp"
  fi
  if ! git show ":2:${f}" >"$main_tmp" 2>/dev/null; then
    echo "sem a nossa versão de ${f}" >&2
    rm -f "$base_tmp" "$main_tmp" "$phase_tmp"
    return 1
  fi
  if ! git show ":3:${f}" >"$phase_tmp" 2>/dev/null; then
    echo "sem a versão da fase de ${f}" >&2
    rm -f "$base_tmp" "$main_tmp" "$phase_tmp"
    return 1
  fi
  if cmp -s "$main_tmp" "$phase_tmp"; then
    cp "$main_tmp" "$f"
    git add -- "$f"
    rm -f "$base_tmp" "$main_tmp" "$phase_tmp"
    return 0
  fi
  if [[ ! -s "$base_tmp" ]]; then
    echo "sem base comum em ${f}" >&2
    rm -f "$base_tmp" "$main_tmp" "$phase_tmp"
    return 1
  fi
  if ! integracao_resolver_ledger "$base_tmp" "$main_tmp" "$phase_tmp" "$fase" >"${f}.resolvido"; then
    rm -f "${f}.resolvido" "$base_tmp" "$main_tmp" "$phase_tmp"
    return 1
  fi
  mv "${f}.resolvido" "$f"
  git add -- "$f"
  rm -f "$base_tmp" "$main_tmp" "$phase_tmp"
}

resolver_rebase() {
  local fase="$1"
  local -a permitidos=(
    docs/CHANGELOG.md
    docs/history/SETUP-HISTORICO.md
    docs/DECISOES.md
    docs/ROADMAP.md
    docs/DEBITO-TECNICO.md
    docs/history/DEBITO-RESOLVIDO.md
    docs/SETUP.md
  )
  while rebase_em_andamento; do
    local -a conflitos=()
    mapfile -t conflitos < <(git diff --name-only --diff-filter=U || true)
    if [[ ${#conflitos[@]} -eq 0 ]]; then
      if ! GIT_EDITOR=true git rebase --continue; then
        if rebase_em_andamento && git diff --cached --quiet && [[ -z "$(git diff --name-only --diff-filter=U)" ]]; then
          GIT_EDITOR=true git rebase --skip || return 1
        elif rebase_em_andamento; then
          continue
        else
          return 1
        fi
      fi
      continue
    fi
    local ruim=0 f p ok
    for f in "${conflitos[@]}"; do
      ok=0
      for p in "${permitidos[@]}"; do
        if [[ "$f" == "$p" ]]; then
          ok=1
        fi
      done
      if [[ $ok -eq 0 ]]; then
        echo "conflito de lógica: ${f}" >&2
        echo "rebase parado. Resolva e rode de novo com --continuar, ou --abortar." >&2
        ruim=1
        continue
      fi
      if ! resolver_um "$f" "$fase"; then
        echo "conflito não trivial: ${f}" >&2
        echo "rebase parado. Resolva e rode de novo com --continuar, ou --abortar." >&2
        ruim=1
      fi
    done
    if [[ $ruim -eq 1 ]]; then
      return 4
    fi
    if ! GIT_EDITOR=true git rebase --continue; then
      if rebase_em_andamento; then
        continue
      fi
      echo "rebase --continue falhou" >&2
      return 1
    fi
  done
}

if ! git fetch --quiet "$remote" main; then
  echo "não consegui buscar ${remote} main" >&2
  exit 1
fi
git fetch "$remote" "+refs/heads/${branch}:refs/remotes/${remote}/${branch}" >/dev/null 2>&1 || true

rodar_resolver() {
  set +e
  resolver_rebase "$id"
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    exit "$rc"
  fi
}

if rebase_em_andamento; then
  rodar_resolver
elif ! git rebase "$base"; then
  if rebase_em_andamento; then
    rodar_resolver
  else
    echo "rebase em ${base} falhou sem deixar conflito" >&2
    exit 1
  fi
fi

if [[ -f docs/SETUP.md ]] && grep -q '^# F-' docs/SETUP.md; then
  echo "SETUP.md ainda tem spec; o fecho devolve o template vazio e commita antes de integrar" >&2
  exit 1
fi

fragmento="docs/changes/${id}.md"
if [[ -f "$fragmento" ]]; then
  if ! integracao_fragmento_tem_changelog "$fragmento"; then
    echo "fragmento de ${id} sem linha de changelog; o fecho preenche ## changelog antes de integrar" >&2
    exit 6
  fi
  paths_tmp="$(mktemp)"
  if ! integracao_aplicar_fragmento "$ROOT" "${ROOT}/${fragmento}" "$id" >"$paths_tmp"; then
    cat "$paths_tmp" >&2
    rm -f "$paths_tmp"
    exit 1
  fi
  mapfile -t paths <"$paths_tmp"
  rm -f "$paths_tmp"
  git add -- "${paths[@]}"
  if ! git diff --cached --quiet; then
    git commit -m "docs: consolida ${id}"
  fi
fi

if [[ -n "${INTEGRACAO_VALIDAR+x}" ]]; then
  if ! bash -c "$INTEGRACAO_VALIDAR"; then
    echo "validação falhou; não fiz merge. A trava continua com ${id}." >&2
    exit 5
  fi
elif [[ -f "${ROOT}/scripts/validar.sh" ]]; then
  if ! bash "${ROOT}/scripts/validar.sh"; then
    echo "validação falhou; não fiz merge. A trava continua com ${id}." >&2
    exit 5
  fi
else
  echo "sem scripts/validar.sh; não integro no escuro" >&2
  exit 5
fi

old=""
if git rev-parse --verify --quiet "${remote}/${branch}" >/dev/null; then
  old="$(git rev-parse "${remote}/${branch}")"
fi
if [[ -z "$old" ]]; then
  git push --quiet -u "$remote" HEAD
elif git merge-base --is-ancestor "$old" HEAD; then
  git push --quiet "$remote" HEAD
else
  git push --quiet --force-with-lease="refs/heads/${branch}:${old}" "$remote" "HEAD:refs/heads/${branch}"
fi

if [[ "${INTEGRACAO_SEM_GITHUB:-}" == 1 ]]; then
  main_wt="$(worktree_da_branch main)"
  if [[ -z "$main_wt" ]]; then
    echo "INTEGRACAO_SEM_GITHUB exige um worktree na main" >&2
    exit 1
  fi
  git -C "$main_wt" merge --quiet --ff-only "$branch"
  git -C "$main_wt" push --quiet "$remote" main
  git push "$remote" --delete "$branch" >/dev/null 2>&1 || true
else
  if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
    echo "gh sem autenticação; a branch está atualizada e a validação passou. Não fiz merge. A trava continua com ${id}." >&2
    exit 1
  fi
  numero="$(gh pr list --head "$branch" --base main --json number --jq '.[0].number')"
  if [[ -z "$numero" || "$numero" == "null" ]]; then
    titulo="${titulo:-${id}}"
    if [[ -n "$corpo" ]]; then
      gh pr create --base main --head "$branch" --title "$titulo" --body-file "$corpo"
    else
      gh pr create --base main --head "$branch" --title "$titulo" --body "Integração da ${id}. O que entrou e os critérios estão na spec da fase."
    fi
  fi
  checks="$(gh pr checks "$branch" 2>&1 || true)"
  if [[ "$checks" == *"no checks reported"* || "$checks" == *"No checks reported"* ]]; then
    echo "sem checks no PR; a validação local já passou" >&2
  elif ! gh pr checks "$branch" --watch --fail-fast; then
    echo "checks falharam; não fiz merge. A trava continua com ${id}." >&2
    exit 5
  fi
  gh pr merge --rebase --delete-branch "$branch"
  if main_wt="$(worktree_da_branch main)"; then
    git -C "$main_wt" pull --ff-only "$remote" main || true
  fi
fi

soltar_trava
echo "integrada: ${id}"

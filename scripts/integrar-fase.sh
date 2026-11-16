#!/usr/bin/env bash
# Integra uma fase no main, uma por vez (R-004, ADR-002), no bash 3.2 e pelo fecho comum (ADR-003):
#   1. pega a trava `refs/integracao/lock` no remoto (outra fase com ela: sai 3);
#   2. rebaseia a branch em `origin/main` e resolve o conflito trivial de ledger (o resto: sai 4, rebase parado);
#   3. aplica o fragmento da fase paralela nos ledgers (sem linha de changelog: sai 6);
#   4. roda `scripts/validar.sh` (falhou: sai 5, sem merge);
#   5. empurra a branch e abre o PR, se ainda não há;
#   6. o merge é do `scripts/fechar-pr.sh <pr> [--issue N]`, rodado do checkout principal — a única rota
#      de merge (PR que não integrou: sai 5, com a trava presa; falhou depois do merge: segue e sai 1);
#   7. com o PR `MERGED` conferido, solta a trava, tira o worktree e o branch local da fase a partir do
#      checkout principal e deixa o `main` local em dia;
#   8. roda o `scripts/conferir-fecho.sh`, do checkout principal (pendência: sai 1, já integrada; Amplug F-110).
# Em 4, 5 e 6 a trava fica com a fase.
#
# Uso, a partir do worktree da fase (paralela: a sessão no checkout principal roda
# `(cd <worktree> && scripts/integrar-fase.sh …)`, Amplug F-110) ou do checkout na branch dela (solitária):
#   scripts/integrar-fase.sh --id F-012 [--issue N] [--titulo T] [--corpo arquivo.md]
#   scripts/integrar-fase.sh --id F-012 --continuar [--issue N]
#   scripts/integrar-fase.sh --id F-012 --abortar
#
# Saídas: 0 integrou; 1 uso, branch ou git, ou integrou com pendência (trava já solta); 3 trava de
# outra fase; 4 conflito de lógica (rebase parado); 5 validação falhou ou o PR não integrou;
# 6 fragmento sem changelog.
# INTEGRACAO_VALIDAR, se definida, substitui scripts/validar.sh (teste).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/integracao.sh
source "${SCRIPT_DIR}/lib/integracao.sh"

id="" titulo="" corpo="" issue="" abortar=0
args_originais=("$@")
remote="${INTEGRACAO_REMOTE:-origin}"
base="${INTEGRACAO_BASE:-origin/main}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) id="${2:-}"; shift 2 ;;
    --titulo) titulo="${2:-}"; shift 2 ;;
    --corpo) corpo="${2:-}"; shift 2 ;;
    --issue) issue="${2:-}"; shift 2 ;;
    --abortar) abortar=1; shift ;;
    --continuar) shift ;;
    *)
      echo "argumento desconhecido: $1" >&2
      exit 1
      ;;
  esac
done
case "$issue" in *[!0-9]*) echo "--issue leva o número da issue" >&2; exit 1 ;; esac

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if [[ -z "$id" ]]; then
  registros="$(find docs/fases-ativas -maxdepth 1 -name 'F-*.md' 2>/dev/null || true)"
  if [[ -n "$registros" && "$(printf '%s\n' "$registros" | wc -l | tr -d ' ')" == 1 ]]; then
    id="$(basename "$registros" .md)"
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
# O --abortar também roda do checkout principal (Amplug F-104): sem branch da fase, só solta a trava dela.
if [[ "$branch" != fase/* && $abortar -eq 0 ]]; then
  echo "integração roda na branch da fase; esta é '${branch}'" >&2
  exit 1
fi

# O checkout principal: o primeiro da lista de worktrees (o repositório, não um worktree adicional).
principal="$(git worktree list --porcelain | sed -n '1s/^worktree //p')"

# A branch da fase pode ter o script de antes de uma correção no main, e o rebase troca o arquivo no
# disco, não o código que este processo já roda (a trava presa da Amplug F-105). Diferente do main: roda a
# versão do main, de uma cópia, com os mesmos argumentos (Amplug F-106).
if [[ -z "${INTEGRACAO_VERSAO_MAIN:-}" && "$branch" == fase/* ]]; then
  git fetch --quiet "$remote" main 2>/dev/null || true
  if git cat-file -e "${remote}/main:scripts/integrar-fase.sh" 2>/dev/null \
    && git cat-file -e "${remote}/main:scripts/lib/integracao.sh" 2>/dev/null; then
    if ! git show "${remote}/main:scripts/integrar-fase.sh" | cmp -s - "${SCRIPT_DIR}/integrar-fase.sh" \
      || ! git show "${remote}/main:scripts/lib/integracao.sh" | cmp -s - "${SCRIPT_DIR}/lib/integracao.sh"; then
      copia="$(mktemp -d)"
      git archive "${remote}/main" scripts | tar -x -C "$copia"
      echo "o integrar-fase.sh desta branch difere do ${remote}/main; rodo a versão do main" >&2
      INTEGRACAO_VERSAO_MAIN="$copia" exec bash "${copia}/scripts/integrar-fase.sh" ${args_originais[@]+"${args_originais[@]}"}
    fi
  fi
fi
# A marca do desvio não passa pros filhos: o `validar.sh` roda o teste deste script, que desvia de novo.
if [[ -n "${INTEGRACAO_VERSAO_MAIN:-}" ]]; then
  if [[ -d "$INTEGRACAO_VERSAO_MAIN" && "$SCRIPT_DIR" == "${INTEGRACAO_VERSAO_MAIN}/scripts" ]]; then
    copia_do_main="$INTEGRACAO_VERSAO_MAIN"
    trap 'rm -rf "$copia_do_main"' EXIT
  fi
  unset INTEGRACAO_VERSAO_MAIN
fi

rebase_em_andamento() {
  [[ -d "$(git rev-parse --git-path rebase-merge)" || -d "$(git rev-parse --git-path rebase-apply)" ]]
}

trava_msg() {
  git fetch "$remote" refs/integracao/lock:refs/integracao/lock-vista >/dev/null 2>&1 || return 1
  git log -1 --format=%s refs/integracao/lock-vista
  git update-ref -d refs/integracao/lock-vista >/dev/null
}

adquirir_trava() {
  local empty commit err msg
  empty="$(git mktree </dev/null)"
  commit="$(git commit-tree "$empty" -m "lock ${id}")"
  err="$(mktemp)"
  if git push "$remote" "${commit}:refs/integracao/lock" >/dev/null 2>"$err"; then
    rm -f "$err"
    return 0
  fi
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
  if [[ "$branch" == fase/* ]] && rebase_em_andamento; then
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

# Os ledgers e a spec: o conflito neles pode ser trivial. Qualquer outro arquivo é lógica.
e_ledger() {
  case "$1" in
    docs/CHANGELOG.md | docs/history/SETUP-HISTORICO.md | docs/DECISOES.md | docs/ROADMAP.md \
      | docs/DEBITO-TECNICO.md | docs/history/DEBITO-RESOLVIDO.md | docs/SETUP.md \
      | docs/reference/atritos.md) return 0 ;;
  esac
  return 1
}

resolver_rebase() {
  local fase="$1" conflitos f ruim
  while rebase_em_andamento; do
    conflitos="$(git diff --name-only --diff-filter=U || true)"
    if [[ -z "$conflitos" ]]; then
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
    ruim=0
    while IFS= read -r f; do
      [[ -n "$f" ]] || continue
      if ! e_ledger "$f"; then
        echo "conflito de lógica: ${f}" >&2
        ruim=1
        continue
      fi
      if ! resolver_um "$f" "$fase"; then
        echo "conflito não trivial: ${f}" >&2
        ruim=1
      fi
    done <<< "$conflitos"
    if [[ $ruim -eq 1 ]]; then
      echo "rebase parado. Resolva e rode de novo com --continuar, ou --abortar. A trava continua com ${fase}." >&2
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
  local rc
  set +e
  resolver_rebase "$id"
  rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    exit "$rc"
  fi
}

if rebase_em_andamento; then
  rodar_resolver
elif ! git rebase --quiet "$base"; then
  if rebase_em_andamento; then
    rodar_resolver
  else
    echo "rebase em ${base} falhou sem deixar conflito" >&2
    exit 1
  fi
fi

if [[ -f docs/SETUP.md ]] && grep -q '^# F-' docs/SETUP.md; then
  echo "SETUP.md ainda tem spec; o fecho devolve o SETUP vazio e commita antes de integrar" >&2
  exit 1
fi

fragmento="docs/changes/${id}.md"
if [[ -f "$fragmento" ]]; then
  if ! integracao_fragmento_tem_changelog "$fragmento"; then
    echo "fragmento de ${id} sem linha de changelog; o fecho preenche ## changelog antes de integrar. A trava continua com ${id}." >&2
    exit 6
  fi
  paths_tmp="$(mktemp)"
  if ! integracao_aplicar_fragmento "$ROOT" "${ROOT}/${fragmento}" "$id" >"$paths_tmp"; then
    cat "$paths_tmp" >&2
    rm -f "$paths_tmp"
    exit 1
  fi
  while IFS= read -r caminho; do
    [[ -n "$caminho" ]] && git add -- "$caminho"
  done <"$paths_tmp"
  rm -f "$paths_tmp"
  if ! git diff --cached --quiet; then
    git commit --quiet -m "docs: consolida ${id}"
  fi
fi

if [[ -n "${INTEGRACAO_VALIDAR+x}" ]]; then
  validar=(bash -c "$INTEGRACAO_VALIDAR")
elif [[ -f "${ROOT}/scripts/validar.sh" ]]; then
  validar=(bash "${ROOT}/scripts/validar.sh")
else
  echo "sem scripts/validar.sh; não integro no escuro" >&2
  exit 5
fi
if ! "${validar[@]}"; then
  echo "validação falhou; não fiz merge. A trava continua com ${id}." >&2
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
  # Só aqui, numa branch fase/* recém-rebaseada: o hook barra o push forçado na mão (R-004).
  git push --quiet --force-with-lease="refs/heads/${branch}:${old}" "$remote" "HEAD:refs/heads/${branch}"
fi

if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
  echo "gh sem autenticação; a branch está atualizada e a validação passou. Não fiz merge. A trava continua com ${id}." >&2
  exit 1
fi
numero="$(gh pr list --head "$branch" --base main --state open --json number --jq '.[0].number')"
if [[ -z "$numero" || "$numero" == "null" ]]; then
  titulo="${titulo:-${id}}"
  if [[ -n "$corpo" ]]; then
    gh pr create --base main --head "$branch" --title "$titulo" --body-file "$corpo" >/dev/null
  else
    gh pr create --base main --head "$branch" --title "$titulo" \
      --body "Integração da ${id}. O que entrou e os critérios estão em docs/history/fases/${id}.md." >/dev/null
  fi
  numero="$(gh pr list --head "$branch" --base main --state open --json number --jq '.[0].number')"
fi
if [[ -z "$numero" || "$numero" == "null" ]]; then
  echo "não achei o PR de ${branch} depois de criar. A trava continua com ${id}." >&2
  exit 1
fi
echo "PR #${numero} de ${branch}"

# O merge é do fecho comum (ADR-003), do checkout principal: espera os checks, põe em dia, integra
# com --rebase --delete-branch, fecha a issue e sincroniza o main local.
pendente=0
# Daqui em diante, do checkout principal: o `gh pr merge --delete-branch` do fecho comum tira o worktree
# da fase, e o `gh`/`git` seguinte com a pasta apagada cairia antes de soltar a trava (Amplug F-101, Amplug F-099; Amplug F-104).
cd "$principal"
if ! (bash "${SCRIPT_DIR}/fechar-pr.sh" "$numero" ${issue:+--issue "$issue"}); then
  # O fecho comum pode falhar depois do merge (issue, fetch, o ff-only do main num checkout sujo):
  # aí a fase já entrou, e prender a trava faria o --continuar abrir um PR novo.
  if [[ "$(gh pr view "$numero" --json state -q .state)" != MERGED ]]; then
    echo "o fecho comum do PR #${numero} falhou; não integrou. A trava continua com ${id}." >&2
    exit 5
  fi
  echo "o PR #${numero} entrou, mas o fecho comum falhou depois do merge; solto a trava e limpo — confira o resto à mão" >&2
  pendente=1
fi
estado="$(gh pr view "$numero" --json state -q .state)"
if [[ "$estado" != MERGED ]]; then
  echo "o PR #${numero} está ${estado}, não MERGED. A trava continua com ${id}." >&2
  exit 1
fi
soltar_trava

# A limpeza, do checkout principal: o worktree da fase (se o fecho comum já não tirou), o branch local e o
# remoto que sobrou, o main em dia.
git worktree prune
if [[ "$ROOT" != "$principal" ]] && git worktree list --porcelain | grep -qxF "worktree ${ROOT}"; then
  if ! git worktree remove "$ROOT"; then
    echo "não tirei o worktree ${ROOT} (sujo?); tire a partir do checkout principal" >&2
    pendente=1
  fi
fi
if [[ "$(git branch --show-current)" == "$branch" ]]; then
  git switch --quiet main
fi
git fetch --quiet --prune "$remote"
if git show-ref --verify --quiet "refs/heads/${branch}"; then
  git branch --quiet -D "$branch"   # o PR está MERGED (conferido acima): o rebase do GitHub refaz os SHAs
fi
if [[ -n "$(git ls-remote --heads "$remote" "refs/heads/${branch}")" ]]; then
  git push --quiet "$remote" --delete "$branch"
fi
if [[ "$(git branch --show-current)" == main ]]; then
  if ! git merge --quiet --ff-only "${remote}/main"; then
    echo "o main local não andou por fast-forward (o checkout principal tem mudança sem commit?): ponha em dia à mão" >&2
    pendente=1
  fi
elif ! git worktree list --porcelain | grep -qx 'branch refs/heads/main'; then
  git fetch --quiet "$remote" main:main || pendente=1
fi
if [[ $pendente -ne 0 ]]; then
  echo "integrada: ${id} (PR #${numero}), com pendência acima; confira com scripts/conferir-fecho.sh ${numero}${issue:+ --issue ${issue}}" >&2
  exit 1
fi
# A conferência do fecho, aqui mesmo e do checkout principal (Amplug F-110): a sessão da fase já não está no
# worktree que acabou de sair. A cópia do principal (o main em dia) primeiro; a deste processo, se faltar.
conferir="${principal}/scripts/conferir-fecho.sh"
[[ -f "$conferir" ]] || conferir="${SCRIPT_DIR}/conferir-fecho.sh"
if ! conferencia="$(bash "$conferir" "$numero" ${issue:+--issue "$issue"} 2>&1)"; then
  printf '%s\n' "$conferencia" >&2
  echo "integrada: ${id} (PR #${numero}), mas o conferir-fecho.sh acusou pendência acima" >&2
  exit 1
fi
echo "integrada: ${id} (PR #${numero}); conferir-fecho: ${conferencia}"

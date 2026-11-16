#!/usr/bin/env bash
# O `gh` falso dos testes do fecho comum (`fechar-pr.test.sh`, `conferir-fecho.test.sh`) e da integração
# (`integrar-fase.test.sh`): o teste o instala como `gh` num PATH próprio. O estado mora em `$GH_ESTADO` (um arquivo por campo) e cada chamada
# vai pra `$GH_ESTADO/log`. O `pr merge` faz no `origin` (um repositório bare) o que o GitHub faria.
set -euo pipefail
e=${GH_ESTADO:?}
echo "gh $*" >> "$e/log"
# O gh de verdade não roda com a pasta atual apagada (Amplug F-104): o mesmo aqui.
pwd -P > /dev/null 2>&1 || { echo "failed to run git: fatal: Unable to read current working directory" >&2; exit 1; }
ler() { cat "$e/$1"; }
# O valor da opção `$1` nos argumentos que seguem.
opcao() { local o=$1; shift; while [ $# -gt 0 ]; do [ "$1" = "$o" ] && { echo "${2:-}"; return; }; shift; done; }
case "$1 ${2:-}" in
  "auth status") ;;
  "pr list")
    # Um PR por vez: o aberto da branch pedida, senão nada (o `--jq` do chamador já viria resolvido).
    if [ -s "$e/branch" ] && [ "$(ler branch)" = "$(opcao --head "$@")" ] && [ "$(ler pr_state 2> /dev/null)" = OPEN ]; then
      ler pr_num 2> /dev/null || echo 7
    fi ;;
  "pr create")
    n=$(( $(ler pr_num 2> /dev/null || echo 6) + 1 )); echo "$n" > "$e/pr_num"
    opcao --head "$@" > "$e/branch"; echo OPEN > "$e/pr_state"; echo CLEAN > "$e/merge_state"
    echo "https://github.com/falso/repo/pull/$n" ;;
  "pr view")
    case "$*" in
      *"--json state,headRefName"*) echo "$(ler pr_state) $(ler branch)" ;;
      *"--json state"*) ler pr_state ;;
      *mergeStateStatus*)
        if [ -s "$e/unknown" ] && [ "$(ler unknown)" -gt 0 ]; then echo $(($(ler unknown) - 1)) > "$e/unknown"; echo UNKNOWN; else ler merge_state; fi ;;
      *headRefOid*) ler head ;;
      *) exit 1 ;;
    esac ;;
  "pr checks")
    if [ -s "$e/checks_sem" ]; then
      n=$(ler checks_sem); echo $((n - 1)) > "$e/checks_sem"
      [ "$n" -le 1 ] && : > "$e/checks_sem"
      echo "no checks reported on the '$(ler branch)' branch" >&2; exit 1
    fi
    echo "CI	pass"; exit "$(ler checks_rc)" ;;
  "pr update-branch")
    echo CLEAN > "$e/merge_state"; echo "${RANDOM}novo" > "$e/head" ;;
  "pr merge")
    if [ -s "$e/merge_recusa" ] && [ "$(ler merge_recusa)" -gt 0 ]; then
      echo $(($(ler merge_recusa) - 1)) > "$e/merge_recusa"; echo "Required status check \"CI\" is expected." >&2; exit 1
    fi
    b=$(ler branch)
    git push -q origin "refs/remotes/origin/$b:refs/heads/main" 2> /dev/null || git push -q origin "$b:main"
    git push -q origin --delete "$b"
    if [ "$(git branch --show-current)" = "$b" ]; then git switch -q main; git branch -q -D "$b"; fi
    echo MERGED > "$e/pr_state"
    # O gh 2.104 tira o worktree da branch apagada pelo --delete-branch (o fecho da Amplug F-101): `tira_worktree` diz qual.
    if [ -s "$e/tira_worktree" ]; then git worktree remove --force "$(ler tira_worktree)"; : > "$e/tira_worktree"; fi
    if [ -s "$e/merge_meio" ]; then : > "$e/merge_meio"; echo "failed to delete local branch" >&2; exit 1; fi ;;
  "issue view") ler issue_state ;;
  "issue close") echo CLOSED > "$e/issue_state" ;;
  *) echo "gh falso: sem $*" >&2; exit 1 ;;
esac

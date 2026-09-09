#!/bin/bash
# Testa o guardrail de git destrutivo alimentando o JSON do evento PreToolUse por stdin.
# Nasceu com a correção do D-001 (o padrão casava em qualquer ponto da cláusula).
set -euo pipefail
HOOK="$(cd "$(dirname "$0")" && pwd)/block-dangerous-git.sh"

rodar() {
  printf '%s' "{\"tool_input\":{\"command\":$(printf '%s' "$1" | jq -Rs .)}}" | bash "$HOOK"
  echo $?
}

falhou=0
espera() {
  local cmd="$1" saida="$2" desc="$3"
  local got
  got="$(rodar "$cmd" 2>/dev/null || true)"
  if [ "$got" != "$saida" ]; then
    echo "FALHOU: $desc — esperado exit $saida, veio $got (cmd: $cmd)" >&2
    falhou=1
  fi
}

# o destrutivo de verdade é barrado
espera 'git push --force' 2 'push --force é barrado'
espera 'git push -f origin main' 2 'push -f é barrado'
espera 'git push --force-with-lease' 2 'push --force-with-lease é barrado'
espera 'git reset --hard' 2 'reset --hard é barrado'
espera 'git clean -f' 2 'clean -f é barrado'
espera 'git clean -fdx' 2 'clean -fdx é barrado'
espera 'git branch -D foo' 2 'branch -D é barrado'

# D-001: citar o literal não é executá-lo — a âncora no início da cláusula
espera 'echo git push --force' 0 'echo que só cita o literal passa'
espera 'grep -rn "git reset --hard" docs/' 0 'grep pelo literal passa'
espera 'echo "nunca rode git clean -f"' 0 'aviso citando o literal passa'

# opção global não esconde o subcomando: `git -C <dir>` e `git -c <k=v>` casam
espera 'git -C /tmp/repo push --force' 2 'push --force com -C é barrado'
espera 'git -C /tmp/repo reset --hard' 2 'reset --hard com -C é barrado'
espera 'git -c core.editor=true push --force' 2 'push --force com -c é barrado'

# comando composto: a cláusula depois de && também é inspecionada
espera 'cd foo && git push --force origin main' 2 'push --force depois de && é barrado'
espera 'git status; git clean -fd' 2 'clean -fd depois de ; é barrado'

# o legítimo passa
espera 'git status' 0 'status passa'
espera 'git push origin main' 0 'push normal passa'
espera 'git clean -n' 0 'clean --dry-run passa'
espera 'git branch -d foo' 0 'branch -d (minúsculo, seguro) passa'
espera 'git reset HEAD~1' 0 'reset sem --hard passa'

if [ "$falhou" -ne 0 ]; then
  exit 1
fi
echo 'ok'

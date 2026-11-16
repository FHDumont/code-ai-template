#!/bin/bash
# Testa o guardrail dos comandos do dono alimentando o JSON do evento PreToolUse
# por stdin — mesmo molde do `block-dangerous-git.sh`.
#
# Cobre o que vem LIGADO no template (o `git add` cego) e prova que os exemplos
# comentados estão de fato inertes. Ao descomentar um exemplo no hook, mova o
# caso correspondente da seção "exemplos desligados" pra cima, com exit 2.
set -euo pipefail
HOOK="$(cd "$(dirname "$0")" && pwd)/block-comandos-do-dono.sh"

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

# git add cego — a regra universal, ligada por padrão
espera 'git add -A' 2 'git add -A é barrado'
espera 'git add --all' 2 'git add --all é barrado'
espera 'git add .' 2 'git add . é barrado'
espera 'git add docs/SETUP.md' 0 'git add por caminho explícito passa'
espera 'git status' 0 'git status passa'

# echo que só cita o literal passa (âncora no início da cláusula)
espera 'echo git add -A' 0 'echo que só cita o literal passa'

# comando composto
espera 'echo ok && git add -A' 2 'git add -A depois de && é barrado'
espera 'git status; git add -A' 2 'git add -A depois de ; é barrado'
espera 'cd web && git add src/foo.ts' 0 'composto sem comando barrado passa'

# separador dentro de aspas não abre cláusula nova
espera "cat > t.sh <<'EOF'" 0 'heredoc de arquivo passa'
espera "printf '%s' 'git status; git add -A' > /tmp/t" 0 'literal citado entre aspas não abre cláusula'
espera 'grep -rn "git add -A" docs/' 0 'grep pelo literal entre aspas passa'

# corpo de heredoc é dado, não comando
espera 'cat > /tmp/x.md <<EOF
git add -A
EOF' 0 'git add -A dentro do corpo de heredoc passa'
espera 'cat > /tmp/x.md <<-EOF
	git add -A
	EOF' 0 'heredoc <<- indentado passa'
espera 'echo oi
git add -A' 2 'script multilinha de verdade continua barrado'
espera 'cat > /tmp/x.md <<EOF
texto
EOF
git add -A' 2 'comando depois do heredoc fechado continua barrado'

# só conta como heredoc o que FECHA, e <<< / # / << aritmético não abrem
espera 'echo "escreva <<EOF assim"
git add -A' 2 'marca citada dentro de string não engole o resto'
# shellcheck disable=SC2016 # o comando é texto pro hook, não pra este shell
espera 'X=$((1 << N))
git add -A' 2 'shift aritmético não abre heredoc'
espera '# usa <<EOF
git add -A' 2 'comentário não abre heredoc'
espera 'grep foo <<<"bar"
git add -A' 2 'here-string não abre heredoc'
espera 'cat > /tmp/x <<EOF
texto
git add -A' 2 'marca que nunca fecha não engole o resto'
espera "cat > /tmp/x <<'END-OF'
texto
END-OF
git add -A" 2 'marca com hífen fecha, e o comando depois é barrado'
espera "cat > /tmp/x <<'END-OF'
git add -A
END-OF" 0 'marca com hífen: o corpo continua sendo dado'

# exemplos desligados — ficam inertes até serem descomentados no hook
espera 'pnpm format' 0 'exemplo (1) formatador está comentado'
espera './scripts/lab.sh up' 0 'exemplo (2) ambiente local está comentado'
espera 'pnpm --filter db seed --force' 0 'exemplo (3) seed --force está comentado'

if [ "$falhou" -ne 0 ]; then
  exit 1
fi
echo 'ok'

#!/bin/bash
# Testa o guardrail alimentando o JSON do evento PreToolUse por stdin .
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

espera 'echo git push --force' 0 'echo que só cita o literal passa'
espera 'git push --force' 2 'push --force de verdade é barrado'
espera 'git reset --hard' 2 'reset --hard é barrado'
espera 'git clean -f' 2 'clean -f é barrado'
espera 'git branch -D foo' 2 'branch -D é barrado'
espera 'git status' 0 'status passa'
espera 'cd foo && git push --force origin main' 2 'push --force depois de && é barrado'

# opção global não esconde o subcomando: com a âncora crua, `git -C <dir> push --force`
# escapava inteiro (o bloco do commit já lê o -C)
espera 'git -C /tmp/repo push --force' 2 'push --force com -C é barrado'
espera 'git -C /tmp/repo reset --hard' 2 'reset --hard com -C é barrado'
espera 'git -c core.editor=true push --force' 2 'push --force com -c é barrado'
espera 'git -C /tmp/repo status' 0 'status com -C passa'

# separador dentro de aspas não abre cláusula, e corpo de heredoc é dado, não comando
# (a mesma classe que o block-comandos-do-dono.sh fechou; aqui ela só apareceu quando
# o -C passou a casar, e barrava o arquivo que escreve estes próprios casos)
espera 'grep -rn "git push --force" docs/' 0 'grep pelo literal entre aspas passa'
espera "printf '%s' 'a; git push --force' > /tmp/t" 0 'literal citado não abre cláusula'
espera 'cat > /tmp/x.sh <<EOF
git push --force
EOF' 0 'corpo de heredoc é dado'
espera 'cat > /tmp/x.sh <<EOF
texto
EOF
git push --force' 2 'comando depois do heredoc fechado é barrado'
espera 'echo oi
git reset --hard' 2 'script multilinha de verdade é barrado'
espera 'grep foo <<<"bar"
git push --force' 2 'here-string não abre heredoc'

# A mensagem do push forçado aponta a rota da integração (Amplug F-098).
msg="$(printf '%s' '{"tool_input":{"command":"git push --force-with-lease origin fase/F-1-x"}}' | bash "$HOOK" 2>&1 || true)"
case "$msg" in
  *scripts/integrar-fase.sh*) ;;
  *) echo "FALHOU: a mensagem do push forçado não aponta o integrar-fase.sh" >&2; falhou=1 ;;
esac

# A sessão da fase paralela nasce no checkout principal (no `main`) e trabalha no worktree (Amplug F-110): o commit
# é julgado pelo branch do repo em que roda — `cd <wt>`, `git -C <wt>` ou o `cwd` do evento —, não pelo do
# projeto da sessão. Antes, o `cd "<wt>"` com aspas perdia o alvo (barrava o worktree) e o `git -C "<main>"`
# não achava repo nenhum (deixava o main passar).
TMPG="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMPG"' EXIT
principal="$TMPG/principal" wt="$TMPG/fases/F-1"
git init -q -b main "$principal"
git -C "$principal" -c user.name=t -c user.email=t@t commit -q --allow-empty -m base
git -C "$principal" worktree add -q -b fase/F-1-x "$wt"
rodar_em() { # <cmd> <cwd do evento> — o projeto da sessão é sempre o checkout principal
  printf '%s' "{\"cwd\":$(printf '%s' "$2" | jq -Rs .),\"tool_input\":{\"command\":$(printf '%s' "$1" | jq -Rs .)}}" |
    CLAUDE_PROJECT_DIR="$principal" bash "$HOOK"
  echo $?
}
espera_em() {
  local cmd="$1" cwd="$2" saida="$3" desc="$4" got
  got="$(rodar_em "$cmd" "$cwd" 2>/dev/null || true)"
  if [ "$got" != "$saida" ]; then
    echo "FALHOU: $desc — esperado exit $saida, veio $got (cmd: $cmd, cwd: $cwd)" >&2
    falhou=1
  fi
}
espera_em "cd $wt && git commit -m x" "$principal" 0 'cd no worktree: commit na fase passa'
espera_em "cd \"$wt\" && git commit -m \"docs: x\"" "$principal" 0 'cd entre aspas no worktree: commit na fase passa'
espera_em "git -C \"$wt\" commit -m x" "$principal" 0 'git -C entre aspas no worktree passa'
espera_em "(cd $wt && git commit -m x)" "$principal" 2 'subshell com cd e o main ao alcance é barrado (alvo incerto)'
espera_em "(git -C $wt commit -m x)" "$principal" 0 'subshell com -C literal no worktree passa'
espera_em "cd ../fases/F-1 && git commit -m x" "$principal" 0 'cd relativo ao cwd do comando passa'
espera_em 'git commit -m x' "$wt" 0 'o cwd do evento no worktree passa'
espera_em 'git commit -m x' "$principal" 2 'commit no main da sessão continua barrado'
espera_em "git -C \"$principal\" commit -m x" "$wt" 2 'git -C entre aspas no main é barrado'
espera_em "cd \"$principal\" && git commit -m x" "$wt" 2 'cd entre aspas no main é barrado'
espera_em 'git -C ../../principal commit -m x' "$wt" 2 'git -C relativo ao cwd, no main, é barrado'
# Alvo que o hook não resolve (variável, `$(…)`, literal com espaço) não vira pasta inexistente: o commit é
# julgado pelo cwd do comando (revisão de fecho da Amplug F-110: `cd "$CLAUDE_PROJECT_DIR" && git commit` passava).
# shellcheck disable=SC2016 # o $ é do comando avaliado pelo hook, não daqui
espera_em 'cd "$CLAUDE_PROJECT_DIR" && git commit -m x' "$principal" 2 'cd com variável, no main, é barrado'
# shellcheck disable=SC2016
espera_em 'cd "$(git rev-parse --show-toplevel)" && git commit -m x' "$principal" 2 'cd com $(…), no main, é barrado'
# shellcheck disable=SC2016
espera_em 'git -C "$CLAUDE_PROJECT_DIR" commit -m x' "$principal" 2 'git -C com variável, no main, é barrado'
espera_em "cd $TMPG/nao-existe && git commit -m x" "$principal" 2 'cd pra pasta que não existe cai no cwd do main'
# shellcheck disable=SC2016
espera_em 'cd "$CLAUDE_PROJECT_DIR" && git commit -m x' "$wt" 2 'cd na variável do projeto, do cwd no worktree, é barrado'
# shellcheck disable=SC2016
espera_em "cd $wt && git -C \"\$CLAUDE_PROJECT_DIR\" commit -m x" "$principal" 2 'git -C na variável do projeto depois do cd no worktree é barrado'
# shellcheck disable=SC2016
espera_em 'cd "$X" && git commit -m x' "$wt" 2 'cd com alvo incerto e o main ao alcance é barrado'
# shellcheck disable=SC2016
espera_em "cd \"\$X\" && cd $wt && git commit -m x" "$principal" 0 'cd absoluto depois do incerto zera a dúvida'
espera_em "cd $wt; cd nao-existe; git commit -m x" "$principal" 0 'cd que falha deixa o diretório no worktree'
espera_em "cd $principal; cd nao-existe; git commit -m x" "$wt" 2 'cd que falha deixa o diretório no main'
# A terceira passada: variável só pelo nome inteiro, `-C` só de opção global, `{ … }`, `builtin` e `pushd`.
# shellcheck disable=SC2016
espera_em 'cd $PWD_FASE && git commit -m x' "$wt" 2 'variável com prefixo conhecido continua incerta'
# shellcheck disable=SC2016
espera_em "cd $wt && git commit --amend -C \"\$SHA\"" "$principal" 0 'o -C do próprio commit não é alvo'
espera_em "cd $wt && git commit -m \"fix: git -C \$X barrado
corpo\"" "$principal" 0 '-C dentro da mensagem não é alvo'
espera_em "{ cd $principal; git commit -m x; }" "$wt" 2 'cd dentro de chaves, no main, é barrado'
espera_em "builtin cd $principal && git commit -m x" "$wt" 2 'builtin cd no main é barrado'
espera_em "pushd $principal && git commit -m x" "$wt" 2 'pushd no main é barrado'
espera_em "pushd $wt && git commit -m x" "$principal" 0 'pushd no worktree passa'
espera_em "( { cd $principal; git commit -m x; } )" "$wt" 2 'agrupamento aninhado no main é barrado'
# O `cd` de dentro de `( … )` acaba na subshell (a quinta passada: vazava pras cláusulas seguintes).
espera_em "( cd $wt ); git commit -m x" "$principal" 2 'cd na subshell não vaza: o commit fora dela é no main'
espera_em "(cd $wt) && git commit -m x" "$principal" 2 'cd na subshell não vaza, com &&'
espera_em "( ( cd $wt ) ) ; git commit -m x" "$principal" 2 'cd na subshell aninhada não vaza'
espera_em "( cd $wt && git status ) ; git commit -m x" "$principal" 2 'cd no meio da subshell não vaza'
espera_em "( cd $principal ); git commit -m x" "$wt" 2 'subshell deixa o alvo incerto, com o main ao alcance'
espera_em "{ cd $wt; }; git commit -m x" "$principal" 0 'cd na chave continua valendo'
# A sexta passada: o redirecionamento depois do `)` escondia o fim da subshell.
espera_em "( cd $wt ) 2>/dev/null; git commit -m x" "$principal" 2 'subshell com redirecionamento não vaza'
espera_em "cd $wt; ( true ) 2>/dev/null; cd $principal; echo \$(pwd); git commit -m x" "$principal" 2 'cd real depois da subshell vale'
espera_em "cd $wt | cat; git commit -m x" "$principal" 2 'cd numa ponta do pipe não vale pro commit'
espera_em "cd $wt && git log --oneline | head -1 && git commit -m x" "$principal" 0 'pipe sem cd numa ponta não deixa o commit incerto'
espera_em "cd $wt && git commit -m x 2>&1 | tail -5" "$principal" 0 'commit com a saída no pipe, no worktree, passa'
espera_em 'git commit -m x 2>&1 | tail -3' "$wt" 0 'commit com pipe e o cwd no worktree passa'
espera_em "cd $wt && git commit -m \"a | b
c (d)\"" "$principal" 0 'mensagem multilinha com pipe e parêntese no worktree passa'
espera_em "pushd $wt; popd; git commit -m x" "$principal" 2 'popd volta pra onde o hook não acompanha: incerto'
espera_em "cd $wt; cd -; git commit -m x" "$principal" 2 'cd - é incerto'
espera_em "cd $wt; cd; git commit -m x" "$principal" 2 'cd sem argumento é incerto'
espera_em "cd $wt 2>&1 | cat; git commit -m x" "$principal" 2 'cd no pipe com 2>&1 continua incerto'
espera_em "cd $wt &>/dev/null | cat; git commit -m x" "$principal" 2 'cd no pipe com &> continua incerto'
espera_em "cd $wt \\
| cat; git commit -m x" "$principal" 2 'cd no pipe com continuação de linha continua incerto'
espera_em "cd $wt && git commit -m x 2>&1 | tail -3" "$principal" 0 'commit com 2>&1 no pipe, no worktree, passa'
espera_em "cd $wt | cat; git commit -m x \\" "$principal" 2 'barra no fim do comando não some com o cd do pipe'
espera_em "cd $wt && git commit -m \"\$(cat <<'EOF'
docs: x (y)

corpo
EOF
)\"" "$principal" 0 'commit com mensagem por heredoc no worktree passa'
espera_em "cd $wt && git status || true; git commit -m x" "$principal" 0 'o || não é pipe'
# Um cwd com quebra de linha não pode desligar as guardas (a quarta passada: o sed do expandir caía).
mkdir -p "$TMPG/com
quebra"
espera_em 'git push --force' "$TMPG/com
quebra" 2 'cwd com quebra de linha não desliga o push forçado'

if [ "$falhou" -ne 0 ]; then
  exit 1
fi
echo 'ok'

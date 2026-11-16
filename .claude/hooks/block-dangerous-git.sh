#!/bin/bash
# PreToolUse hook (Bash): bloqueia comandos git destrutivos antes de executar.
# Transforma AGENTS.md §Git em guardrail duro. Ver ali as regras completas.
#
# Protocolo do hook: lê o JSON do evento no stdin, extrai .tool_input.command,
# casa contra os padrões abaixo. Em caso de match: mensagem em stderr + exit 2
# (Claude Code bloqueia a chamada e mostra o stderr ao agente). Sem match: exit 0.

INPUT=$(cat)

# Sem jq não dá pra parsear o evento — não trava o agente por isso.
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
# O diretório em que o comando roda (o shell da sessão guarda o `cd` entre chamadas). A sessão da fase
# paralela nasce no checkout principal (no `main`) e trabalha no worktree (Amplug F-110): o alvo do commit é o
# repo do comando, não o projeto da sessão.
SESSAO_DIR=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

block() {
  # $1 = o que foi barrado + regra; $2 = rota certa
  {
    echo "BLOQUEADO pelo guardrail de git (AGENTS.md §Git): $1"
    echo
    echo "Comando: $COMMAND"
    echo
    echo "Rota certa: $2"
  } >&2
  exit 2
}

# Verifica se a cláusula **começa** com git + subcomando ($2, ex.: "push", "reset"),
# tolerando as opções globais que mudam o alvo sem mudar o comando (`git -C <dir>`,
# `git -c <k=v>`) — o bloco do commit abaixo já lê o `-C`, então ele precisa casar aqui.
# Âncora no início: um `echo` que só cita o literal não casa.
has_subcmd() {
  printf '%s' "$1" | grep -Eq "^git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+$2([[:space:]]|\$)"
}

# Verifica se $1 contém a flag regex $2 (já com âncoras de fronteira embutidas).
has_flag() {
  printf '%s' "$1" | grep -Eq -- "$2"
}

# O corpo de um heredoc é DADO, não comando: `cat > x <<EOF` com uma linha
# `git add -A` dentro escreve texto, não roda git. Como a quebra de linha também
# separa cláusula (num script multilinha há um comando por linha, e esse a gente
# quer inspecionar), o corpo do heredoc sai antes de partir.
#
# Duas guardas contra engolir comando de verdade (achado numa revisão de fecho do Vaulty):
# só conta como abertura o que **fecha** — marca sem linha de fechamento não
# descarta nada —, e `<<<` (here-string), `#` (comentário) e o `<<` aritmético não
# abrem heredoc. \047 é a aspa simples, que não pode aparecer literal dentro do awk.
CLAUSULAS="$(printf '%s' "$COMMAND" | awk '
  { linha[NR] = $0 }
  END {
    i = 1
    while (i <= NR) {
      l = linha[i]
      print l
      marca = ""
      sem_herestring = l
      gsub(/<<</, "\001", sem_herestring)
      if (sem_herestring !~ /^[ \t]*#/ &&
          match(sem_herestring, /<<-?[ \t]*("[^"]+"|\047[^\047]+\047|[A-Za-z_][A-Za-z0-9_.-]*)/)) {
        m = substr(sem_herestring, RSTART, RLENGTH)
        gsub(/^<<-?[ \t]*/, "", m)
        gsub(/["\047]/, "", m)
        marca = m
      }
      if (marca != "") {
        fecha = 0
        for (j = i + 1; j <= NR; j++) {
          t = linha[j]
          sub(/^[ \t]+/, "", t)
          sub(/[ \t]+$/, "", t)
          if (t == marca) { fecha = j; break }
        }
        if (fecha > 0) { i = fecha + 1; continue }
      }
      i++
    }
  }
')"

# Literal entre aspas é dado: sai antes de partir as cláusulas. Exceção, um caminho ou palavra simples
# (`cd "/x/repo-fases/F-1"`, `git -C '/x'`): sem espaço nem separador, a aspa só é tirada — apagado,
# o `cd` perdia o alvo e o commit no worktree era julgado pelo branch do projeto da sessão (Amplug F-110).
# As variáveis que o hook conhece viram o valor antes disso, pra `cd "$CLAUDE_PROJECT_DIR"` ter alvo.
# Só o nome inteiro: `$HOME_X` é outra variável e continua incerta.
expandir() { # <nome> <valor>
  # Valor com quebra de linha não expande (o `sed` cairia e as guardas todas com ele): fica incerto.
  local valor novo
  [ -n "$2" ] || return 0
  case "$2" in *$'\n'*) return 0 ;; esac
  valor="$(printf '%s' "$2" | sed 's/[#&\\]/\\&/g')" || return 0
  novo="$(printf '%s' "$CLAUSULAS" | sed -E "s#\\\$\\{$1\\}#${valor}#g; s#\\\$$1([^A-Za-z0-9_]|\$)#${valor}\\1#g")" &&
    CLAUSULAS="$novo"
}
expandir CLAUDE_PROJECT_DIR "$CLAUDE_PROJECT_DIR"
expandir HOME "$HOME"
expandir PWD "$SESSAO_DIR"
CLAUSULAS="$(printf '%s' "$CLAUSULAS" | sed -E "s/'([A-Za-z0-9_.\/~:@+=-]*)'/\1/g; s/\"([A-Za-z0-9_.\/~:@+=-]*)\"/\1/g")"
CLAUSULAS="$(printf '%s' "$CLAUSULAS" | sed -E "s/'[^']*'/''/g; s/\"[^\"]*\"/\"\"/g")"

REPO_DIR=""
# 1 depois de um `cd` cujo alvo o hook não sabe (literal apagado `""`, `$VAR`, `$(…)`, crase).
INCERTO=0

# Caminho relativo de `cd`/`-C` é relativo ao diretório corrente: o do `cd` anterior, senão o do comando.
# Alvo que não dá pra saber daqui sai vazio. O commit com alvo incerto é barrado se o `main` está ao
# alcance (o `cd` anterior, o `cwd` do comando ou o projeto): com a sessão no checkout principal, um
# `cd "$X" && git commit` pode cair nele (revisão de fecho da Amplug F-110). Use o caminho literal.
resolver() {
  local d="${1/#\~/$HOME}" base
  case "$d" in
    '' | *'"'* | *"'"* | *'$'* | *'`'*) return 0 ;;
    /*) printf '%s' "$d" ;;
    *)
      base="${REPO_DIR:-${SESSAO_DIR:-${CLAUDE_PROJECT_DIR:-$(pwd)}}}"
      printf '%s/%s' "$base" "$d"
      ;;
  esac
}
DESTRUTIVA="operação destrutiva: peça confirmação ao dono (AGENTS.md §Quando pedir confirmação)."

# Comandos compostos (&&, ;, |, ||) são inspecionados cláusula a cláusula, pra
# não deixar um --force plantado num subcomando errado escapar da checagem
# nem vazar pra um subcomando que não seja o dele.
# Subshell e pipe: o `cd` de dentro de `( … )` ou de uma ponta do pipe acaba ali, e um redirecionamento ou
# `$(…)` no meio confunde qualquer contagem de parênteses (revisão de fecho da Amplug F-110). Em vez de contar, a
# regra é a segura, e só pro `cd`: depois que uma subshell abriu no comando, ou com um `cd` numa ponta de
# pipe, o `cd` não muda o alvo — deixa-o incerto (barrado com o `main` ao alcance, salvo `git -C <literal>`).
# O commit em si, com pipe na saída ou sem `cd` em grupo, não fica incerto.
SUBSHELL=0
CD_NO_PIPE=0
# Pra esse teste, o `&` de redirecionamento (`2>&1`, `&>`) não separa, e a continuação `\` junta as linhas.
# (`$!` no `N`: no BSD sed, `N` na última linha sai sem imprimir e o comando sumia.)
SEM_REDIR="$(printf '%s' "$CLAUSULAS" | sed -E ':a
/\\$/{
$!{N
s/\\\n/ /
ba
}
}
s/[0-9]*>&[0-9-]*/ /g; s/&>>?/ /g')" || SEM_REDIR=""
[ -n "$SEM_REDIR" ] || SEM_REDIR="$CLAUSULAS"
if printf '%s' "$SEM_REDIR" | grep -Eq '(^|[;&(])[[:space:]]*(cd|pushd|popd)([[:space:]][^;&|]*)?\|([^|]|$)|(^|[^|])\|[[:space:]]*(cd|pushd|popd)([[:space:]]|$)'; then
  CD_NO_PIPE=1
fi
while IFS= read -r seg; do
  # Cláusula que abre subshell (`(` no começo; `$(` não conta).
  case "$seg" in
    *'('*) printf '%s' "$seg" | grep -Eq '^[[:space:]{]*\(' && SUBSHELL=1 ;;
  esac
  # `( cd x && git … )` e `{ cd x; git …; }` agrupam: o parêntese e a chave não mudam o comando, nem o
  # `builtin` na frente do `cd`.
  seg="$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^([({][[:space:]]*)+//; s/([[:space:]]*[)}])+$//; s/^builtin[[:space:]]+//')"
  [ -z "$seg" ] && continue

  # git push --force / -f / --force-with-lease
  if has_subcmd "$seg" "push" && has_flag "$seg" '(^|[[:space:]])(--force(-with-lease)?|-f)([[:space:]]|$)'; then
    block "push forçado (reescreve história publicada)." "a branch da fase se atualiza com o main por \`scripts/integrar-fase.sh --id F-xxx\` (o único \`--force-with-lease\`, só em \`fase/*\` depois do rebase, R-004); fora disso, $DESTRUTIVA"
  fi

  # git reset --hard
  if has_subcmd "$seg" "reset" && has_flag "$seg" '(^|[[:space:]])--hard([[:space:]]|$)'; then
    block "git reset --hard." "$DESTRUTIVA"
  fi

  # git clean -f / -fd / -fdx / -df / --force (mas não --dry-run, -n)
  if has_subcmd "$seg" "clean" && has_flag "$seg" '(^|[[:space:]])(-[a-zA-Z]*f[a-zA-Z]*|--force)([[:space:]]|$)'; then
    block "git clean com force (apaga arquivos não versionados sem confirmação)." "$DESTRUTIVA"
  fi

  # git branch -D
  if has_subcmd "$seg" "branch" && has_flag "$seg" '(^|[[:space:]])-D([[:space:]]|$)'; then
    block "git branch -D." "a limpeza de branch do fecho é \`gh pr merge --rebase --delete-branch\`, que apaga remota e local; para descartar uma branch não mergeada, peça ao dono."
  fi

  # Um `cd <dir>` (ou `pushd`) numa cláusula anterior muda o repo-alvo das cláusulas seguintes.
  # `popd`, `cd -` e `cd` sem argumento voltam pra um lugar que o hook não acompanha: incerto.
  if printf '%s' "$seg" | grep -Eq '^(popd|cd|pushd)([[:space:]]+-)?([[:space:]]|$)' &&
    ! printf '%s' "$seg" | grep -Eq '^(cd|pushd)[[:space:]]+[^-[:space:]]'; then
    INCERTO=1
  elif [ "$SUBSHELL" = 1 ] || [ "$CD_NO_PIPE" = 1 ]; then
    printf '%s' "$seg" | grep -Eq '^(cd|pushd)[[:space:]]' && INCERTO=1
  elif printf '%s' "$seg" | grep -Eq '^(cd|pushd)[[:space:]]+[^[:space:]]+'; then
    CD_ARG="$(printf '%s' "$seg" | sed -E 's/^(cd|pushd)[[:space:]]+//; s/[[:space:]].*$//')"
    CD_ALVO="$(resolver "$CD_ARG")"
    if [ -z "$CD_ALVO" ]; then
      INCERTO=1
    elif [ -d "$CD_ALVO" ]; then
      # Relativo depois de um alvo incerto continua incerto; absoluto zera.
      case "$CD_ARG" in /* | '~'*) INCERTO=0 ;; esac
      REPO_DIR="$CD_ALVO"
    fi
    # `cd` pra pasta que não existe falha no shell: o diretório fica onde estava.
  fi

  # git commit quando o branch atual é main — no repo em que o commit vai rodar:
  # `git -C <dir>` da própria cláusula, senão o `cd` anterior, senão o diretório do comando (`cwd` do
  # evento), senão o projeto da sessão. (Operar um segundo repo a partir da sessão dava falso positivo.)
  if has_subcmd "$seg" "commit"; then
    ALVO="" INCERTO_C=$INCERTO
    # Só o `-C` de opção global, antes do `commit` (o `commit -C <sha>` reusa mensagem, e um `-C` no
    # texto da mensagem não é alvo).
    GLOBAIS="$(printf '%s' "$seg" | sed -nE 's/^git(([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*)[[:space:]]+commit([[:space:]].*)?$/\1/p')"
    if printf '%s' "$GLOBAIS" | grep -Eq -- '(^|[[:space:]])-C[[:space:]]+[^[:space:]]+'; then
      C_ARG="$(printf '%s' "$GLOBAIS" | sed -E 's/.*(^|[[:space:]])-C[[:space:]]+([^[:space:]]+).*/\2/')"
      ALVO="$(resolver "$C_ARG")"
      if [ -z "$ALVO" ]; then
        INCERTO_C=1
      elif [ -d "$ALVO" ]; then
        case "$C_ARG" in /* | '~'*) INCERTO_C=0 ;; esac
      else
        ALVO=""   # `-C` pra pasta que não existe: o git falha antes do commit
      fi
    fi
    [ -z "$ALVO" ] && ALVO="${REPO_DIR:-${SESSAO_DIR:-$CLAUDE_PROJECT_DIR}}"

    if [ "$INCERTO_C" = 1 ]; then
      for d in "$ALVO" "$REPO_DIR" "$SESSAO_DIR" "$CLAUDE_PROJECT_DIR"; do
        [ -n "$d" ] || continue
        if [ "$(git -C "$d" branch --show-current 2>/dev/null)" = "main" ]; then
          block "git commit com alvo que o hook não resolve (variável, \$(…), caminho com espaço, \`cd\` em subshell ou pipe) e o main ao alcance ($d)." "use o caminho literal do worktree, sem subshell nem pipe: \`cd /caminho/do/worktree && git commit …\` ou \`git -C /caminho/do/worktree commit …\`."
        fi
      done
    fi
    if [ -n "$ALVO" ]; then
      BRANCH="$(git -C "$ALVO" branch --show-current 2>/dev/null)"
    else
      BRANCH="$(git branch --show-current 2>/dev/null)"
    fi

    if [ "$BRANCH" = "main" ]; then
      block "git commit direto no main." "crie uma branch \`fase/F-xxx-slug\` a partir do \`main\` e commite lá; \`main\` só recebe merge de PR (AGENTS.md §Git)."
    fi
  fi
done <<EOF
$(printf '%s' "$CLAUSULAS" | sed -E 's/(&&|\|\||;|\|)/\n/g')
EOF

exit 0

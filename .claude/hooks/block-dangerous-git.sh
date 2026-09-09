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

# Verifica se $1 contém, como token isolado (delimitado por espaço/início/fim),
# um subcomando git ($2, ex.: "push", "reset").
# Verifica se a cláusula **começa** com git + subcomando ($2, ex.: "push", "reset"),
# tolerando as opções globais que mudam o alvo sem mudar o comando (`git -C <dir>`,
# `git -c <k=v>`) — o bloco do commit abaixo já lê o `-C`, então ele precisa casar aqui.
# Âncora no início: um `echo` que só cita o literal não casa (D-001).
has_subcmd() {
  printf '%s' "$1" | grep -Eq "^git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+$2([[:space:]]|\$)"
}

# Verifica se $1 contém a flag regex $2 (já com âncoras de fronteira embutidas).
has_flag() {
  printf '%s' "$1" | grep -Eq -- "$2"
}

REPO_DIR=""
DESTRUTIVA="operação destrutiva: peça confirmação ao dono (AGENTS.md §Quando pedir confirmação)."

# Comandos compostos (&&, ;, |, ||) são inspecionados cláusula a cláusula, pra
# não deixar um --force plantado num subcomando errado escapar da checagem
# nem vazar pra um subcomando que não seja o dele.
while IFS= read -r seg; do
  seg="$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [ -z "$seg" ] && continue

  # git push --force / -f / --force-with-lease
  if has_subcmd "$seg" "push" && has_flag "$seg" '(^|[[:space:]])(--force(-with-lease)?|-f)([[:space:]]|$)'; then
    block "push forçado (reescreve história publicada)." "$DESTRUTIVA"
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

  # Um `cd <dir>` numa cláusula anterior muda o repo-alvo das cláusulas seguintes.
  if printf '%s' "$seg" | grep -Eq '^cd[[:space:]]+[^[:space:]]+'; then
    REPO_DIR="$(printf '%s' "$seg" | sed -E 's/^cd[[:space:]]+//; s/[[:space:]].*$//; s/^"//; s/"$//')"
    REPO_DIR="${REPO_DIR/#\~/$HOME}"
  fi

  # git commit quando o branch atual é main — no repo em que o commit vai rodar:
  # `git -C <dir>` da própria cláusula, senão o `cd` anterior, senão o projeto da sessão.
  # (Operar um segundo repo a partir da sessão dava falso positivo — F-261.)
  if has_subcmd "$seg" "commit"; then
    ALVO=""
    if printf '%s' "$seg" | grep -Eq -- '(^|[[:space:]])-C[[:space:]]+[^[:space:]]+'; then
      ALVO="$(printf '%s' "$seg" | sed -E 's/.*(^|[[:space:]])-C[[:space:]]+([^[:space:]]+).*/\2/')"
    elif [ -n "$REPO_DIR" ]; then
      ALVO="$REPO_DIR"
    elif [ -n "$CLAUDE_PROJECT_DIR" ]; then
      ALVO="$CLAUDE_PROJECT_DIR"
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
$(printf '%s' "$COMMAND" | sed -E 's/(&&|\|\||;|\|)/\n/g')
EOF

exit 0

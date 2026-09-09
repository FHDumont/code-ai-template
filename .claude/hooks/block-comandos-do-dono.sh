#!/bin/bash
# PreToolUse hook (Bash): bloqueia os comandos que só o dono roda, e o `git add` cego.
# Transforma em guardrail duro regras que estavam só escritas em AGENTS.md
# (§Stack e comandos, §Git) e mesmo assim foram furadas mais de uma vez.
#
# Protocolo idêntico ao do `block-dangerous-git.sh`: lê o JSON do evento no stdin,
# extrai .tool_input.command, casa contra os padrões abaixo. Em caso de match:
# mensagem em stderr + exit 2 (Claude Code bloqueia a chamada e mostra o stderr
# ao agente). Sem match: exit 0.
#
# ADAPTE ESTE HOOK AO SEU PROJETO. Só a regra do `git add` cego é universal e vem
# ligada. As outras três são os comandos do projeto de onde este template saiu
# (um monorepo pnpm), deixadas como **exemplo comentado**: descomente e troque os
# literais pelos comandos que no seu projeto só o dono roda. O critério pra ligar
# uma nova está em AGENTS.md §O loop: regra violada mais de uma vez vira hook.

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
    echo "BLOQUEADO pelo guardrail dos comandos do dono: $1"
    echo
    echo "Comando: $COMMAND"
    echo
    echo "Rota certa: $2"
  } >&2
  exit 2
}

# A cláusula **começa** com o comando $2 (ex.: "pnpm", "git").
# Âncora no início: um `echo` que só cita o literal não casa.
comeca_com() {
  printf '%s' "$1" | grep -Eq "^$2([[:space:]]|\$)"
}

# A cláusula contém o token $2 como palavra inteira.
tem_token() {
  printf '%s' "$1" | grep -Eq -- "(^|[[:space:]])$2([[:space:]]|\$)"
}

# Comandos compostos (&&, ;, |, ||) são inspecionados cláusula a cláusula, pra
# não deixar um `cd x && <comando barrado>` escapar da checagem.
#
# Antes de partir, o **miolo das aspas é esvaziado**: separador dentro de string
# não abre cláusula nova — senão escrever um arquivo que cite `...; git add -A`
# entre aspas é barrado como se fosse o comando. Efeito colateral aceito: um
# `bash -c 'git add -A'` escapa. O hook é guardrail contra esquecimento, não
# contra quem quer burlar.
# O corpo de um heredoc é DADO, não comando: `cat > x <<EOF` com uma linha
# `git add -A` dentro escreve texto, não roda git. Como a quebra de linha também
# separa cláusula (num script multilinha há um comando por linha, e esse a gente
# quer inspecionar), o corpo do heredoc sai antes de partir. \047 é a aspa simples,
# que não pode aparecer literal dentro do programa awk.
CLAUSULAS="$(printf '%s' "$COMMAND" | awk '
  marca != "" {
    linha = $0
    sub(/^[ \t]+/, "", linha)
    sub(/[ \t]+$/, "", linha)
    if (linha == marca) { marca = "" }
    next
  }
  {
    print
    if (match($0, /<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*["\047]?/)) {
      m = substr($0, RSTART, RLENGTH)
      gsub(/^<<-?[ \t]*/, "", m)
      gsub(/["\047]/, "", m)
      marca = m
    }
  }
')"

CLAUSULAS="$(printf '%s' "$CLAUSULAS" | sed -E "s/'[^']*'/''/g; s/\"[^\"]*\"/\"\"/g")"

while IFS= read -r seg; do
  seg="$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [ -z "$seg" ] && continue

  # git add -A / git add --all / git add . — universal, e a única ligada por padrão.
  # O working tree é compartilhado com subagentes: `git add -A` varre o trabalho deles.
  if comeca_com "$seg" "git[[:space:]]+add" \
    && printf '%s' "$seg" | grep -Eq -- '(^|[[:space:]])(-A|--all|\.)([[:space:]]|$)'; then
    block "\`git add\` cego (-A / --all / .)." "adicione por caminho explícito e confira o \`git status\` antes de commitar — o working tree é compartilhado com subagentes e carrega arquivo alheio à etapa (AGENTS.md §Git)."
  fi

  # ---------------------------------------------------------------------------
  # EXEMPLOS — comandos do projeto de origem. Descomente e adapte.
  # ---------------------------------------------------------------------------

  # (1) Formatador que reescreve o repo inteiro e some com o diff da fase.
  # if comeca_com "$seg" "pnpm" && tem_token "$seg" "(run[[:space:]]+)?format"; then
  #   block "\`pnpm format\`." "o repo nunca foi normalizado: o formatador reescreve centenas de arquivos e some com o diff da fase (AGENTS.md §Stack e comandos). Formatação passa por \`pnpm -r lint\`; normalizar é passada própria, decisão do dono."
  # fi

  # (2) Script de ambiente local — "o ambiente é do dono" (AGENTS.md §Stack e comandos).
  # ALVO_LAB="$(printf '%s' "$seg" | sed -E 's/^(bash|sh|zsh)[[:space:]]+//')"
  # if printf '%s' "$ALVO_LAB" | grep -Eq '^[^[:space:]]*lab\.sh([[:space:]]|$)' \
  #   && tem_token "$ALVO_LAB" '(up|down|reset)'; then
  #   block "\`lab.sh\` — o ambiente local é do dono (AGENTS.md §Stack e comandos)." "peça ao dono subir, derrubar ou resetar o ambiente. Pra auditar o código bastam leitura, grep e typecheck."
  # fi

  # (3) Comando que apaga dado real do banco de desenvolvimento.
  # if comeca_com "$seg" "(pnpm|npx|node|tsx)" && tem_token "$seg" '[^[:space:]]*seed[^[:space:]]*' \
  #   && printf '%s' "$seg" | grep -Eq -- '(^|[[:space:]])--force([[:space:]]|$)'; then
  #   block "\`seed --force\` (apaga o miolo do livro existente)." "o banco de dev carrega cadastro manual do dono; \`--force\` o descarta. Peça confirmação antes de recriar (AGENTS.md §Quando pedir confirmação)."
  # fi
done <<EOF
$(printf '%s' "$CLAUSULAS" | sed -E 's/(&&|\|\||;|\|)/\n/g')
EOF

exit 0

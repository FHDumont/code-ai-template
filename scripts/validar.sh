#!/usr/bin/env bash
# Validação deste template (R-004): os testes de shell dos hooks e dos scripts do método, mais o `shellcheck`
# nos `.sh` quando o binário existe. A integração recusa o merge se este script sair diferente de zero, e o
# workflow `validar.yml` roda o mesmo em todo PR. Roda no bash 3.2 do Mac.
# Projeto derivado: acrescente typecheck, lint e teste da stack. Mantenha uma rede que falhe de verdade.
#
#   scripts/validar.sh           roda tudo
#   scripts/validar.sh --plano   só diz o que rodaria, sem rodar (o `validar.test.sh`)
set -euo pipefail

plano=0
for arg in "$@"; do
  case "$arg" in
    --plano) plano=1 ;;
    *) echo "uso: validar.sh [--plano]" >&2; exit 2 ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

# Teste novo entra aqui: o `validar.test.sh` reprova `.test.sh` versionado que ficou de fora.
testes="
.claude/hooks/block-dangerous-git.test.sh
.claude/hooks/block-comandos-do-dono.test.sh
scripts/fechar-pr.test.sh
scripts/conferir-fecho.test.sh
scripts/canal-avisar.test.sh
scripts/fases-ativas.test.sh
scripts/abrir-fase.test.sh
scripts/integrar-fase.test.sh
scripts/validar.test.sh
"

for t in $testes; do
  echo "▶ $t"
  if [[ "$plano" == 0 ]]; then bash "$t"; fi
done

if [[ "$plano" == 1 ]]; then
  echo "validar: plano"
  exit 0
fi

if command -v shellcheck >/dev/null 2>&1; then
  echo "▶ shellcheck"
  scripts=()
  while IFS= read -r f; do
    scripts+=("$f")
  done < <(git ls-files 'scripts/*.sh' 'scripts/lib/*.sh' '.claude/hooks/*.sh')
  shellcheck -x -P SCRIPTDIR "${scripts[@]}"
else
  echo "▶ shellcheck — pulado: sem o binário"
fi
echo "validar: ok"

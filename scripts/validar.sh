#!/usr/bin/env bash
# Validação deste template. A integração recusa o merge se este script sair diferente de zero.
# Projeto derivado: acrescente typecheck, lint e teste da stack. Mantenha uma rede que falhe de verdade.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
bash .claude/hooks/block-dangerous-git.test.sh
bash .claude/hooks/block-comandos-do-dono.test.sh
bash scripts/fases-ativas.test.sh
bash scripts/abrir-fase.test.sh
bash scripts/integrar-fase.test.sh

#!/usr/bin/env bash
# Testa o `fechar-pr.sh`: merge, update-branch, espera do check, vermelho. Imprime `ok`.
set -euo pipefail
aqui=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=fecho-teste-comum.sh
. "$aqui/fecho-teste-comum.sh"

# 1. Caminho feliz: merge, issue fechada, main local em dia, e o conferir passa.
cenario
no_repo bash "$aqui/fechar-pr.sh" 7 --issue 9 > /dev/null || erro "fechar-pr falhou no caminho feliz"
grep -q 'gh pr merge 7 --rebase --delete-branch' "$GH_ESTADO/log" || erro "não integrou com --rebase --delete-branch"
grep -q 'gh issue close 9' "$GH_ESTADO/log" || erro "não fechou a issue"
grep -q 'update-branch' "$GH_ESTADO/log" && erro "fez update-branch sem estar atrás"
[ "$(no_repo bash "$aqui/conferir-fecho.sh" 7 --issue 9)" = ok ] || erro "conferir não deu ok depois do fecho"

# 2. Atrás do main: update-branch --rebase e uma segunda espera do CI antes do merge.
cenario
echo BEHIND > "$GH_ESTADO/merge_state"
no_repo bash "$aqui/fechar-pr.sh" 7 > /dev/null || erro "fechar-pr falhou com o PR atrás"
grep -q 'gh pr update-branch 7 --rebase' "$GH_ESTADO/log" || erro "não fez update-branch --rebase"
[ "$(grep -c 'gh pr checks 7' "$GH_ESTADO/log")" -ge 2 ] || erro "não esperou o CI de novo depois do update-branch"

# 3. Check ainda não nasceu: espera e segue.
cenario
echo 2 > "$GH_ESTADO/checks_sem"
no_repo bash "$aqui/fechar-pr.sh" 7 > /dev/null 2>&1 || erro "não esperou o check nascer"

# 3b. O GitHub ainda calculando (UNKNOWN) e atrás: espera assentar e faz o update-branch.
cenario
echo 2 > "$GH_ESTADO/unknown"; echo BEHIND > "$GH_ESTADO/merge_state"
no_repo bash "$aqui/fechar-pr.sh" 7 > /dev/null 2>&1 || erro "falhou com o mergeStateStatus UNKNOWN"
grep -q 'gh pr update-branch 7 --rebase' "$GH_ESTADO/log" || erro "o UNKNOWN pulou o update-branch"

# 3c. O merge recusa um check obrigatório que não tinha nascido: espera e tenta de novo.
cenario
echo 1 > "$GH_ESTADO/merge_recusa"
no_repo bash "$aqui/fechar-pr.sh" 7 > /dev/null 2>&1 || erro "não tentou o merge de novo"
[ "$(grep -c 'gh pr merge 7' "$GH_ESTADO/log")" = 2 ] || erro "esperava 2 tentativas de merge"
cenario
echo 9 > "$GH_ESTADO/merge_recusa"
if no_repo bash "$aqui/fechar-pr.sh" 7 > /dev/null 2>&1; then erro "seguiu com o merge sempre recusado"; fi

# 3d. O merge entrou no GitHub mas saiu com erro (a parte local): não tenta de novo.
cenario
echo 1 > "$GH_ESTADO/merge_meio"
no_repo bash "$aqui/fechar-pr.sh" 7 > /dev/null 2>&1 || erro "o merge integrado com erro local não seguiu"
[ "$(grep -c 'gh pr merge 7' "$GH_ESTADO/log")" = 1 ] || erro "tentou o merge de novo num PR já integrado"

# 4. Vermelho: para sem merge.
cenario
echo 1 > "$GH_ESTADO/checks_rc"
if no_repo bash "$aqui/fechar-pr.sh" 7 > /dev/null 2>&1; then erro "seguiu com check vermelho"; fi
grep -q 'gh pr merge' "$GH_ESTADO/log" && erro "fez merge com check vermelho"

[ "$falhou" = 0 ] && echo ok
exit "$falhou"

#!/usr/bin/env bash
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=test-lib.sh
source "${AQUI}/test-lib.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

bare="${TMP}/bare.git"
clone="${TMP}/clone"
teste_bare "$bare" "$clone"

lista="$(cd "$clone" && bash "${AQUI}/fases-ativas.sh")"
if [[ "$lista" == *'(nenhuma)'* && "$lista" == *'depende de F-099'* ]]; then
  teste_ok "sem fase ativa, a fila do roadmap aparece"
else
  teste_falha "lista inicial inesperada"
  printf '%s\n' "$lista" >&2
fi

spec="${TMP}/spec.md"
printf '%s\n' '# F-010 — alfa' > "$spec"
(
  cd "$clone"
  bash "${AQUI}/abrir-fase.sh" --id F-010 --slug alfa --spec "$spec" --arquivos 'src/alfa/' --sem-push --destino "${TMP}/wt-010" --titulo 'alfa' --escopo 'fase alfa'
) >/dev/null

if (cd "$clone" && bash "${AQUI}/fases-ativas.sh" --sobrepor src/alfa/nota.txt) >/dev/null 2>"${TMP}/err"; then
  teste_falha "src/alfa/nota.txt deveria sobrepor a fase"
else
  grep -q 'sobrepõe F-010' "${TMP}/err"
  teste_ok "sobreposição acusa o caminho reivindicado"
fi
if (cd "$clone" && bash "${AQUI}/fases-ativas.sh" --sobrepor src/beta/nota.txt) >/dev/null; then
  teste_ok "caminho fora da reivindicação passa"
else
  teste_falha "src/beta não deveria sobrepor src/alfa/"
fi

git -C "$clone" checkout -b fase/F-030-solta >/dev/null
echo solta >> "$clone/README.md"
git -C "$clone" add -- README.md
git -C "$clone" commit -m "feat: solta" >/dev/null
git -C "$clone" checkout main >/dev/null

lista="$(cd "$clone" && bash "${AQUI}/fases-ativas.sh")"
if [[ "$lista" == *'repo-inteiro'* && "$lista" == *'fase/F-030-solta'* ]]; then
  teste_ok "branch sem registro reivindica o repo inteiro"
else
  teste_falha "solitária implícita não apareceu"
  printf '%s\n' "$lista" >&2
fi
if (cd "$clone" && bash "${AQUI}/fases-ativas.sh" --sobrepor README.md) >/dev/null 2>&1; then
  teste_falha "repo inteiro deveria bloquear qualquer caminho"
else
  teste_ok "repo inteiro bloqueia o caminho"
fi

printf '%s\n' '# F-040 — local' > "$clone/docs/SETUP.md"
lista="$(cd "$clone" && bash "${AQUI}/fases-ativas.sh")"
if [[ "$lista" == *'## F-040'* && "$lista" == *'working tree'* ]]; then
  teste_ok "spec solitária no SETUP da main aparece como ativa"
else
  teste_falha "spec no SETUP da main não entrou na lista"
  printf '%s\n' "$lista" >&2
fi

(
  cd "$clone"
  bash "${AQUI}/enfileirar.sh" --na F-010 --linha '- **F-021** — depois — depende de F-010' --sem-push
  git push origin 'fase/F-010-alfa' >/dev/null 2>&1
)
lista="$(cd "$clone" && bash "${AQUI}/fases-ativas.sh")"
vezes="$(printf '%s\n' "$lista" | grep -c 'F-021' || true)"
if [[ "$vezes" -eq 1 ]]; then
  teste_ok "fila do fragmento aparece uma vez com a branch no remoto"
else
  teste_falha "fila do fragmento saiu ${vezes} vezes"
  printf '%s\n' "$lista" >&2
fi

clone2="${TMP}/clone2"
git clone -q "$bare" "$clone2"
git -C "$clone2" config user.email "teste@example.com"
git -C "$clone2" config user.name "Teste"
git -C "$clone2" fetch -q origin 'fase/F-010-alfa'
git -C "$clone2" checkout -q -B 'fase/F-010-alfa' 'origin/fase/F-010-alfa'
(
  cd "$clone2"
  bash "${AQUI}/enfileirar.sh" --na F-010 --linha '- **F-022** — no origin — depende de F-010'
) >/dev/null
git -C "$clone" fetch -q origin 'fase/F-010-alfa'
lista="$(cd "$clone" && bash "${AQUI}/fases-ativas.sh")"
vezes21="$(printf '%s\n' "$lista" | grep -c 'F-021' || true)"
vezes22="$(printf '%s\n' "$lista" | grep -c 'F-022' || true)"
if [[ "$vezes21" -eq 1 && "$vezes22" -eq 1 ]]; then
  teste_ok "linha só no origin entra na fila sem duplicar a local"
else
  teste_falha "refs divergentes: F-021=${vezes21} F-022=${vezes22}"
  printf '%s\n' "$lista" >&2
fi

mock="${TMP}/bin"
mkdir -p "$mock"
cat > "${mock}/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '[{"number":7,"body":"- **F-030** — exportar — depende de F-099\n- **F-031** — pronta — depende de F-001"}]'
EOF
chmod +x "${mock}/gh"
lista="$(cd "$clone" && PATH="${mock}:${PATH}" FASES_ATIVAS_GH=1 bash "${AQUI}/fases-ativas.sh")"
if [[ "$lista" == *'issue #7'* && "$lista" == *'F-030'* && "$lista" != *'F-031'* ]]; then
  teste_ok "fila lê issue aberta e ignora dependência já no changelog"
else
  teste_falha "issue não entrou na fila como devia"
  printf '%s\n' "$lista" >&2
fi
pos_road="$(printf '%s\n' "$lista" | grep -n 'F-020' | head -n 1 | cut -d: -f1 || true)"
pos_frag="$(printf '%s\n' "$lista" | grep -n 'F-021' | head -n 1 | cut -d: -f1 || true)"
pos_issue="$(printf '%s\n' "$lista" | grep -n 'issue #7' | head -n 1 | cut -d: -f1 || true)"
if [[ -n "$pos_road" && -n "$pos_frag" && -n "$pos_issue" && "$pos_road" -lt "$pos_frag" && "$pos_frag" -lt "$pos_issue" ]]; then
  teste_ok "fila sai roadmap, fragmento, issue"
else
  teste_falha "ordem da fila: roadmap=${pos_road} fragmento=${pos_frag} issue=${pos_issue}"
fi

if [[ "$teste_falhou" -ne 0 ]]; then
  echo "fases-ativas.test.sh falhou" >&2
  exit 1
fi
echo "fases-ativas.test.sh passou"

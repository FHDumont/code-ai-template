#!/usr/bin/env bash
# Apoio dos testes dos scripts de fase. Não faz parte do fluxo do agente.

teste_falhou=0

teste_ok() {
  local desc="$1"
  echo "ok: ${desc}"
}

teste_falha() {
  echo "FALHOU: $*" >&2
  teste_falhou=1
}

teste_rc() {
  local desc="$1" esperado="$2"
  shift 2
  set +e
  "$@" >/tmp/teste-out 2>/tmp/teste-err
  local rc=$?
  set -e
  if [[ "$rc" != "$esperado" ]]; then
    teste_falha "${desc} — esperado exit ${esperado}, veio ${rc}"
    echo "--- stdout ---" >&2
    cat /tmp/teste-out >&2 || true
    echo "--- stderr ---" >&2
    cat /tmp/teste-err >&2 || true
    return 1
  fi
  teste_ok "$desc"
  return 0
}

teste_repo_init() {
  local dir="$1"
  git init -b main "$dir" >/dev/null
  git -C "$dir" config user.email "teste@example.com"
  git -C "$dir" config user.name "Teste"
  mkdir -p "$dir/docs/history" "$dir/docs/fases-ativas" "$dir/docs/changes" "$dir/src"
  cat > "$dir/docs/CHANGELOG.md" <<'EOF'
# CHANGELOG

- **F-001** — base — 2026-01-01
EOF
  cat > "$dir/docs/ROADMAP.md" <<'EOF'
# ROADMAP

## Atual

## Próximas

- **F-010** — alfa
- **F-011** — beta
- **F-020** — gama — depende de F-099
EOF
  cat > "$dir/docs/DECISOES.md" <<'EOF'
# DECISÕES

## Método

| ADR | Título | Status |
| --- | ------ | ------ |
| ADR-001 | Canal | accepted |

## Plataforma

| ADR | Título | Status |
| --- | ------ | ------ |
EOF
  cat > "$dir/docs/DEBITO-TECNICO.md" <<'EOF'
# DÉBITO TÉCNICO

**D-001** — um débito — baixa
EOF
  printf '%s\n' '# DÉBITO RESOLVIDO' '' > "$dir/docs/history/DEBITO-RESOLVIDO.md"
  printf '%s\n' '# SETUP — histórico' '' '- F-001 — base' > "$dir/docs/history/SETUP-HISTORICO.md"
  printf '%s\n' '# SETUP — fase atual' '' 'vazio' > "$dir/docs/SETUP.md"
  echo "leia" > "$dir/docs/fases-ativas/LEIA.md"
  echo "leia" > "$dir/docs/changes/LEIA.md"
  echo "readme" > "$dir/README.md"
  git -C "$dir" add -- README.md docs
  git -C "$dir" commit -m "chore: base" >/dev/null
}

teste_bare() {
  local bare="$1" clone="$2"
  git init --bare -b main "$bare" >/dev/null
  teste_repo_init "$clone"
  git -C "$clone" remote add origin "$bare"
  git -C "$clone" push -u origin main >/dev/null 2>&1
}

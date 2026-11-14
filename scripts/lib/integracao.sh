# Funções da integração de fases paralelas. Quem chama é que liga set -e.
# Regras: docs/reference/integracao.md. Não imprime progresso — só o resultado
# combinado (resolver) ou os caminhos alterados (fragmento), um por linha.

# Linha cujo assunto é a fase (changelog, roadmap, histórico). Menção
# "depende de <id>" não conta: apagar essa linha não é conflito trivial.
integracao_linha_e_da_fase() {
  local linha="$1" id="$2"
  [[ "$linha" == *"**${id}**"* ]] && return 0
  [[ "$linha" == "- ${id} "* || "$linha" == "- ${id}—"* ]] && return 0
  return 1
}

# 0 se os caminhos se cruzam. Diretório precisa da barra no fim;
# "src/notas" sem barra é arquivo e não cobre "src/notas/tags.ts".
integracao_sobrepoe() {
  local a="${1#./}" b="${2#./}"
  [[ "$a" == "$b" ]] && return 0
  if [[ "$a" == */ && ( "$b" == "$a"* || "${b}/" == "$a" ) ]]; then
    return 0
  fi
  if [[ "$b" == */ && ( "$a" == "$b"* || "${a}/" == "$b" ) ]]; then
    return 0
  fi
  return 1
}

integracao_id_valido() {
  [[ "$1" =~ ^F-[A-Za-z0-9]+(-[A-Za-z0-9]+)*$ ]]
}

# Ids citados em "depende de F-a, F-b". Um por linha. Sem citação, não imprime.
integracao_ids_depende() {
  local linha="$1" trecho id
  [[ "$linha" == *"depende de "* ]] || return 0
  trecho="${linha#*depende de }"
  trecho="${trecho%%—*}"
  trecho="${trecho%% - *}"
  local -a partes=()
  IFS=',' read -ra partes <<< "$trecho"
  for id in "${partes[@]}"; do
    id="${id#"${id%%[![:space:]]*}"}"
    id="${id%"${id##*[![:space:]]}"}"
    if integracao_id_valido "$id"; then
      printf '%s\n' "$id"
    fi
  done
}

# Combina três versões de um ledger. Estágio "main" é a ponta que já integrou;
# "fase" é o commit da fase. Sai 1 se a fase tirou ou reescreveu linha que não é dela.
integracao_resolver_ledger() {
  local base_file="$1" main_file="$2" phase_file="$3" phase_id="$4"
  local linha
  local -A na_base=() na_phase=() na_main=()
  while IFS= read -r linha || [[ -n "$linha" ]]; do
    [[ -z "$linha" ]] && continue
    na_base["$linha"]=1
  done < "$base_file"
  while IFS= read -r linha || [[ -n "$linha" ]]; do
    [[ -z "$linha" ]] && continue
    na_phase["$linha"]=1
  done < "$phase_file"
  while IFS= read -r linha || [[ -n "$linha" ]]; do
    [[ -z "$linha" ]] && continue
    na_main["$linha"]=1
  done < "$main_file"

  for linha in "${!na_base[@]}"; do
    if [[ -z "${na_phase[$linha]+x}" && -n "${na_main[$linha]+x}" ]]; then
      if ! integracao_linha_e_da_fase "$linha" "$phase_id"; then
        echo "conflito não trivial: a fase tirou ou reescreveu linha que não é dela: ${linha}" >&2
        return 1
      fi
    fi
  done

  local -a resultado=()
  while IFS= read -r linha || [[ -n "$linha" ]]; do
    if [[ -n "$linha" && -z "${na_phase[$linha]+x}" && -n "${na_base[$linha]+x}" ]] && integracao_linha_e_da_fase "$linha" "$phase_id"; then
      continue
    fi
    resultado+=("$linha")
  done < "$main_file"

  local anterior="" nova
  local -a adicoes=()
  local -A pred_de=()
  while IFS= read -r linha || [[ -n "$linha" ]]; do
    if [[ -z "$linha" ]]; then
      continue
    fi
    if [[ -n "${na_base[$linha]+x}" ]]; then
      anterior="$linha"
      continue
    fi
    local ja=0
    for nova in "${resultado[@]+"${resultado[@]}"}"; do
      if [[ "$nova" == "$linha" ]]; then
        ja=1
        break
      fi
    done
    if [[ $ja -eq 1 ]]; then
      anterior="$linha"
      continue
    fi
    pred_de["$linha"]="$anterior"
    adicoes+=("$linha")
    anterior="$linha"
  done < "$phase_file"

  for nova in "${adicoes[@]+"${adicoes[@]}"}"; do
    local pred="${pred_de[$nova]}" inseriu=0
    local -a novo=()
    if [[ -z "$pred" ]]; then
      resultado+=("$nova")
      continue
    fi
    for linha in "${resultado[@]+"${resultado[@]}"}"; do
      novo+=("$linha")
      if [[ $inseriu -eq 0 && "$linha" == "$pred" ]]; then
        novo+=("$nova")
        inseriu=1
      fi
    done
    if [[ $inseriu -eq 0 ]]; then
      novo+=("$nova")
    fi
    resultado=("${novo[@]+"${novo[@]}"}")
  done

  if [[ ${#resultado[@]} -eq 0 ]]; then
    return 0
  fi
  printf '%s\n' "${resultado[@]}"
}

integracao_fragmento_tem_changelog() {
  local fragment="$1" secao="" linha
  [[ -f "$fragment" ]] || return 1
  while IFS= read -r linha || [[ -n "$linha" ]]; do
    if [[ "$linha" =~ ^##[[:space:]]+([a-z0-9-]+)[[:space:]]*$ ]]; then
      secao="${BASH_REMATCH[1]}"
      continue
    fi
    [[ "$secao" == "changelog" ]] || continue
    [[ -z "$linha" || "$linha" =~ ^# || "$linha" =~ ^\<\!-- ]] && continue
    return 0
  done < "$fragment"
  return 1
}

integracao_escrever_fragmento_vazio() {
  local arquivo="$1" id="$2"
  cat > "$arquivo" <<EOF
# ${id}

<!-- Fragmento da fase. A integração consolida; a fase não edita os ledgers. Uma linha por item. -->

## changelog

## historico

## roadmap-remove

## roadmap-add

## decisoes

## debito-add

## debito-resolve

## debito-resolvido
EOF
}

# Anexa uma linha no fim da seção "## <secao>" (antes do próximo cabeçalho).
integracao_anexar_na_secao() {
  local arquivo="$1" secao="$2" nova="$3"
  local -a linhas=()
  local linha
  while IFS= read -r linha || [[ -n "$linha" ]]; do
    linhas+=("$linha")
  done < "$arquivo"
  local i n=${#linhas[@]} inicio=-1 fim=-1
  for ((i = 0; i < n; i++)); do
    if [[ "${linhas[$i]}" == "## ${secao}" ]]; then
      inicio=$i
      break
    fi
  done
  if [[ $inicio -lt 0 ]]; then
    echo "seção '## ${secao}' não está em ${arquivo}" >&2
    return 1
  fi
  fim=$n
  for ((i = inicio + 1; i < n; i++)); do
    if [[ "${linhas[$i]}" == "## "* ]]; then
      fim=$i
      break
    fi
  done
  local -a novo=()
  for ((i = 0; i < fim; i++)); do
    novo+=("${linhas[$i]}")
  done
  if [[ $fim -gt 0 && -n "${novo[$((fim - 1))]:-}" ]]; then
    novo+=("")
  fi
  novo+=("$nova")
  novo+=("")
  for ((i = fim; i < n; i++)); do
    novo+=("${linhas[$i]}")
  done
  printf '%s\n' "${novo[@]}" > "$arquivo"
}

# Linha de fila no fragmento: entra em roadmap-add e o id sai do roadmap antigo.
integracao_enfileirar_no_fragmento() {
  local fragment="$1" linha="$2" id
  if grep -Fxq -- "$linha" "$fragment"; then
    return 0
  fi
  integracao_anexar_na_secao "$fragment" "roadmap-add" "$linha"
  if [[ "$linha" =~ \*\*(F-[A-Za-z0-9]+(-[A-Za-z0-9]+)*)\*\* ]]; then
    id="${BASH_REMATCH[1]}"
    if ! grep -Fxq -- "$id" "$fragment"; then
      integracao_anexar_na_secao "$fragment" "roadmap-remove" "$id"
    fi
  fi
}

_integracao_garantir_newline() {
  local arquivo="$1" ult
  [[ -s "$arquivo" ]] || return 0
  ult=$(tail -c 1 "$arquivo" || true)
  if [[ "$ult" != $'\n' ]]; then
    printf '\n' >> "$arquivo"
  fi
}

_integracao_acrescentar_se_falta() {
  local arquivo="$1" linha="$2"
  [[ -f "$arquivo" ]] || { echo "arquivo ausente: ${arquivo}" >&2; return 1; }
  if grep -Fxq -- "$linha" "$arquivo"; then
    return 0
  fi
  _integracao_garantir_newline "$arquivo"
  printf '%s\n' "$linha" >> "$arquivo"
}

_integracao_remover_linhas_com_id() {
  local arquivo="$1" id="$2" tmp
  [[ -f "$arquivo" ]] || return 0
  tmp=$(mktemp)
  grep -v -E "(^|[^A-Za-z0-9-])${id}([^A-Za-z0-9-]|$)" "$arquivo" > "$tmp" || true
  mv "$tmp" "$arquivo"
}

# Tira do roadmap só a linha cujo assunto é o id (`**F-xxx**`).
# "depende de F-xxx" numa linha de outra fase fica.
_integracao_remover_assunto_roadmap() {
  local arquivo="$1" id="$2" tmp
  [[ -f "$arquivo" ]] || return 0
  tmp=$(mktemp)
  grep -v -F -- "**${id}**" "$arquivo" > "$tmp" || true
  mv "$tmp" "$arquivo"
}

_integracao_inserir_decisao() {
  local arquivo="$1" secao="$2" nova="$3"
  local adr=""
  if [[ "$nova" =~ ADR-[0-9]+ ]]; then
    adr="${BASH_REMATCH[0]}"
    if grep -E -q "${adr}([^0-9]|$)" "$arquivo"; then
      return 0
    fi
  fi
  local -a linhas=()
  local linha
  while IFS= read -r linha || [[ -n "$linha" ]]; do
    linhas+=("$linha")
  done < "$arquivo"
  local i n=${#linhas[@]} inicio=-1 fim=-1
  for ((i = 0; i < n; i++)); do
    if [[ "${linhas[$i]}" == "## ${secao}" ]]; then
      inicio=$i
      break
    fi
  done
  if [[ $inicio -lt 0 ]]; then
    echo "seção '## ${secao}' não está em ${arquivo}" >&2
    return 1
  fi
  fim=$n
  for ((i = inicio + 1; i < n; i++)); do
    if [[ "${linhas[$i]}" == "## "* ]]; then
      fim=$i
      break
    fi
  done
  local ancora=$inicio
  for ((i = inicio + 1; i < fim; i++)); do
    if [[ "${linhas[$i]}" == \|* ]]; then
      ancora=$i
    fi
  done
  local -a novo=()
  for ((i = 0; i < n; i++)); do
    novo+=("${linhas[$i]}")
    if [[ $i -eq $ancora ]]; then
      novo+=("$nova")
    fi
  done
  printf '%s\n' "${novo[@]}" > "$arquivo"
}

# Edita os ledgers sob root, apaga o fragmento e o registro da fase.
# Imprime os caminhos relativos que o commit da integração deve incluir.
integracao_aplicar_fragmento() {
  local root="$1" fragment="$2" id="$3"
  [[ -f "$fragment" ]] || { echo "fragmento ausente: ${fragment}" >&2; return 1; }
  local secao="" decisoes_secao="Método" linha
  local -a changelog=() historico=() roadmap_remove=() roadmap_add=()
  local -a decisoes=() debito_add=() debito_resolve=() debito_resolvido=()

  while IFS= read -r linha || [[ -n "$linha" ]]; do
    if [[ "$linha" =~ ^##[[:space:]]+([a-z0-9-]+)[[:space:]]*$ ]]; then
      secao="${BASH_REMATCH[1]}"
      continue
    fi
    [[ -z "$linha" || "$linha" =~ ^# || "$linha" =~ ^\<\!-- ]] && continue
    case "$secao" in
      changelog) changelog+=("$linha") ;;
      historico) historico+=("$linha") ;;
      roadmap-remove) roadmap_remove+=("$linha") ;;
      roadmap-add) roadmap_add+=("$linha") ;;
      decisoes)
        if [[ "$linha" == secao:* ]]; then
          decisoes_secao="${linha#secao:}"
          decisoes_secao="${decisoes_secao#"${decisoes_secao%%[![:space:]]*}"}"
          decisoes_secao="${decisoes_secao%"${decisoes_secao##*[![:space:]]}"}"
        else
          decisoes+=("$linha")
        fi
        ;;
      debito-add) debito_add+=("$linha") ;;
      debito-resolve) debito_resolve+=("$linha") ;;
      debito-resolvido) debito_resolvido+=("$linha") ;;
      "")
        echo "linha fora de seção no fragmento: ${linha}" >&2
        return 1
        ;;
      *)
        echo "seção desconhecida no fragmento: ${secao}" >&2
        return 1
        ;;
    esac
  done < "$fragment"

  local rel abs id_add
  for linha in "${roadmap_add[@]+"${roadmap_add[@]}"}"; do
    if [[ "$linha" =~ \*\*(F-[A-Za-z0-9]+(-[A-Za-z0-9]+)*)\*\* ]]; then
      id_add="${BASH_REMATCH[1]}"
      local ja=0 um
      for um in "${roadmap_remove[@]+"${roadmap_remove[@]}"}"; do
        [[ "$um" == "$id_add" ]] && ja=1
      done
      if [[ $ja -eq 0 ]]; then
        roadmap_remove+=("$id_add")
      fi
    fi
  done

  local -a tocados=()
  _integracao_marcar() {
    local caminho="$1" ja=0 um
    for um in "${tocados[@]+"${tocados[@]}"}"; do
      [[ "$um" == "$caminho" ]] && ja=1
    done
    if [[ $ja -eq 0 ]]; then
      tocados+=("$caminho")
    fi
  }

  local changelog_path="${root}/docs/CHANGELOG.md"
  local historico_path="${root}/docs/history/SETUP-HISTORICO.md"
  local roadmap_path="${root}/docs/ROADMAP.md"
  local decisoes_path="${root}/docs/DECISOES.md"
  local debito_path="${root}/docs/DEBITO-TECNICO.md"
  local resolvido_path="${root}/docs/history/DEBITO-RESOLVIDO.md"

  for linha in "${changelog[@]+"${changelog[@]}"}"; do
    _integracao_acrescentar_se_falta "$changelog_path" "$linha"
    _integracao_marcar "docs/CHANGELOG.md"
  done
  for linha in "${historico[@]+"${historico[@]}"}"; do
    _integracao_acrescentar_se_falta "$historico_path" "$linha"
    _integracao_marcar "docs/history/SETUP-HISTORICO.md"
  done
  if [[ ${#roadmap_remove[@]} -gt 0 && -f "$roadmap_path" ]]; then
    for id_add in "${roadmap_remove[@]}"; do
      _integracao_remover_assunto_roadmap "$roadmap_path" "$id_add"
    done
    _integracao_marcar "docs/ROADMAP.md"
  fi
  for linha in "${roadmap_add[@]+"${roadmap_add[@]}"}"; do
    if [[ "$linha" =~ \*\*(F-[A-Za-z0-9]+(-[A-Za-z0-9]+)*)\*\* ]]; then
      id_add="${BASH_REMATCH[1]}"
      if grep -F -q -- "**${id_add}**" "$roadmap_path"; then
        continue
      fi
    elif grep -Fxq -- "$linha" "$roadmap_path"; then
      continue
    fi
    integracao_anexar_na_secao "$roadmap_path" "Próximas" "$linha"
    _integracao_marcar "docs/ROADMAP.md"
  done
  for linha in "${decisoes[@]+"${decisoes[@]}"}"; do
    _integracao_inserir_decisao "$decisoes_path" "$decisoes_secao" "$linha"
    _integracao_marcar "docs/DECISOES.md"
  done
  for linha in "${debito_add[@]+"${debito_add[@]}"}"; do
    _integracao_acrescentar_se_falta "$debito_path" "$linha"
    _integracao_marcar "docs/DEBITO-TECNICO.md"
  done
  for linha in "${debito_resolve[@]+"${debito_resolve[@]}"}"; do
    _integracao_remover_linhas_com_id "$debito_path" "$linha"
    _integracao_marcar "docs/DEBITO-TECNICO.md"
  done
  for linha in "${debito_resolvido[@]+"${debito_resolvido[@]}"}"; do
    _integracao_acrescentar_se_falta "$resolvido_path" "$linha"
    _integracao_marcar "docs/history/DEBITO-RESOLVIDO.md"
  done

  local frag_rel="${fragment#"${root}/"}"
  rm -f "$fragment"
  _integracao_marcar "$frag_rel"
  local registro="${root}/docs/fases-ativas/${id}.md"
  if [[ -f "$registro" ]]; then
    rm -f "$registro"
    _integracao_marcar "docs/fases-ativas/${id}.md"
  fi

  printf '%s\n' "${tocados[@]}"
}

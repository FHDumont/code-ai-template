# shellcheck shell=bash
# Funções da integração de fases paralelas (ADR-002). Quem chama é que liga set -e.
# Regras: docs/reference/integracao.md (R-001 a R-006). Não imprime progresso — só o resultado
# combinado (resolver) ou os caminhos alterados (fragmento), um por linha.
# Roda no bash 3.2 do Mac, que não tem mapa associativo: o que era mapa é awk (F-metodo-v8, Amplug F-098).
# Aceita os dois formatos de ledger: item de lista (`- **F-xxx** — …`, `- F-xxx — …`) e linha de tabela
# ficam colados; parágrafo (`**X-xxx** — …`, `> nota`) fica separado do vizinho por uma linha em branco.

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
  trecho="${trecho%%:*}"
  trecho="${trecho%%;*}"
  local -a partes=()
  IFS=',' read -ra partes <<< "$trecho"
  for id in ${partes[@]+"${partes[@]}"}; do
    id="${id#"${id%%[![:space:]]*}"}"
    id="${id%"${id##*[![:space:]]}"}"
    id="${id%%[).]*}"
    if integracao_id_valido "$id"; then
      printf '%s\n' "$id"
    fi
  done
}

# Linha de parágrafo (`**X**…`, `> nota`) se separa da vizinha por uma linha em branco;
# item de lista (`- …`) e linha de tabela (`| …`) ficam colados.
integracao_e_paragrafo() {
  [[ "$1" == '**'* || "$1" == '>'* ]]
}

# Combina três versões de um ledger. Estágio "main" é a ponta que já integrou;
# "fase" é o commit da fase. Sai 1 se a fase tirou ou reescreveu linha que não é dela.
# A linha nova da fase entra depois da que a precede na fase (e depois do que a main
# acrescentou logo ali), com a linha em branco do parágrafo; a linha da fase que a fase
# tirou sai junto com uma das brancas em volta.
integracao_resolver_ledger() {
  local base_file="$1" main_file="$2" phase_file="$3" phase_id="$4"
  awk -v id="$phase_id" '
    function da_fase(l) {
      if (index(l, "**" id "**") > 0) return 1
      if (index(l, "- " id " ") == 1 || index(l, "- " id "—") == 1) return 1
      return 0
    }
    function paragrafo(l) { return (substr(l, 1, 2) == "**" || substr(l, 1, 1) == ">") }
    FILENAME == ARGV[1] { if ($0 != "") B[$0] = 1; next }
    FILENAME == ARGV[2] { M[++nm] = $0; next }
    { F[++nf] = $0; if ($0 != "") P[$0] = 1 }
    END {
      for (l in B) {
        if (!(l in P) && !da_fase(l)) {
          print "conflito não trivial: a fase tirou ou reescreveu linha que não é dela: " l > "/dev/stderr"
          exit 1
        }
      }
      # A main, sem a linha da fase que a fase tirou (e sem a branca que sobraria dobrada).
      n = 0; tirou = 0
      for (i = 1; i <= nm; i++) {
        l = M[i]
        if (l != "" && !(l in P) && (l in B) && da_fase(l)) { tirou = 1; continue }
        if (l == "" && tirou && n > 0 && R[n] == "") { tirou = 0; continue }
        if (l != "") tirou = 0
        R[++n] = l
      }
      if (tirou && n > 0 && R[n] == "") n--
      for (i = 1; i <= n; i++) if (R[i] != "") EmR[R[i]] = 1
      # As linhas novas da fase, cada uma com a que a precede.
      na = 0; anterior = ""
      for (i = 1; i <= nf; i++) {
        l = F[i]
        if (l == "") continue
        if ((l in B) || (l in EmR)) { anterior = l; continue }
        if (l in Vista) { anterior = l; continue }
        Vista[l] = 1
        A[++na] = l; Pred[na] = anterior; anterior = l
      }
      for (a = 1; a <= na; a++) {
        nova = A[a]; pred = Pred[a]; k = 0
        if (pred != "") {
          for (i = 1; i <= n; i++) if (R[i] == pred) { k = i; break }
        }
        if (k > 0) {
          # Pula o que a main acrescentou logo depois da mesma linha: a fase entra depois.
          for (m = k + 1; m <= n; m++) {
            if (R[m] == "") continue
            if (!(R[m] in B) && !(R[m] in P)) { k = m; continue }
            break
          }
        } else {
          k = n
          while (k > 0 && R[k] == "") k--
        }
        ins = 0
        if (paragrafo(nova) && k > 0 && R[k] != "") X[++ins] = ""
        X[++ins] = nova
        if (paragrafo(nova) && k < n && R[k + 1] != "") X[++ins] = ""
        for (i = n; i > k; i--) R[i + ins] = R[i]
        for (j = 1; j <= ins; j++) R[k + j] = X[j]
        n += ins
      }
      for (i = 1; i <= n; i++) print R[i]
    }
  ' "$base_file" "$main_file" "$phase_file"
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
    [[ -z "$linha" || "$linha" == '#'* || "$linha" == '<!--'* ]] && continue
    return 0
  done < "$fragment"
  return 1
}

integracao_escrever_fragmento_vazio() {
  local arquivo="$1" id="$2"
  cat > "$arquivo" <<EOF
# ${id}

<!-- Fragmento da fase (templates/fragmento-fase.md). A integração consolida; a fase paralela não edita os ledgers. Uma linha por item. -->

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

# Anexa uma linha no fim da seção "## <secao>" (antes do próximo cabeçalho "## "),
# separada por uma linha em branco da anterior e da seguinte.
integracao_anexar_na_secao() {
  local arquivo="$1" secao="$2" nova="$3" tmp
  if ! grep -Fxq -- "## ${secao}" "$arquivo"; then
    echo "seção '## ${secao}' não está em ${arquivo}" >&2
    return 1
  fi
  tmp=$(mktemp)
  awk -v secao="## ${secao}" -v nova="$nova" '
    { L[++n] = $0 }
    END {
      ini = 0
      for (i = 1; i <= n; i++) if (L[i] == secao) { ini = i; break }
      fim = n + 1
      for (i = ini + 1; i <= n; i++) if (substr(L[i], 1, 3) == "## ") { fim = i; break }
      ult = fim - 1
      while (ult > ini && L[ult] == "") ult--
      for (i = 1; i <= ult; i++) print L[i]
      print ""
      print nova
      if (fim <= n) {
        print ""
        for (i = fim; i <= n; i++) print L[i]
      }
    }
  ' "$arquivo" > "$tmp"
  mv "$tmp" "$arquivo"
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

# Acrescenta a linha no fim do ledger, se ainda não estiver lá. Parágrafo ganha a linha em branco antes.
_integracao_acrescentar_se_falta() {
  local arquivo="$1" linha="$2" ult tmp
  [[ -f "$arquivo" ]] || { echo "arquivo ausente: ${arquivo}" >&2; return 1; }
  if grep -Fxq -- "$linha" "$arquivo"; then
    return 0
  fi
  if [[ -s "$arquivo" ]]; then
    if [[ "$(tail -c 1 "$arquivo")" != "" ]]; then
      printf '\n' >> "$arquivo"
    fi
    # Item de lista ou linha de tabela cola no item anterior: as linhas em branco do fim do ledger saem,
    # desde que a última linha com texto seja da mesma lista (depois de um título, a branca fica).
    if ! integracao_e_paragrafo "$linha"; then
      tmp=$(mktemp)
      awk '{ L[NR] = $0 } END {
        n = NR; while (n > 0 && L[n] == "") n--
        if (n > 0 && (substr(L[n], 1, 2) == "- " || substr(L[n], 1, 1) == "|")) fim = n; else fim = NR
        for (i = 1; i <= fim; i++) print L[i]
      }' "$arquivo" > "$tmp"
      cat "$tmp" > "$arquivo"
      rm -f "$tmp"
    fi
    ult=$(tail -n 1 "$arquivo")
    if integracao_e_paragrafo "$linha" && [[ -n "$ult" ]]; then
      printf '\n' >> "$arquivo"
    fi
  fi
  printf '%s\n' "$linha" >> "$arquivo"
}

# Tira as linhas que contêm o texto fixo (`**F-xxx**`, `**D-xxx**`) e a linha em branco que sobraria dobrada.
# "depende de F-xxx" numa linha de outra fase fica: o texto procurado leva os asteriscos.
_integracao_tirar_paragrafo() {
  local arquivo="$1" texto="$2" tmp
  [[ -f "$arquivo" ]] || return 0
  tmp=$(mktemp)
  awk -v t="$texto" '
    { L[++nl] = $0 }
    END {
      n = 0; tirou = 0
      for (i = 1; i <= nl; i++) {
        l = L[i]
        if (index(l, t) > 0) { tirou = 1; continue }
        if (l == "" && tirou && n > 0 && R[n] == "") { tirou = 0; continue }
        if (l != "") tirou = 0
        R[++n] = l
      }
      if (tirou && n > 0 && R[n] == "") n--
      for (i = 1; i <= n; i++) print R[i]
    }
  ' "$arquivo" > "$tmp"
  mv "$tmp" "$arquivo"
}

# Linha de tabela entra depois da última linha `|` da seção. ADR que já está no arquivo não entra de novo.
_integracao_inserir_decisao() {
  local arquivo="$1" secao="$2" nova="$3" adr="" tmp
  if [[ "$nova" =~ ADR-[0-9]+ ]]; then
    adr="${BASH_REMATCH[0]}"
    if grep -E -q "${adr}([^0-9]|$)" "$arquivo"; then
      return 0
    fi
  fi
  if ! grep -Fxq -- "## ${secao}" "$arquivo"; then
    echo "seção '## ${secao}' não está em ${arquivo}" >&2
    return 1
  fi
  tmp=$(mktemp)
  awk -v secao="## ${secao}" -v nova="$nova" '
    { L[++n] = $0 }
    END {
      ini = 0
      for (i = 1; i <= n; i++) if (L[i] == secao) { ini = i; break }
      fim = n + 1
      for (i = ini + 1; i <= n; i++) if (substr(L[i], 1, 3) == "## ") { fim = i; break }
      ancora = ini
      for (i = ini + 1; i < fim; i++) if (substr(L[i], 1, 1) == "|") ancora = i
      for (i = 1; i <= n; i++) { print L[i]; if (i == ancora) print nova }
    }
  ' "$arquivo" > "$tmp"
  mv "$tmp" "$arquivo"
}

# Edita os ledgers sob root, apaga o fragmento e o registro da fase.
# Imprime os caminhos relativos que o commit da integração deve incluir.
integracao_aplicar_fragmento() {
  local root="$1" fragment="$2" id="$3"
  [[ -f "$fragment" ]] || { echo "fragmento ausente: ${fragment}" >&2; return 1; }
  local secao="" decisoes_secao="Método" linha
  local -a changelog=() historico=() roadmap_remove=() roadmap_add=()
  local -a decisoes=() decisoes_secoes=() debito_add=() debito_resolve=() debito_resolvido=()

  while IFS= read -r linha || [[ -n "$linha" ]]; do
    if [[ "$linha" =~ ^##[[:space:]]+([a-z0-9-]+)[[:space:]]*$ ]]; then
      secao="${BASH_REMATCH[1]}"
      continue
    fi
    [[ -z "$linha" || "$linha" == '#'* || "$linha" == '<!--'* ]] && continue
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
          decisoes_secoes+=("$decisoes_secao")
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

  local id_add um ja i
  for linha in ${roadmap_add[@]+"${roadmap_add[@]}"}; do
    if [[ "$linha" =~ \*\*(F-[A-Za-z0-9]+(-[A-Za-z0-9]+)*)\*\* ]]; then
      id_add="${BASH_REMATCH[1]}"
      ja=0
      for um in ${roadmap_remove[@]+"${roadmap_remove[@]}"}; do
        [[ "$um" == "$id_add" ]] && ja=1
      done
      if [[ $ja -eq 0 ]]; then
        roadmap_remove+=("$id_add")
      fi
    fi
  done

  local tocados=""
  _integracao_marcar() {
    case $'\n'"$tocados" in
      *$'\n'"$1"$'\n'*) ;;
      *) tocados="${tocados}$1"$'\n' ;;
    esac
  }

  local changelog_path="${root}/docs/CHANGELOG.md"
  local historico_path="${root}/docs/history/SETUP-HISTORICO.md"
  local roadmap_path="${root}/docs/ROADMAP.md"
  local decisoes_path="${root}/docs/DECISOES.md"
  local debito_path="${root}/docs/DEBITO-TECNICO.md"
  local resolvido_path="${root}/docs/history/DEBITO-RESOLVIDO.md"

  for linha in ${changelog[@]+"${changelog[@]}"}; do
    _integracao_acrescentar_se_falta "$changelog_path" "$linha" || return 1
    _integracao_marcar "docs/CHANGELOG.md"
  done
  for linha in ${historico[@]+"${historico[@]}"}; do
    _integracao_acrescentar_se_falta "$historico_path" "$linha" || return 1
    _integracao_marcar "docs/history/SETUP-HISTORICO.md"
  done
  if [[ ${#roadmap_remove[@]} -gt 0 && -f "$roadmap_path" ]]; then
    for id_add in "${roadmap_remove[@]}"; do
      _integracao_tirar_paragrafo "$roadmap_path" "**${id_add}**"
    done
    _integracao_marcar "docs/ROADMAP.md"
  fi
  for linha in ${roadmap_add[@]+"${roadmap_add[@]}"}; do
    if [[ "$linha" =~ \*\*(F-[A-Za-z0-9]+(-[A-Za-z0-9]+)*)\*\* ]]; then
      id_add="${BASH_REMATCH[1]}"
      if grep -F -q -- "**${id_add}**" "$roadmap_path"; then
        continue
      fi
    elif grep -Fxq -- "$linha" "$roadmap_path"; then
      continue
    fi
    integracao_anexar_na_secao "$roadmap_path" "Próximas" "$linha" || return 1
    _integracao_marcar "docs/ROADMAP.md"
  done
  i=0
  while [[ $i -lt ${#decisoes[@]} ]]; do
    _integracao_inserir_decisao "$decisoes_path" "${decisoes_secoes[$i]}" "${decisoes[$i]}" || return 1
    _integracao_marcar "docs/DECISOES.md"
    i=$((i + 1))
  done
  for linha in ${debito_add[@]+"${debito_add[@]}"}; do
    _integracao_acrescentar_se_falta "$debito_path" "$linha" || return 1
    _integracao_marcar "docs/DEBITO-TECNICO.md"
  done
  for linha in ${debito_resolve[@]+"${debito_resolve[@]}"}; do
    _integracao_tirar_paragrafo "$debito_path" "**${linha}**"
    _integracao_marcar "docs/DEBITO-TECNICO.md"
  done
  for linha in ${debito_resolvido[@]+"${debito_resolvido[@]}"}; do
    _integracao_acrescentar_se_falta "$resolvido_path" "$linha" || return 1
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

  printf '%s' "$tocados"
}

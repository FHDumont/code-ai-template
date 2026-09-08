#!/usr/bin/env python3
"""Fatia docs/history/SETUP-HISTORICO.md em um arquivo por fase (docs/history/fases/) e reescreve o SETUP-HISTORICO.md como índice.

Uso: python3 scripts/split-historico.py [caminho-do-repo]
Idempotente só na primeira passada: rode uma vez, confira o diff, commite. Não edita o conteúdo das fases — só move.
"""
import re, sys, os, unicodedata

root = sys.argv[1] if len(sys.argv) > 1 else "."
src = os.path.join(root, "docs/history/SETUP-HISTORICO.md")
out_dir = os.path.join(root, "docs/history/fases")
text = open(src, encoding="utf-8").read()
lines = text.split("\n")

# cabeçalho do arquivo = tudo antes do primeiro '# ' de fase
blocks, cur, header_done = [], None, False
for ln in lines:
    if ln.startswith("# ") and not ln.startswith("# SETUP —") and not ln.startswith("# SETUP -"):
        if ln.strip() == "# SETUP":          # invólucro antigo: a fase real vem no próximo '# F-'
            cur = None; header_done = True; continue
        cur = [ln]; blocks.append(cur); header_done = True; continue
    if cur is not None:
        cur.append(ln)
    elif header_done:
        # texto de invólucro '# SETUP' (blockquote + ---) — descartado, é boilerplate do SETUP.md
        if ln.strip() and not ln.startswith(">") and ln.strip() != "---":
            sys.stderr.write(f"aviso: linha fora de fase descartada: {ln[:80]}\n")

def slug(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    s = re.sub(r"[^a-zA-Z0-9]+", "-", s).strip("-").lower()
    return s[:60].rstrip("-")

os.makedirs(out_dir, exist_ok=True)
seen, index, avulso = {}, [], 0
for b in blocks:
    title = b[0][2:].strip()
    m = re.match(r"(F-[0-9]{3}[a-z0-9]*)\s*[—–-]\s*(.*)", title) or re.match(r"(F-[A-Za-z0-9][A-Za-z0-9-]*)\s+[—–]\s+(.*)", title)
    if m:
        fid, rest = m.group(1), m.group(2).strip()
        n = seen.get(fid, 0) + 1; seen[fid] = n
        name = fid if n == 1 else f"{fid}-{n}"
    else:
        avulso += 1
        fid, rest = None, title
        name = f"avulso-{avulso:02d}-{slug(title)}"
    # remove linhas em branco/--- sobrando no fim
    while b and b[-1].strip() in ("", "---"):
        b.pop()
    open(os.path.join(out_dir, name + ".md"), "w", encoding="utf-8").write("\n".join(b) + "\n")
    label = f"{fid} — {rest}" if fid else title
    if fid and n > 1:
        label += f" _(segunda entrada com o mesmo ID)_"
    index.append(f"- {label} → [`fases/{name}.md`](fases/{name}.md)")

idx = [
    "# SETUP — histórico",
    "",
    "> Índice das specs de fases **concluídas**. O texto cheio de cada fase — spec na íntegra + bloco **\"Notas de implementação\"** — mora em `docs/history/fases/<ID>.md`, um arquivo por fase; este índice tem **uma linha por fase**, na ordem em que fecharam. Frio: `grep` pelo ID, leia só o arquivo da fase. Ao fechar uma fase, crie o arquivo dela e acrescente a linha aqui.",
    "",
    "---",
    "",
    *index,
    "",
]
open(src, "w", encoding="utf-8").write("\n".join(idx))
print(f"{len(blocks)} fases → {out_dir} ({avulso} avulsas; IDs repetidos: {[k for k,v in seen.items() if v>1]})")

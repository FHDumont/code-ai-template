# Spec de fase — formato

> Modelo de uma spec **redigida no plan mode** em `docs/SETUP.md`.
>
> Mantenha enxuto: a spec diz **o que** e **por quê**; o code mode decide o **como** aterrado no código.

---

# F-xxx — Título da fase

## Objetivo

Uma a três linhas: o que esta fase entrega e por quê.

## Escopo

**Entra:**

- ...

**NÃO entra (deixar explícito):**

- ...

## Passos

1. ...
2. ...

> Nomes de arquivo/símbolo abaixo já foram auditados no plan mode contra o código.

## Etapas

> Opcional. A fase pode ser entregue em **1+ etapas**, e **cada etapa é um commit** na branch da fase (regra de git no `AGENTS.md`). Liste aqui quando a spec se beneficia de fatiar; senão, omita e trate como etapa única.

1. **Etapa 1 — ...** · commit: `feat: ...`
2. **Etapa 2 — ...** · commit: `feat: ...`

## Critério de pronto

- ...
- docs vivos atualizados (CHANGELOG, ROADMAP; DECISOES/DEBITO se aplicável)

## Decisões em aberto

> Se houver decisão não resolvida, liste aqui pra o dono decidir **antes** de ir pro agente. Se a decisão for de arquitetura, ela vira um ADR ao ser tomada.

- (nenhuma) | ...

---

Model/effort de execução: `<modelo> · <effort>`


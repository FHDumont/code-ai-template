# Fragmento de fase — modelo

> `docs/changes/<id>.md`, preenchido no fecho da fase **paralela** (R-003). A integração (`scripts/integrar-fase.sh`) aplica cada seção no ledger dela e apaga o arquivo. Uma linha por item, no formato do ledger de destino: o do `CHANGELOG`, do `ROADMAP` e do débito do projeto (item de lista `- **F-xxx** — …` neste template; parágrafo `**F-xxx** — …` também é aceito, e a integração põe a linha em branco), item `- F-xxx — …` no `SETUP-HISTORICO`, linha de tabela no `DECISOES` (depois de `secao: <nome da seção>`). Seção vazia fica vazia. Sem linha em `changelog`, a integração sai 6. A fase solitária não tem fragmento: edita os ledgers na branch.

```
# F-012

## changelog

- **F-012** — tags nas notas — 2026-11-14

## historico

- F-012 — Tags nas notas → [`fases/F-012.md`](fases/F-012.md)

## roadmap-remove

F-012

## roadmap-add

- **F-020** — exportar notas — depende de F-012

## decisoes

secao: Método
| ADR-004 | Título | accepted |

## debito-add

**D-014** — o defeito — 🟡 importante. Correção: o que fazer.

## debito-resolve

D-009

## debito-resolvido

**D-009** — resolvido na F-012: como.
```

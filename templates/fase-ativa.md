# Registro de fase paralela — modelo

> Escrito por `scripts/abrir-fase.sh` em `docs/fases-ativas/<id>.md`, na branch da fase (R-002). Uma chave por linha. `arquivos` é lista separada por vírgula; diretório leva barra no fim.

```
id: F-012
titulo: Tags nas notas
modo: paralela
status: executando   # executando | pronta-para-integrar (produção, espera o ok do dono) | integrando (só a integração rodando)
branch: fase/F-012-tags
depende_de: -
arquivos: src/notas/, src/tags.ts
areas: notas, tags
bots: -
escopo: Uma linha do que a fase entrega.
```

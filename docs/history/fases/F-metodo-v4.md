# F-metodo-v4 — O que o Vaulty aprendeu depois da v3, de volta pro template

## Objetivo

Trazer pro template — a fonte da verdade do método — as regras e a mecânica que o Vaulty refinou entre a F-262 e a F-335 direto no próprio repo, deixando de fora o que é da stack dele.

## O que entrou

- **Fonte única do método** — `AGENTS.md` declara que regra agnóstica nova entra nele, nunca só num flavor; flavor só duplica em runbook de skill, com nota de sync.
- **Plan mode copia a spec pro `SETUP.md`** — logo depois da aprovação, sem commitar (o commit é da execução, junto com o primeiro código), porque a execução pode ser de outro agente que não lê o arquivo de plano do Claude Code. `CLAUDE.md`, `planejar-fase` (passos 7–10), `grilling` e `templates/spec-fase.md` alinhados; `SETUP.md` fica vazio no fecho.
- **Fecho em commit `docs:` próprio** — permitido desde que não carregue código.
- **Problema surgido na fase se resolve na fase** + **critério de adjacência** (mesmo caminho, uma linha, sem contrato, sem decisão do dono).
- **ADR é rascunho até o merge** — corrige-se no lugar enquanto a branch não integrou; `docs/adr/TEMPLATE.md` alinhado.
- **Débito** — "aceito como limitação" sai do vivo (vai pro resolvido com nota de aceite); item sem `Correção:` não é débito; "NÃO entra" da spec não vira débito automaticamente.
- **Git** — `gh pr merge --rebase --delete-branch` como rota única de limpeza (o hook barra `branch -D`).
- **`revisor-fecho`** — subagente da revisão de fecho com o checklist da casa, em versão agnóstica de stack; `fechar-fase` passo 2 o dispara.
- **Hook de git** — corpo de heredoc é dado e separador entre aspas não abre cláusula, como já era no `block-comandos-do-dono.sh`; casos novos no `.test.sh`.
- **Fontes avulsas** em `docs/reference/referencias.md` (o post do Spotify, origem do "só hook enforça" e do `varredura`), puladas pela `/verificar-referencia`.

## Notas de implementação

- **Ficou de fora, por ser da stack do Vaulty:** hooks `lint-arquivo.sh` (eslint no arquivo editado) e `journal-em-ordem.sh` (journal do Drizzle), subagente `auditor-migration`, skills `nova-migration` e `screenshot-lab`, MCP `postgres-lab`, allowlist de permissões, bucket `docs/manual/`, e as regras de UI/código do `CONVENCOES.md`. O padrão "hook PostToolUse de lint por arquivo" é bom candidato a exemplo comentado se um segundo projeto pedir.
- **Onde o template já estava à frente, ficou o template:** o Cursor rule e o bloco de Etapas do `templates/spec-fase.md` (o Vaulty guarda a versão anterior à compressão da v3).
- O teste novo do heredoc falha no hook antigo (provado rodando o `.test.sh` novo contra o `block-dangerous-git.sh` do `main`).

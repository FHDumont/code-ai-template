# CONVENÇÕES

> Exemplo preenchido (stack TypeScript). Mostra a forma; o conteúdo é por-projeto.

## Linguagem / tipos

- Strict mode sempre. Sem `any` exceto em casos justificados com comentário.
- Validação de I/O com schema (ex.: Zod); tipos derivados do schema, não duplicados.
- Imports absolutos via paths do tsconfig (`@mc/core`, `@mc/db`, …).
- Sem `enum` do TS — preferir const objects + `as const`.

## Estilo

- Formatter compartilhado (Prettier) e linter (ESLint flat config).
- 2 espaços, aspas simples, trailing commas.

## Estrutura de arquivos

- Um arquivo, uma responsabilidade clara.
- ~300 linhas como referência de teto — acima, considerar split (mas não por princípio cego: se o arquivo é coerente, deixe).
- Co-locar testes: `foo.ts` + `foo.test.ts` na mesma pasta.

## Naming

- `camelCase` para variáveis e funções.
- `PascalCase` para tipos, interfaces, classes e componentes.
- `SCREAMING_SNAKE_CASE` para constantes globais.
- `kebab-case` para nome de arquivo (exceto componentes, que seguem o PascalCase do nome).
- Slugs no banco: `kebab-case`.

## Erros

- Não engolir erro em silêncio.
- Esperado → tipo discriminado (`Result<T, E>` ou similar) no core.
- Inesperado → propaga, captura no boundary (middleware de erro, error boundary de UI).

## Comentários

- Comente o **porquê**, não o **o quê** (código bom mostra o quê).
- Documente decisões não-óbvias e trade-offs aceitos.
- Sem código morto comentado — delete (o histórico fica no git).

## Testes

- Unit/integration com Vitest; e2e de UI com Playwright.
- Testes vivem ao lado do código (`*.test.ts`).
- Cobertura não é métrica vazia — foque em caminhos críticos (adapters, cálculo de custo, roteamento de output, fluxo de aprovação, orquestração).

## UI

- Componentes shadcn como base; wrappers customizados ao lado — não modificar o componente instalado.
- Acessibilidade: `aria-label` quando o texto não basta, foco visível, contraste AA, suporte a teclado em tudo.
- Desktop-first mas funcional em tablet; apps satélite mobile-friendly.
- Estados: loading = skeleton (não spinner), empty = ilustração + CTA, error = mensagem útil + retry.

## Antipadrões deste projeto

- `utils.ts`/`helpers.ts` genérico — função vive no domínio dela.
- Serializar config com `JSON.stringify` cru — use schema + serializador explícito.
- Logar prompt inteiro em stdout — vai pra observability.
- `process.env` espalhado — centralize com validação.
- Esquecer a migration no commit — schema e migration sempre juntos.
- Commit gigante — pequenos e semânticos; fase grande = vários commits.


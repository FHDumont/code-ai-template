---
name: verificar-referencia
description: Vigia os repos de referência registrados — puxa o que entrou desde o SHA revisado, classifica adotar/adaptar/ignorar, abre issues achado e avança o SHA.
disable-model-invocation: true
---

O método deste repo bebe de fontes externas. Elas continuam evoluindo depois que copiamos delas — esta é a passada que fecha o loop. Entrada e saída são fixas: lê `docs/reference/referencias.md`, escreve issues `achado` e o SHA novo. Nada de mudança de método aqui; a triagem é do plan mode.

Rode uma entrada de cada vez. Para cada uma em `docs/reference/referencias.md`:

1. **Atualize o clone.** `git -C <clone local> pull`. Sem clone na máquina? Diga ao dono onde clonar e siga pra próxima entrada.
2. **Levante o que entrou** desde o **SHA revisado** da entrada: `git -C <clone> log --oneline <sha>..HEAD` e `git -C <clone> diff --stat <sha>..HEAD`. Se a fonte tem CHANGELOG, `git -C <clone> diff <sha>..HEAD -- CHANGELOG.md` costuma ser o resumo mais barato. Zero commits → registre "sem novidades" e vá pra próxima.
3. **Leia o que parece relevante** — skill nova, mudança em skill que já adaptamos, princípio de método novo. Volume grande: dispare subagentes, um por área, e junte os relatos.
4. **Classifique cada novidade** em uma de três:
   - **adotar** — cabe no método como está, ou com ajuste cosmético.
   - **adaptar** — a ideia serve, a forma não; vale portar em pt-BR/no formato daqui.
   - **ignorar** — fora do escopo do template (versionamento, marketplace, stack específica). Ignorado é decisão: diga o porquê em uma linha no relato, e não abra issue.
5. **Abra uma issue `achado` por item de adotar/adaptar** — `gh issue create --label achado` —, cada uma com: o que é, o caminho do arquivo na fonte, o SHA em que apareceu, e por que vale aqui. Uma issue por item; item grande vira issue própria, não bullet dentro de outra.
6. **Avance o SHA.** Atualize `SHA revisado` e a data da entrada em `docs/reference/referencias.md` pro `HEAD` do clone, mesmo quando tudo foi ignorado — o SHA marca "revisado até aqui", não "adotado até aqui".
7. **Relate ao dono:** por entrada, quantos commits desde o SHA anterior, o que virou issue, e o que foi ignorado com o porquê.

As issues abertas aqui são matéria-prima solta. Quem decide o que vira fase é o próximo plan mode, pelo `/planejar-fase`.

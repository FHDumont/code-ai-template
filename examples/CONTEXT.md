# CONTEXT — linguagem ubíqua

> Exemplo preenchido pro projeto-brinquedo **Recados** (API self-hosted de notas). Mostra a forma; o conteúdo é por-projeto.

## Termos

**Nota**: um texto curto que o dono guarda pra si, com corpo, data de criação e tags.
_Evitar_: recado, post, item, entrada

**Tag**: rótulo livre de uma palavra que agrupa notas por assunto; uma nota tem zero ou mais.
_Evitar_: label, categoria, marcador

**Cofre**: o conjunto de notas de um dono — a unidade de isolamento entre contas e a fronteira de qualquer busca.
_Evitar_: workspace, espaço, coleção, biblioteca

**Dono**: a pessoa autenticada que criou as notas do cofre; num deploy self-hosted, quase sempre uma só.
_Evitar_: usuário, user, conta, cliente

**Arquivar**: tirar a nota das listagens sem apagá-la; ela continua buscável por ID e volta com um desarquivar.
_Evitar_: deletar, remover, esconder, soft-delete

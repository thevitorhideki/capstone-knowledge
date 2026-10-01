---
name: registrar
description: Salva no cérebro compartilhado do time (repositório capstone-knowledge) as decisões, aprendizados e mudanças de contrato front↔back da sessão atual, para que as outras pessoas e os agentes delas herdem esse conhecimento. Use ao concluir uma tarefa, antes de abrir um PR, ou quando o usuário pedir para registrar, salvar ou documentar o que foi decidido/aprendido.
---

# Registrar conhecimento

Objetivo: quem tocar este código depois (pessoa ou agente) herda o que foi decidido e aprendido nesta tarefa, sem redescobrir nem trabalhar com informação defasada.

## 1. Localize e sincronize

O caminho do repositório de conhecimento está no contexto do início da sessão (linha `Local:`). Se não estiver, use `$CAPSTONE_KNOWLEDGE_DIR` ou o diretório `capstone-knowledge` ao lado do repositório atual.

```bash
git -C <dir> pull --rebase --autostash
```

## 2. Garimpe a sessão

Revise a conversa e o trabalho feito (`git diff`, `git log` da branch) e separe três tipos de conhecimento:

- **Decisão** — uma escolha entre alternativas reais que define como o código deve ser escrito daqui pra frente. Ex.: "paginação por cursor, não offset", "frames da câmera processados em worker separado da API".
- **Aprendizado** — algo não óbvio que custou tempo descobrir e que o código sozinho não deixa claro. Ex.: pegadinha de biblioteca, comportamento do SDK/câmera, causa raiz de um bug, comando necessário para rodar algo.
- **Contrato** — mudança na interface entre front e back: endpoint, payload, enum, evento, código de erro.

Descarte: o que já é evidente lendo o código, detalhes que só valem para esta tarefa, preferências pessoais, e o que já está no PR/commit.

Se nada passar no filtro, diga isso ao usuário e pare. Nenhuma entrada é melhor que ruído — o índice é lido por todos em toda sessão.

## 3. Compare com o que já existe

Busque entradas sobre o mesmo assunto antes de escrever:

```bash
grep -ril "<termos>" <dir>/decisoes <dir>/aprendizados <dir>/contratos
```

- Nova decisão contradiz uma ativa: na antiga, mude `status: substituido` e preencha `substituido_por: decisoes/<novo-arquivo>.md`; na nova, cite a antiga em "Contexto".
- Aprendizado complementa ou corrige um existente: edite o existente e atualize `data`, em vez de criar outro.
- Aprendizado deixou de valer (ex.: bug corrigido na lib): marque `status: substituido`.

## 4. Escreva

- Um arquivo por entrada: `decisoes/AAAA-MM-DD-slug.md` ou `aprendizados/AAAA-MM-DD-slug.md`, copiando a estrutura de `templates/`.
- `autor`: saída de `git config user.name`. `repos`: `[backend]`, `[frontend]` ou `[ambos]`. `pr`: link do PR, se já existir.
- `resumo`: uma linha autossuficiente — é o que aparece no índice de todo mundo. Quem ler só o resumo já deve saber o que fazer.
- Contratos são documentos vivos: edite `contratos/<dominio>.md` no lugar (crie a partir de `templates/contrato.md` se não existir) e acrescente uma linha no "Histórico". O schema detalhado continua sendo o OpenAPI do FastAPI; o contrato registra semântica, regras e quem consome o quê.
- Seja curto e concreto. Aponte arquivos e símbolos do código (`app/services/camera.py:CameraPool`) em vez de copiar código.

## 5. Confirme e publique

Mostre ao usuário a lista do que vai ser registrado (tipo, título e resumo de cada entrada, e entradas antigas que serão marcadas como substituídas). Só depois da confirmação:

```bash
git -C <dir> add -A
git -C <dir> commit -m "docs(<backend|frontend|ambos>): <resumo curto>"
git -C <dir> pull --rebase
git -C <dir> push
```

Se o `pull --rebase` der conflito (normalmente em `contratos/`), resolva mantendo as duas mudanças e avise o usuário.

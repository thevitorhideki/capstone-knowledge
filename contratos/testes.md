---
titulo: Contrato de testes (autoria) e catálogo de operações
dominio: testes
atualizado_em: 2026-10-01
atualizado_por: Vitor Katakura
---

O schema detalhado vem do OpenAPI do backend. Este documento registra o que o schema não diz: semântica, regras, quem consome o quê e mudanças em andamento.

## O documento de teste (`definition`)

- Forma: `{schema_version: 1, name, description, steps: [{id, type, target?, inputs}]}`. O nome do teste é `definition.name`; não há campo `name` fora dele na gravação.
- `target`: `{role?, name?, path?}`, com ao menos `path` ou o par `role` + `name`. `path` é seletor Playwright (CSS e também `text="x" >> visible=true`, `:has-text()`, `role=switch`, `>> nth=0`). `name` aceita referência `{"from": "camera.username"}`.
- Referências `{"from": "camera.username" | "camera.password"}` só em input com `accepts_ref: true` (hoje só `ui.fill.value`) e em `target.name`. O documento nunca leva senha.
- `url` (`ui.goto`) e `pattern` (`wait.url`, `assert.url`) sem `http://`/`https://` são relativos à URL base da câmera: `#/` vira `http://ip:porta/#/`. `pattern` é glob casado contra a URL inteira, só com `*` (sem `/`) e `**` (qualquer coisa): `**/#/index/**`.
- `timeout_ms` vai de 100 a 120000 ms; ausente, vale o padrão do servidor (15000).
- Passo sem `id` recebe `step_` + 6 hex do servidor na gravação; o front pode mandar sem id.

## GET /api/operations?include_inactive=false

- Para que serve: a paleta do editor e a fonte do formulário de cada passo. Serializa o registro do engine, não a tabela.
- Regras e invariantes: item sem `id`; a chave é `type`. Cada item traz `type, family, label, group, function, requires_target, is_active, inputs`. Cada input traz `key, label, kind, required, accepts_ref` e só quando existem `min, max, unit, options, default`. `kind` ∈ `string | integer | boolean | enum | range | target | vertices` e diz qual controle desenhar. Hoje são 16 operações, todas `family: "ui"`. `include_inactive=true` serve para exibir passo antigo cuja operação saiu do catálogo.
- Erros esperados e como o front deve tratar: só 401.
- Implementado em (back): `app/api/routes/operations.py`, registro em `app/engine/registry.py` e `app/engine/operations/`.
- Consumido em (front): ainda não consumido (editor de passos).

## GET /api/test-cases?include_inactive=false&q=&driver_id=&driver_slug=

- Para que serve: lista de testes. Item: `{id, code, name, revision, is_active, allowed_drivers: [{id, slug, label}], updated_at}`, ordenado por `code`.
- Regras e invariantes: `q` busca por trecho (sem diferenciar maiúsculas) em `code` e no nome. `driver_slug` é provisório até o escopo 3; depois vale `driver_id`.
- Implementado em (back): `app/api/routes/test_cases.py:list_test_cases`.

## POST /api/test-cases

- Para que serve: criar teste sem passos. Corpo `{code, name, driver_ids}`, com `driver_ids` não vazio (o editor manda o driver da câmera aberta).
- Regras e invariantes: `code` aceita letras, dígitos, `.`, `_` e `-`, começando por letra ou dígito, até 64 caracteres. Responde 201 com o detalhe: os campos do item mais `definition` e `created_at`, com `revision: 1`.
- Erros esperados e como o front deve tratar: 409 `{"detail": {"error": "code_taken", "message"}}`; 422 `{"detail": {"error": "invalid_drivers", "message", "driver_ids"}}` para driver inexistente ou inativo; 422 do Pydantic para corpo malformado.

## GET /api/test-cases/{id}

- Para que serve: o detalhe, com `definition` já na versão corrente do formato. Teste inativo continua respondendo 200.

## PUT /api/test-cases/{id}

- Para que serve: gravar o documento inteiro. Corpo `{definition, revision}`, onde `revision` é a que o editor leu.
- Regras e invariantes: responde 200 com o detalhe (`revision + 1`) e `warnings` (ex.: operação inativa).
- Erros esperados e como o front deve tratar: 422 `{"detail": {"errors": [{step_id, field, message}], "warnings": [...]}}`, com `step_id: null` quando o problema é do documento; o editor marca `field` no passo `step_id`. 409 `{"detail": {"error": "revision_conflict", "message"}}`: alguém gravou no intervalo; recarregar antes de gravar de novo.

## PATCH /api/test-cases/{id}

- Para que serve: `{code?, is_active?}`. Desativar substitui a remoção.
- Regras e invariantes: corpo que não muda nada responde 200 sem avançar `updated_at`. Não mexe em `revision`.
- Erros esperados e como o front deve tratar: 409 `code_taken`.

## PUT /api/test-cases/{id}/allowed-drivers

- Para que serve: substituir o conjunto de drivers permitidos. Corpo `{driver_ids}`, não vazio.
- Regras e invariantes: driver inativo só pode ficar se o teste já o declarava.
- Erros esperados e como o front deve tratar: 422 para lista vazia e para `invalid_drivers`.

## POST /api/test-cases/validate

- Para que serve: validar um documento sem gravar. Corpo `{definition}`, resposta 200 `{errors, warnings}`, no mesmo formato do 422 do PUT.

## POST /api/test-cases/{id}/duplicate

- Para que serve: cópia com ids de passo novos e os mesmos drivers. Corpo `{code}`. 201, ou 409 `code_taken`.

## GET /api/test-cases/{id}/export · POST /api/test-cases/import

- Para que serve: o export é um anexo (`Content-Disposition: attachment; filename="<code>.json"`) com `{code, name, definition, driver_slugs}`, sem id nem dado de ambiente. O import recebe `{code, definition, driver_ids}`: o front traduz `driver_slugs` em ids via `GET /api/drivers`.
- Regras e invariantes: o import nunca sobrescreve. `code` repetido responde 409 `code_taken` e documento inválido responde 422 como no PUT.

## Mudanças em andamento

- `feat/testes-engine` / PR #9 (rascunho) — tudo acima — merge depois do escopo 1 (fila).
- Glue pós-merge do escopo 2: `GET /api/cameras/{id}/test-cases` é removida. O front passa a usar `GET /api/test-cases?driver_slug=<driver da câmera>` e, depois do escopo 3, `?driver_id=`. Entra também `GET /api/test-cases/{id}/runs?limit=`.

## Histórico

- 2026-10-01 — catálogo de operações e rotas de autoria de testes — https://github.com/capstone-insper/202602_INTELBRAS_VisaoComputacional_Backend/pull/9

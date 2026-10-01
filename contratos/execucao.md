---
titulo: Contrato de execução (Runs, células, log e artefatos)
dominio: execucao
atualizado_em: 2026-10-01
atualizado_por: Vitor Katakura
---

O schema detalhado vem do OpenAPI do backend. Este documento registra o que o schema não diz: semântica, regras, quem consome o quê e mudanças em andamento.

Modelo em três níveis: **Run** (uma câmera; tem `status` de ciclo de vida `queued|running|completed|failed|canceled|interrupted`) → **célula** (um teste naquela câmera; `status` é veredito `passed|failed|blocked|skipped|canceled`, `null` enquanto não terminou) → **passo**. Runs irmãs de um mesmo disparo compartilham `batch_id`. `completed` quer dizer que terminou, não que passou. A API só enfileira; quem executa é o worker (`python -m app.worker`), então sem worker no ar as Runs ficam `queued`.

## POST /api/runs

- Para que serve: disparar N testes em M câmeras. Corpo: `{test_case_ids, camera_ids, tracing?}`. `scope: "all_cameras"` ainda é aceito, mas está deprecado.
- Regras e invariantes: responde `202 {batch_id, runs: [RunPublic]}` com **uma Run por câmera**, cada uma já com `cases` (células) em `position` 0..N-1 **na ordem de `test_case_ids`** — o back não reordena mais por tela; quem monta a seleção põe IF-001 primeiro. `tracing` ausente usa `TRACING_ENABLED`. Run nasce `queued`, com `camera: null` (o retrato da câmera só é preenchido quando o worker toma a Run).
- Erros esperados e como o front deve tratar: validação tudo ou nada, nada é criado: `404` com `detail` string para câmera ou teste inexistente; `422` com `detail` string para lista vazia, id repetido ou teste sem passos.
- Implementado em (back): `app/api/routes/runs.py:create_runs`, `app/services/run_dispatch.py`.
- Consumido em (front): `src/lib/api.ts` (`createRun`), `src/pages/NewRunPage.tsx` — hoje esperam `Run` único com `results`/`log`.

## GET /api/runs?limit=20&before=&batch_id=&status=&camera_id=&test_case_id=

- Para que serve: histórico paginado e remontagem de um disparo (`batch_id`).
- Regras e invariantes: responde `{items: [RunPublic], next_before}`, mais recente primeiro; `items[].cases` vem `null` (só o detalhe traz células). Para a próxima página, mande `before=<next_before>`; `next_before: null` é fim. `limit` 1..100.
- Erros esperados e como o front deve tratar: `422` se `before` não for id de Run existente.
- Consumido em (front): `src/lib/useRuns.ts`, `src/pages/ReportsPage.tsx` — hoje esperam array puro.

## GET /api/runs/{id}

- Para que serve: polling da Run e tela de relatório.
- Regras e invariantes: `RunPublic` com `cases: [RunCasePublic]` **sem passos**. Cada célula traz `test_case_code`, `test_case_name`, `test_case_revision`, `status`, `duration_ms` (inteiro, ms), `message` e `artifacts: [{id, kind: "trace"|"screenshot", media_type, size_bytes, run_step_id, created_at}]`. `camera` é o retrato `{name, ip_address, port, base_path, model, firmware_version, driver}` do momento da execução (`null` enquanto `queued`). Não há mais `results`, `log`, `trace_available`, `evidence_available` nem `trace_size_bytes`: trace disponível = existe artefato `kind="trace"` na célula, e o tamanho é `size_bytes` (avisar antes de abrir zip grande). `tracing: true` sem artefato `trace` quer dizer que a gravação falhou.
- Erros esperados e como o front deve tratar: `404`.
- Consumido em (front): `src/lib/useRunView.ts`, `src/pages/RunningPage.tsx`, `src/pages/ReportPage.tsx`, `src/pages/FailPage.tsx`, `src/lib/apiTypes.ts` (`Run`, `CaseResult`).

## GET /api/runs/{id}/log?after_seq=0

- Para que serve: log ao vivo e de Runs antigas, pela mesma rota.
- Regras e invariantes: `{entries: [{seq, timestamp, message}]}` só com o que veio depois de `after_seq`; `0` traz tudo. Guarde o maior `seq` recebido e mande no próximo polling. O log não expira.
- Erros esperados e como o front deve tratar: `404`.

## GET /api/runs/{id}/cases/{case_id}

- Para que serve: diagnóstico de uma célula.
- Regras e invariantes: `RunCasePublic` + `steps: [{id, step_id, position, type, status, duration_ms, error_category, error_message}]` + `definition_snapshot`. Enquanto os testes ainda são handlers em código, cada célula executada tem **um** passo `type="legacy.handler"` e o snapshot é `{"schema_version": 0, code, name, description, steps: [{order, action, expected}]}`; isso muda quando o escopo 2 (engine) entrar. Screenshot de falha é o artefato com `run_step_id` igual ao `id` do passo.
- Erros esperados e como o front deve tratar: `404` também quando a célula é de outra Run.

## POST /api/runs/{id}/cancel

- Para que serve: cancelar uma Run (não o lote inteiro).
- Regras e invariantes: Run `queued` vira `canceled` na hora, com as células `canceled`. Run `running` só ganha `cancel_requested: true` e continua `running`; o worker aplica entre uma célula e outra (a célula corrente nunca é interrompida), e só então a Run vira `canceled`. Responde `200 RunPublic` com `cases`.
- Erros esperados e como o front deve tratar: `409 {"detail": {"error": "run_finished", "message": "..."}}` se a Run já terminou; `404`.

## POST /api/runs/{id}/retry

- Para que serve: repetir o que não passou.
- Regras e invariantes: cria um disparo novo (`202 {batch_id, runs}`) na mesma câmera, só com as células de `status != passed`, na ordem original, e com o mesmo `tracing`. A Run de origem não é alterada.
- Erros esperados e como o front deve tratar: `409 {"detail": {"error": "run_not_finished", "message": "..."}}` se a origem ainda não terminou; `422` se todas as células passaram; `404`.

## GET /api/artifacts/{id}

- Para que serve: bytes de trace (`application/zip`) ou screenshot (`image/png`). Substitui `/api/runs/{run}/cases/{camera}/{caso}/trace` e `.../evidence`, que deixaram de existir.
- Regras e invariantes: exige `Bearer`, então o front baixa como `Blob` e entrega ao Trace Viewer embutido (mesmo desenho de hoje). `Content-Disposition: attachment; filename="<kind>-<id>.<ext>"`, `Cache-Control: private, max-age=3600`.
- Erros esperados e como o front deve tratar: `404` artefato ou objeto ausente (pode sumir da tela); `503` com `Retry-After: 30` é MinIO fora do ar — **não** apagar da tela, tentar de novo depois.
- Implementado em (back): `app/api/routes/artifacts.py`.
- Consumido em (front): `src/lib/api.ts` (`caseTrace`/`caseEvidence` hoje), `src/components/modals/TraceViewerModal.tsx`.

## Mudanças em andamento

- `feat/fila-execucao` / PR #10 (escopo 1) — tudo acima substitui o `Run` em memória com `results`/`log`; o front precisa migrar `apiTypes.ts`, o polling (`GET /runs/{id}` + `GET /runs/{id}/log?after_seq`) e os downloads para `GET /artifacts/{id}`. Aguardando merge em `develop`.
- `feat/testes-engine` (escopo 2), depois do merge: células passam a ter um passo por passo do teste (`type` como `ui.click`), `definition_snapshot` vira o documento do builder e entra `GET /api/test-cases/{id}/runs?limit=`.
- `feat/amarrar-banco` (escopo 3), Parte B: `POST /runs` passa a recusar câmera inativa e par teste×driver incompatível (`422 incompatible_pairs`), e `scope: all_cameras` só expande para câmeras ativas.

## Histórico

- 2026-10-01 — fila no Postgres e worker separado: `POST /runs` → `{batch_id, runs}`, Run com `cases`, log por `after_seq`, cancel/retry por Run, artefatos por id em `GET /artifacts/{id}` — https://github.com/capstone-insper/202602_INTELBRAS_VisaoComputacional_Backend/pull/10

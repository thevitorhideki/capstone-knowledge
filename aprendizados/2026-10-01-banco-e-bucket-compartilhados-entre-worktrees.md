---
titulo: Worktrees paralelas dividem camtest, camtest_test e o bucket de teste; isole antes de testar migração
data: 2026-10-01
autor: Vitor Katakura
repos: [backend]
status: ativo
substituido_por:
pr: https://github.com/capstone-insper/202602_INTELBRAS_VisaoComputacional_Backend/pull/10
tags: [ambiente, alembic, testes, worktree]
resumo: As worktrees usam o mesmo container camtest-db e o mesmo MinIO; rode pytest com TEST_DATABASE_URL e TEST_MINIO_BUCKET próprios e teste alembic upgrade/downgrade num banco descartável, nunca no camtest.
---

## Situação

Três escopos (fila, testes-engine, amarrar-banco) rodam em worktrees ao mesmo tempo, cada um com a sua migração saindo de `0002` (`0003_runs`, `0004_test_cases`, `0005_inventory`).

## O que descobrimos

- `alembic upgrade head` no `camtest` compartilhado grava `alembic_version` com uma revisão que as outras worktrees não conhecem, e o `alembic` delas passa a falhar com "Can't locate revision".
- A suíte faz `drop_all`/`create_all` no `camtest_test` e esvazia o bucket `camtest-test` antes de cada teste: duas worktrees rodando juntas derrubam uma à outra.
- `docker compose up` de dentro de uma worktree tenta criar outro `camtest-db` (o `container_name` é fixo) e falha com conflito de nome.

## Como lidar

```bash
docker exec camtest-db psql -U camtest -d postgres -c "create database camtest_test_<slug>" -c "create database camtest_<slug>"
TEST_DATABASE_URL=postgresql+psycopg://camtest:camtest@localhost:5433/camtest_test_<slug> TEST_MINIO_BUCKET=camtest-test-<slug> pytest -q
DATABASE_URL=postgresql+psycopg://camtest:camtest@localhost:5433/camtest_<slug> alembic upgrade head && alembic check && alembic downgrade 0002 && alembic upgrade head
```

Para testar a imagem, `docker compose build` funciona; para subir `api`/`worker`, aponte para `host.docker.internal:5433` e `:9000` em vez de subir o `db` de novo.

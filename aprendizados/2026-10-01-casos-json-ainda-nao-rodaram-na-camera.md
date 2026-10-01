---
titulo: Os 11 casos remontados em JSON ainda não rodaram contra a câmera real
data: 2026-10-01
autor: Vitor Katakura
repos: [backend]
status: ativo
substituido_por:
pr: https://github.com/capstone-insper/202602_INTELBRAS_VisaoComputacional_Backend/pull/9
tags: [engine, casos, camera, seeds]
resumo: Os seeds de alembic/seeds/test_cases foram validados só no Chromium com página sintética; na primeira execução na bancada, confira os seletores e acrescente ao IF-001 a asserção do usuário no cabeçalho.
---

## Situação

Os 11 casos (IF-001, IA-T00..T09) foram remontados como documentos JSON a partir dos handlers de `app/services/playwright/screens/`. A câmera de bancada (177.53.246.161:8209) estava fora do ar em 2026-10-01.

## O que descobrimos

- Os seeds passam em `validate`. As operações foram exercitadas no Chromium real, numa página sintética. Os seletores novos (`role=switch`, `text="X" >> visible=true` no lugar de `get_by_text(exact=True).filter(visible=True)`, `:has-text()` no lugar de `.filter(has_text=)`) deram a mesma contagem dos originais num DOM de teste, mas não no painel da câmera.
- O IF-001 termina em `wait.url "**/#/index/**"`. A asserção que provava o login com a credencial cadastrada (usuário visível no cabeçalho) ficou de fora porque o role do elemento não foi confirmado, e um `path` com o nome literal não pode entrar no documento.
- IA-T05 e IA-T06 assumem o IVS salvo inativo na câmera; IA-T02 confere só a coerência do estado inativo.

## Como lidar

- Na primeira Run na bancada, rode os 11 casos em ordem numa câmera VIP com o IVS salvo inativo e corrija os alvos que falharem, via `PUT /api/test-cases/{id}`.
- Com a câmera no ar, descubra o role do usuário no cabeçalho e acrescente ao IF-001 um `assert.visible` com `{"role": "<role>", "name": {"from": "camera.username"}}`.
- Em caso de dúvida sobre a intenção de cada caso, consulte o handler original no histórico do git (`screens/` sai no glue pós-merge).

---
titulo: Contrato de inventário (câmeras e drivers)
dominio: inventario
atualizado_em: 2026-10-01
atualizado_por: Vitor Katakura
---

O schema detalhado vem do OpenAPI do backend. Este documento registra o que o schema não diz: semântica, regras, quem consome o quê e mudanças em andamento.

## GET /api/cameras?include_inactive=false

- Para que serve: listar a bancada. Por padrão vem só `is_active=true`; `include_inactive=true` traz todas.
- Regras e invariantes: cada item traz `model`, `firmware_version` (pode ser `null`), `is_active` e `reservation`, que é `null` ou `{holder_kind: "editor_session"|"run", holder_ref, acquired_at}`. Nunca traz `password` nem `password_encrypted`. Enquanto o escopo 1 (fila) não entrar, `reservation` vem sempre `null`.
- Erros esperados e como o front deve tratar: só 401.
- Implementado em (back): `app/api/routes/cameras.py:list_cameras`, schema `CameraListItem`.
- Consumido em (front): `src/lib/useCameras.ts`, `src/pages/CamerasPage.tsx`.

## GET /api/cameras/{id}

- Para que serve: detalhe, com `model`, `firmware_version` e `is_active`. Câmera inativa continua respondendo 200.
- Regras e invariantes: **não** traz `reservation` (só a listagem traz).
- Implementado em (back): `cameras.py:get_camera`, schema `CameraPublic`.

## POST /api/cameras

- Para que serve: cadastrar. Corpo: `name`, `model`, `firmware_version?`, `ip_address`, `port?` (80), `driver`, `username`, `password`, `base_path?` ("/").
- Regras e invariantes: `model` e `password` são obrigatórios. `ip_address` precisa ser IP (v4 ou v6, nada de hostname nem `ip:porta`). A senha é cifrada no servidor e nunca volta. Responde 201 com a câmera.
- Erros esperados e como o front deve tratar: 422 de validação (lista do Pydantic, com "Endereço IP inválido" no IP); 422 com `detail` em string para driver desconhecido; 409 com `detail` em string para IP:porta repetido (inclui câmeras inativas).
- Consumido em (front): `src/components/modals/CameraFormModal.tsx`.

## PATCH /api/cameras/{id}

- Para que serve: edição parcial e **desativação** (`{"is_active": false}`), que substitui a remoção.
- Regras e invariantes: `null` é ignorado, exceto em `firmware_version`, onde limpa o valor. `password` só é regravada se vier no corpo. Corpo vazio responde 200 sem avançar `updated_at`.
- Erros esperados e como o front deve tratar: 409 `{"detail": {"error": "camera_busy", "message": "..."}}` ao desativar câmera reservada (Run ou sessão do editor). O front deve mostrar `message` e oferecer tentar de novo depois. Os demais 409/422 seguem o POST.

## DELETE /api/cameras/{id}

- **Removida** (405). Câmera sai de uso com `PATCH is_active=false`, o que preserva o histórico de Runs. O `RemoveCameraModal` e o `api.deleteCamera` do front precisam virar "desativar câmera".

## GET /api/drivers?include_inactive=false · POST /api/drivers · PATCH /api/drivers/{id}

- Para que serve: cadastro das famílias de interface (`intelbras-vip`, `intelbras-mibo`). Item: `{id, slug, label, is_active}`.
- Regras e invariantes: POST `{slug, label}` e PATCH `{label?, is_active?}` são só de admin (403 para os demais). `slug` é kebab-case minúsculo, único e imutável: mandar `slug` no PATCH dá 422.
- Erros esperados e como o front deve tratar: 409 `{"detail": {"error": "slug_taken", "message": "..."}}`.
- Implementado em (back): `app/api/routes/drivers.py`. **Ainda não registrado** no router: entra no ar depois do merge do escopo 2 (tabela `drivers`).

## Mudanças em andamento

- `feat/amarrar-banco` / PR #8 (rascunho): tudo acima. Merge só depois dos escopos 1 (fila) e 2 (testes-engine).
- Parte B do mesmo escopo, depois dos merges de E1 e E2: `driver_id` substitui `driver` no cadastro de câmera (driver inexistente ou inativo dá 422); a resposta passa a trazer `driver: {id, slug, label}` expandido; `GET /api/cameras?driver_id=`; `reservation` passa a refletir a reserva real; `POST /runs` recusa câmera inativa e par teste×driver sem compatibilidade (422 `incompatible_pairs`).

## Histórico

- 2026-10-01 — câmera com `model`/`firmware_version`/`is_active`, senha cifrada, sem DELETE, `reservation` na listagem, `camera_busy`; rotas `/drivers` escritas — https://github.com/capstone-insper/202602_INTELBRAS_VisaoComputacional_Backend/pull/8

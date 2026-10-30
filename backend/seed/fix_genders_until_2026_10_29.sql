-- Acerto ÚNICO pedido pelo Hugo (2026-10-29): todas as contas criadas até ao fim de 29/10/2026 (hora de Lisboa)
-- passam a género masculino. Contas criadas depois não são tocadas (o limite é fixo, por isso é seguro repetir).
-- Contas de demonstração já são masculinas e ficam de fora.
--   make fix-genders
BEGIN;
UPDATE users
SET gender = 'male', updated_at = now()
WHERE NOT is_demo
  AND gender <> 'male'
  AND created_at < timestamptz '2026-10-30 00:00:00+00'
  AND deleted_at IS NULL;
SELECT count(*) AS contas_masculinas_ate_29_10 FROM users WHERE NOT is_demo AND created_at < timestamptz '2026-10-30 00:00:00+00';
COMMIT;

-- SÓ PARA TESTES: simula o pagamento de todos os jogadores de uma equipa (ainda não há módulo de pagamentos).
-- Uso:  make pay-sim TEAM="Nome da equipa"      (Windows: .\scripts\dev.ps1 pay-sim "Nome da equipa")
-- A API confirma a equipa no minuto seguinte (se estiver completa e houver vagas).
UPDATE team_members m
SET paid_at = now()
FROM teams t
WHERE m.team_id = t.id AND NOT t.is_demo AND lower(t.name) = lower(:'team') AND m.paid_at IS NULL;

SELECT t.name AS equipa, count(m.user_id) AS jogadores, count(m.paid_at) AS pagos,
       (t.confirmed_at IS NOT NULL) AS confirmada
FROM teams t LEFT JOIN team_members m ON m.team_id = t.id
WHERE NOT t.is_demo AND lower(t.name) = lower(:'team')
GROUP BY t.id;

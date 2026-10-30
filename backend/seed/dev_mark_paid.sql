-- SÓ PARA TESTES: simula o pagamento de TODOS os jogadores de uma equipa com vaga reservada (ainda não há módulo
-- de pagamentos; na app cada jogador tem o botão "Pagar (simulado)"). A equipa fica confirmada.
-- Uso:  make pay-sim TEAM="Nome da equipa"      (Windows: .\scripts\dev.ps1 pay-sim "Nome da equipa")
-- Só funciona se o líder já fechou a equipa e a vaga está reservada (estado "a pagar").
UPDATE team_members m
SET paid_at = now()
FROM teams t
WHERE m.team_id = t.id AND NOT t.is_demo AND lower(t.name) = lower(:'team')
  AND t.reserved_at IS NOT NULL AND t.confirmed_at IS NULL AND m.paid_at IS NULL;

UPDATE teams t
SET confirmed_at = now()
WHERE NOT t.is_demo AND lower(t.name) = lower(:'team') AND t.reserved_at IS NOT NULL AND t.confirmed_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM team_members m WHERE m.team_id = t.id AND m.paid_at IS NULL);

SELECT t.name AS equipa, count(m.user_id) AS jogadores, count(m.paid_at) AS pagos,
       CASE WHEN t.confirmed_at IS NOT NULL THEN 'confirmada'
            WHEN t.reserved_at IS NOT NULL THEN 'vaga reservada (a pagar)'
            WHEN t.closed_at IS NOT NULL THEN 'fechada, em fila'
            ELSE 'em formação' END AS estado
FROM teams t LEFT JOIN team_members m ON m.team_id = t.id
WHERE NOT t.is_demo AND lower(t.name) = lower(:'team')
GROUP BY t.id;

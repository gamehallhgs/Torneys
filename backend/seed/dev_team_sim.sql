-- SÓ PARA TESTES das fases de fecho/reserva. Variáveis: action, team, tournament.
--   ready   : marca todos os jogadores da equipa como preparados (equipa ainda em formação)
--   expire  : faz expirar já a reserva de vaga (a API trata disso em ~15 s: penaliza quem não pagou)
--   release : liberta a vaga reservada de uma equipa (também de demonstração) e volta à formação;
--             se houver equipas em fila, a API dá a vaga à primeira em ~15 s
--   full    : põe o torneio "cheio" (máx. de equipas = vagas já ocupadas, mínimo 2), para testar a fila
--   status  : mostra o estado das equipas do torneio
-- Uso:  make team-sim ACTION=ready TEAM="Nome"           make team-sim ACTION=full TORNEIO="Outono"
SELECT :'action' = 'ready' AS a_ready, :'action' = 'expire' AS a_expire,
       :'action' = 'release' AS a_release, :'action' = 'full' AS a_full \gset

\if :a_ready
UPDATE team_members m SET ready = true
FROM teams t
WHERE m.team_id = t.id AND lower(t.name) = lower(:'team') AND t.closed_at IS NULL;
\endif

\if :a_expire
UPDATE teams SET reservation_expires_at = now() - interval '1 minute'
WHERE NOT is_demo AND lower(name) = lower(:'team') AND reserved_at IS NOT NULL AND confirmed_at IS NULL;
\endif

\if :a_release
UPDATE team_members m SET paid_at = NULL
FROM teams t
WHERE m.team_id = t.id AND lower(t.name) = lower(:'team') AND t.reserved_at IS NOT NULL AND t.confirmed_at IS NULL;
UPDATE teams
SET closed_at = NULL, payment_mode = NULL, share_cents = NULL, reserved_at = NULL, reservation_expires_at = NULL
WHERE lower(name) = lower(:'team') AND reserved_at IS NOT NULL AND confirmed_at IS NULL;
\endif

\if :a_full
UPDATE tournaments tr
SET max_teams = GREATEST(2, (SELECT count(*)::int FROM teams t WHERE t.tournament_id = tr.id AND t.reserved_at IS NOT NULL))
WHERE tr.status = 'registration_open' AND tr.name ILIKE '%' || :'tournament' || '%';
\endif

SELECT tr.name AS torneio, tr.max_teams AS vagas, t.name AS equipa,
       CASE WHEN t.confirmed_at IS NOT NULL THEN 'confirmada'
            WHEN t.reserved_at IS NOT NULL THEN 'vaga reservada (a pagar)'
            WHEN t.closed_at IS NOT NULL THEN 'fechada, em fila'
            ELSE 'em formação' END AS estado,
       (SELECT count(*) FROM team_members m WHERE m.team_id = t.id) AS jogadores,
       (SELECT count(*) FROM team_members m WHERE m.team_id = t.id AND m.ready) AS preparados,
       (SELECT count(*) FROM team_members m WHERE m.team_id = t.id AND m.paid_at IS NOT NULL) AS pagos,
       t.reservation_expires_at AS prazo
FROM teams t JOIN tournaments tr ON tr.id = t.tournament_id
WHERE NOT t.is_demo AND tr.status = 'registration_open'
  AND (lower(t.name) = lower(:'team') OR tr.name ILIKE '%' || :'tournament' || '%')
ORDER BY tr.name, t.closed_at NULLS LAST, t.name;

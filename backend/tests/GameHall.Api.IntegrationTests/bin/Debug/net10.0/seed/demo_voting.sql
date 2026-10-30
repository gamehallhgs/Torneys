-- Torneios TERMINADOS de demonstração para testar o pódio, os prémios e a votação (melhor jogador / melhor
-- guarda-redes). Correr DEPOIS de demo_tournaments.sql ("make seed" corre os dois). Tudo is_demo.
--
-- Cada torneio testa um caso (hora de fim relativa a agora; janela de abertura de votações = 6 h):
--   1 Liga Votação Aberta         terminou há 1 h; ronda 1 a decorrer com alguns votos
--   2 Taça Votação Empate         terminou há 3 h; ronda 1 fechada, EMPATE no melhor jogador (guarda-redes decidido);
--                                 janela aberta => "empate, a aguardar desempate"  (eliminatórias, 4 equipas, 3.º lugar)
--   3 Liga Desempate Aberto       terminou há 2 h; ronda 1 empatada entre 3 jogadores; ronda 2 (desempate) a decorrer
--   4 Liga Co-vencedores          terminou há 5 h; ronda 1 e ronda 2 empatadas => 2 co-vencedores
--   5 Liga Sem Votação            terminou há 2 dias; o gestor não abriu votação => sem prémios
--   6 Liga Votação Por Abrir      terminou há 30 min; ainda sem votação (o gestor ainda a pode abrir) => sem prémios
--   7 Taça Votação Decidida       terminou há 1 dia; ronda 1 com vencedores claros nas duas categorias
--   8 Liga Empate Sem Desempate   terminou há 8 h; ronda 1 empatada, janela fechada sem desempate => co-vencedores
--   9 Liga Desempate Decidido     terminou há 4 h; ronda 1 empatada e a ronda 2 decidiu um vencedor
-- Os votantes são utilizadores demo 253-300 (não jogam nestes torneios). Para testar com a TUA conta:
--   make voting-sim ACTION=verified|recent|participant|reset EMAIL=o.teu@email
BEGIN;

DELETE FROM tournaments
WHERE is_demo AND name IN (
  'Liga Votação Aberta', 'Taça Votação Empate', 'Liga Desempate Aberto', 'Liga Co-vencedores', 'Liga Sem Votação',
  'Liga Votação Por Abrir', 'Taça Votação Decidida', 'Liga Empate Sem Desempate', 'Liga Desempate Decidido');

CREATE TEMP TABLE _vs ON COMMIT DROP AS
SELECT * FROM (VALUES
  (1, 'Liga Votação Aberta',          'league',             interval '1 hour'),
  (2, 'Taça Votação Empate',          'single_elimination', interval '3 hours'),
  (3, 'Liga Desempate Aberto',        'league',             interval '2 hours'),
  (4, 'Liga Co-vencedores',           'league',             interval '5 hours'),
  (5, 'Liga Sem Votação',             'league',             interval '2 days'),
  (6, 'Liga Votação Por Abrir',       'league',             interval '30 minutes'),
  (7, 'Taça Votação Decidida',        'league',             interval '1 day'),
  (8, 'Liga Empate Sem Desempate',    'league',             interval '8 hours'),
  (9, 'Liga Desempate Decidido',      'league',             interval '4 hours')
) AS v(ti, name, format, ago);

INSERT INTO tournaments
  (id, name, description, organizer_name, sport, format, has_third_place, tiebreakers, status,
   registration_opens_at, registration_closes_at, starts_on, ends_on, location_name, location_address,
   entry_fee_cents, min_age, max_age, max_teams, min_players_per_team, max_players_per_team, is_demo,
   district, municipality, finished_at, voting_window_hours)
SELECT gen_random_uuid(), v.name,
       'Torneio terminado de demonstração para testar o pódio e a votação.',
       'Associação Desportiva Demo', 'futsal', v.format, v.format = 'single_elimination',
       CASE WHEN v.format = 'league' THEN ARRAY['points','head_to_head','goal_difference','goals_for','draw']
            ELSE ARRAY['penalties'] END,
       'finished',
       now() - interval '40 days', now() - interval '30 days', current_date - 2, current_date - 1,
       'Pavilhão Municipal de Braga', 'Av. da Liberdade 100, Braga',
       3000, 16, NULL, CASE WHEN v.format = 'league' THEN 3 ELSE 4 END, 7, 12, true,
       'Braga', 'Braga', now() - v.ago, 6
FROM _vs v;

-- Equipas (3 por liga, 4 nas eliminatórias), confirmadas.
CREATE TEMP TABLE _tt ON COMMIT DROP AS
SELECT t.id AS tournament_id, v.ti, n.n, n.name, n.color, (v.ti - 1) * 28 + (n.n - 1) * 7 AS base
FROM tournaments t
JOIN _vs v ON v.name = t.name
JOIN (VALUES (1, 'Águias do Tejo', '#E53935'), (2, 'Leões do Norte', '#FB8C00'),
             (3, 'Tubarões FC', '#1E88E5'), (4, 'Dragões Urbanos', '#43A047')) AS n(n, name, color)
  ON n.n <= CASE WHEN v.format = 'league' THEN 3 ELSE 4 END
WHERE t.is_demo;

INSERT INTO teams (id, tournament_id, name, color_hex, is_demo, closed_at, reserved_at, reservation_expires_at, confirmed_at, payment_mode, share_cents)
SELECT gen_random_uuid(), tt.tournament_id, tt.name, tt.color, true,
       now() - interval '35 days', now() - interval '35 days', now() - interval '34 days 23 hours', now() - interval '34 days', 'split', 429
FROM _tt tt;

CREATE TEMP TABLE _tm ON COMMIT DROP AS
SELECT tm.id AS team_id, tt.tournament_id, tt.ti, tt.n, tt.base
FROM _tt tt JOIN teams tm ON tm.tournament_id = tt.tournament_id AND tm.name = tt.name;

-- 7 jogadores por equipa: o 1.º é o guarda-redes (e o líder).
INSERT INTO team_members (team_id, tournament_id, user_id, position, paid_at)
SELECT tm.team_id, tm.tournament_id, u.id,
       (ARRAY['GK','CB','RB','LB','CM','RW','ST'])[k],
       now() - interval '34 days'
FROM _tm tm
CROSS JOIN generate_series(1, 7) k
JOIN users u ON u.is_demo AND u.email = 'demo.' || lpad((tm.base + k)::text, 3, '0') || '@gamehall.demo';

UPDATE teams t SET host_user_id = h.user_id
FROM (SELECT DISTINCT ON (team_id) team_id, user_id FROM team_members ORDER BY team_id, joined_at, user_id) h
WHERE t.id = h.team_id AND t.is_demo AND t.host_user_id IS NULL;

-- Jogos terminados. Ligas (3 equipas): a equipa 1 ganha tudo, a 2 ganha à 3 => pódio 1.ª, 2.ª, 3.ª.
INSERT INTO games (id, tournament_id, stage, round_number, round_label, match_number, home_team_id, away_team_id,
                   scheduled_at, field_name, status, home_goals, away_goals)
SELECT gen_random_uuid(), h.tournament_id, 'league', g.rnd, 'Jornada ' || g.rnd, g.rnd, h.team_id, a.team_id,
       now() - interval '3 days' + (g.rnd * interval '2 hours'), 'Campo 1', 'finished', g.hg, g.ag
FROM (VALUES (1, 1, 2, 3, 1), (2, 1, 3, 2, 0), (3, 2, 3, 1, 0)) AS g(rnd, hn, an, hg, ag)
JOIN _tm h ON h.n = g.hn
JOIN _tm a ON a.tournament_id = h.tournament_id AND a.n = g.an
JOIN _vs v ON v.ti = h.ti AND v.format = 'league';

-- Eliminatórias (4 equipas): meias 1v4 e 2v3; final 1v2 decidida por penáltis; 3.º lugar 3v4.
INSERT INTO games (id, tournament_id, stage, round_number, round_label, match_number, home_team_id, away_team_id,
                   scheduled_at, field_name, status, home_goals, away_goals, home_penalties, away_penalties)
SELECT gen_random_uuid(), h.tournament_id, g.stage, g.rnd, g.label, g.mn, h.team_id, a.team_id,
       now() - interval '3 days' + (g.mn * interval '2 hours'), 'Campo 1', 'finished', g.hg, g.ag, g.hp, g.ap
FROM (VALUES
  ('round', 1, 'Meias-finais', 1, 1, 4, 2, 0, NULL::int, NULL::int),
  ('round', 1, 'Meias-finais', 2, 2, 3, 1, 0, NULL, NULL),
  ('round', 2, 'Final',        3, 1, 2, 1, 1, 5, 4),
  ('third_place', 2, '3.º e 4.º lugar', 4, 3, 4, 3, 1, NULL, NULL)
) AS g(stage, rnd, label, mn, hn, an, hg, ag, hp, ap)
JOIN _tm h ON h.n = g.hn
JOIN _tm a ON a.tournament_id = h.tournament_id AND a.n = g.an
JOIN _vs v ON v.ti = h.ti AND v.format = 'single_elimination';

-- ---------------------------------------------------------------------------------------------
-- Votação. Código de jogador = equipa*100 + posição na equipa (101 = guarda-redes da equipa 1, 102 = o central...).
-- Votantes = utilizadores demo 253-300 (cada um vota uma vez por categoria e ronda).
-- ---------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.uid(tname text, code int) RETURNS uuid LANGUAGE sql AS $$
  SELECT u.id FROM _vs v JOIN users u ON u.is_demo
   AND u.email = 'demo.' || lpad((((v.ti - 1) * 28) + ((code / 100) - 1) * 7 + (code % 100))::text, 3, '0') || '@gamehall.demo'
  WHERE v.name = tname $$;

-- Ronda 1: todos os jogadores das equipas (melhor jogador) e os guarda-redes (melhor guarda-redes).
CREATE FUNCTION pg_temp.round1(tname text, opened interval, closes interval) RETURNS void LANGUAGE plpgsql AS $$
DECLARE rid uuid := gen_random_uuid();
BEGIN
  INSERT INTO voting_rounds (id, tournament_id, round_number, opened_at, closes_at)
  SELECT rid, t.id, 1, now() + opened, now() + closes FROM tournaments t WHERE t.is_demo AND t.name = tname;
  INSERT INTO voting_candidates (round_id, category, user_id, team_id)
  SELECT rid, c.category, m.user_id, m.team_id
  FROM team_members m
  JOIN teams tm ON tm.id = m.team_id AND tm.confirmed_at IS NOT NULL
  JOIN tournaments t ON t.id = m.tournament_id AND t.name = tname AND t.is_demo
  CROSS JOIN (VALUES ('best_player'), ('best_goalkeeper')) AS c(category)
  WHERE c.category = 'best_player' OR m.position = 'GK';
END $$;

-- Ronda 2 (desempate): só os empatados, numa categoria.
CREATE FUNCTION pg_temp.round2(tname text, opened interval, closes interval, cat text, codes int[]) RETURNS void LANGUAGE plpgsql AS $$
DECLARE rid uuid := gen_random_uuid();
BEGIN
  INSERT INTO voting_rounds (id, tournament_id, round_number, opened_at, closes_at)
  SELECT rid, t.id, 2, now() + opened, now() + closes FROM tournaments t WHERE t.is_demo AND t.name = tname;
  INSERT INTO voting_candidates (round_id, category, user_id, team_id)
  SELECT rid, cat, m.user_id, m.team_id
  FROM unnest(codes) code
  JOIN team_members m ON m.user_id = pg_temp.uid(tname, code)
  JOIN tournaments t ON t.id = m.tournament_id AND t.name = tname AND t.is_demo;
END $$;

-- [votantes] votantes demo "from".."to" (253-300) votam no jogador [code].
CREATE FUNCTION pg_temp.cast_votes(tname text, rnd int, cat text, code int, vfrom int, vto int) RETURNS void LANGUAGE sql AS $$
  INSERT INTO votes (round_id, category, voter_id, candidate_id)
  SELECT r.id, cat, u.id, pg_temp.uid(tname, code)
  FROM voting_rounds r JOIN tournaments t ON t.id = r.tournament_id AND t.is_demo AND t.name = tname
  JOIN users u ON u.is_demo AND u.email BETWEEN 'demo.' || lpad(vfrom::text, 3, '0') || '@gamehall.demo'
                                           AND 'demo.' || lpad(vto::text, 3, '0') || '@gamehall.demo'
  WHERE r.round_number = rnd $$;

-- 1 Liga Votação Aberta (ronda 1 a decorrer, 2 h e meia de duração restante)
SELECT pg_temp.round1('Liga Votação Aberta', interval '-30 minutes', interval '90 minutes');
SELECT pg_temp.cast_votes('Liga Votação Aberta', 1, 'best_player', 102, 253, 257);
SELECT pg_temp.cast_votes('Liga Votação Aberta', 1, 'best_player', 202, 258, 260);
SELECT pg_temp.cast_votes('Liga Votação Aberta', 1, 'best_player', 302, 261, 262);
SELECT pg_temp.cast_votes('Liga Votação Aberta', 1, 'best_goalkeeper', 101, 253, 256);
SELECT pg_temp.cast_votes('Liga Votação Aberta', 1, 'best_goalkeeper', 201, 257, 257);

-- 2 Taça Votação Empate (ronda 1 fechada: empate 4-4 no melhor jogador; guarda-redes decidido)
SELECT pg_temp.round1('Taça Votação Empate', interval '-150 minutes', interval '-30 minutes');
SELECT pg_temp.cast_votes('Taça Votação Empate', 1, 'best_player', 102, 253, 256);
SELECT pg_temp.cast_votes('Taça Votação Empate', 1, 'best_player', 202, 257, 260);
SELECT pg_temp.cast_votes('Taça Votação Empate', 1, 'best_player', 302, 261, 262);
SELECT pg_temp.cast_votes('Taça Votação Empate', 1, 'best_goalkeeper', 101, 253, 257);
SELECT pg_temp.cast_votes('Taça Votação Empate', 1, 'best_goalkeeper', 201, 258, 259);

-- 3 Liga Desempate Aberto (empate a 3 na ronda 1; ronda 2 a decorrer só com os 3 empatados)
SELECT pg_temp.round1('Liga Desempate Aberto', interval '-110 minutes', interval '-50 minutes');
SELECT pg_temp.cast_votes('Liga Desempate Aberto', 1, 'best_player', 102, 253, 255);
SELECT pg_temp.cast_votes('Liga Desempate Aberto', 1, 'best_player', 202, 256, 258);
SELECT pg_temp.cast_votes('Liga Desempate Aberto', 1, 'best_player', 302, 259, 261);
SELECT pg_temp.cast_votes('Liga Desempate Aberto', 1, 'best_goalkeeper', 101, 253, 256);
SELECT pg_temp.cast_votes('Liga Desempate Aberto', 1, 'best_goalkeeper', 301, 257, 257);
SELECT pg_temp.round2('Liga Desempate Aberto', interval '-10 minutes', interval '80 minutes', 'best_player', ARRAY[102, 202, 302]);
SELECT pg_temp.cast_votes('Liga Desempate Aberto', 2, 'best_player', 102, 253, 254);
SELECT pg_temp.cast_votes('Liga Desempate Aberto', 2, 'best_player', 202, 255, 255);

-- 4 Liga Co-vencedores (empate na ronda 1 e outra vez na ronda 2: ficam os 2 empatados)
SELECT pg_temp.round1('Liga Co-vencedores', interval '-290 minutes', interval '-230 minutes');
SELECT pg_temp.cast_votes('Liga Co-vencedores', 1, 'best_player', 102, 253, 256);
SELECT pg_temp.cast_votes('Liga Co-vencedores', 1, 'best_player', 202, 257, 260);
SELECT pg_temp.cast_votes('Liga Co-vencedores', 1, 'best_player', 302, 261, 261);
SELECT pg_temp.cast_votes('Liga Co-vencedores', 1, 'best_goalkeeper', 101, 253, 255);
SELECT pg_temp.cast_votes('Liga Co-vencedores', 1, 'best_goalkeeper', 201, 256, 256);
SELECT pg_temp.round2('Liga Co-vencedores', interval '-200 minutes', interval '-140 minutes', 'best_player', ARRAY[102, 202]);
SELECT pg_temp.cast_votes('Liga Co-vencedores', 2, 'best_player', 102, 253, 255);
SELECT pg_temp.cast_votes('Liga Co-vencedores', 2, 'best_player', 202, 256, 258);

-- 5 Liga Sem Votação e 6 Liga Votação Por Abrir: sem rondas.

-- 7 Taça Votação Decidida (vencedores claros: 202 melhor jogador, 301 melhor guarda-redes)
SELECT pg_temp.round1('Taça Votação Decidida', interval '-23 hours 50 minutes', interval '-22 hours 50 minutes');
SELECT pg_temp.cast_votes('Taça Votação Decidida', 1, 'best_player', 202, 253, 258);
SELECT pg_temp.cast_votes('Taça Votação Decidida', 1, 'best_player', 102, 259, 261);
SELECT pg_temp.cast_votes('Taça Votação Decidida', 1, 'best_player', 302, 262, 262);
SELECT pg_temp.cast_votes('Taça Votação Decidida', 1, 'best_goalkeeper', 301, 253, 256);
SELECT pg_temp.cast_votes('Taça Votação Decidida', 1, 'best_goalkeeper', 101, 257, 258);

-- 8 Liga Empate Sem Desempate (empate 3-3 no melhor jogador, sem ronda 2 e janela já fechada => co-vencedores)
SELECT pg_temp.round1('Liga Empate Sem Desempate', interval '-470 minutes', interval '-410 minutes');
SELECT pg_temp.cast_votes('Liga Empate Sem Desempate', 1, 'best_player', 102, 253, 255);
SELECT pg_temp.cast_votes('Liga Empate Sem Desempate', 1, 'best_player', 202, 256, 258);
SELECT pg_temp.cast_votes('Liga Empate Sem Desempate', 1, 'best_goalkeeper', 101, 253, 255);

-- 9 Liga Desempate Decidido (empate na ronda 1; a ronda 2 dá a vitória a 102)
SELECT pg_temp.round1('Liga Desempate Decidido', interval '-230 minutes', interval '-170 minutes');
SELECT pg_temp.cast_votes('Liga Desempate Decidido', 1, 'best_player', 102, 253, 255);
SELECT pg_temp.cast_votes('Liga Desempate Decidido', 1, 'best_player', 202, 256, 258);
SELECT pg_temp.cast_votes('Liga Desempate Decidido', 1, 'best_goalkeeper', 201, 253, 258);
SELECT pg_temp.round2('Liga Desempate Decidido', interval '-150 minutes', interval '-90 minutes', 'best_player', ARRAY[102, 202]);
SELECT pg_temp.cast_votes('Liga Desempate Decidido', 2, 'best_player', 102, 253, 258);
SELECT pg_temp.cast_votes('Liga Desempate Decidido', 2, 'best_player', 202, 259, 260);

COMMIT;

SELECT t.name AS torneio, round(extract(epoch FROM now() - t.finished_at) / 3600, 1) AS horas_desde_o_fim,
       (SELECT string_agg('r' || r.round_number || CASE WHEN r.closes_at > now() THEN ' (aberta)' ELSE ' (fechada)' END,
                          ', ' ORDER BY r.round_number)
        FROM voting_rounds r WHERE r.tournament_id = t.id) AS rondas,
       (SELECT count(*) FROM votes v JOIN voting_rounds r ON r.id = v.round_id WHERE r.tournament_id = t.id) AS votos
FROM tournaments t
WHERE t.is_demo AND t.status = 'finished' AND t.finished_at IS NOT NULL
ORDER BY t.finished_at DESC;

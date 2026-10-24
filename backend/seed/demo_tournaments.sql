-- Torneios de DEMONSTRAÇÃO (todos com is_demo = true). Para os apagar: make seed-remove.
-- Seguro de correr várias vezes: apaga primeiro os dados demo anteriores e volta a criá-los
-- com datas relativas a hoje.
BEGIN;

DELETE FROM teams WHERE is_demo;
DELETE FROM tournaments WHERE is_demo;
DELETE FROM users WHERE is_demo;

INSERT INTO tournaments
  (id, name, description, organizer_name, sport, format, has_third_place, tiebreakers, status,
   registration_opens_at, registration_closes_at, starts_on, ends_on, location_name, location_address,
   entry_fee_cents, min_age, max_age, max_teams, min_players_per_team, max_players_per_team, is_demo)
VALUES
  (gen_random_uuid(), 'Taça GameHall 7 - Outono',
   'Eliminatórias a eliminar com jogo de atribuição do 3.º lugar. Inscrições abertas a equipas de futebol 7.',
   'Associação Desportiva Demo', 'football7', 'single_elimination', true,
   ARRAY['penalties'], 'registration_open',
   now() - interval '5 days', now() + interval '10 days', current_date + 20, current_date + 21,
   'Pavilhão GameHall Norte', 'Rua do Desporto 12, Porto',
   6000, 18, NULL, 16, 9, 14, true),

  (gen_random_uuid(), 'Torneio Futsal Jovem',
   'Fase de grupos seguida de eliminatórias, para jovens dos 13 aos 17 anos.',
   'Clube Juventude Demo', 'futsal', 'groups_knockout', true,
   ARRAY['points','head_to_head','goal_difference','goals_for','fair_play','draw'], 'registration_open',
   now() - interval '2 days', now() + interval '14 days', current_date + 25, current_date + 27,
   'Pavilhão Municipal de Braga', 'Av. da Liberdade 100, Braga',
   3500, 13, 17, 12, 7, 12, true),

  (gen_random_uuid(), 'Liga Fut11 Lisboa',
   'Campeonato a duas voltas em campo de 11. Inscrições quase esgotadas.',
   'Federação Demo de Futebol', 'football11', 'league', false,
   ARRAY['points','head_to_head','goal_difference','goals_for','goals_against','wins','fair_play','draw'], 'registration_open',
   now() - interval '20 days', now() + interval '5 days', current_date + 12, current_date + 90,
   'Campo Municipal de Benfica', 'Estrada de Benfica 500, Lisboa',
   15000, 16, NULL, 12, 16, 22, true),

  (gen_random_uuid(), 'Copa Futsal Esgotada',
   'Torneio já com todas as vagas preenchidas (serve para testar o estado "cheio").',
   'Associação Desportiva Demo', 'futsal', 'single_elimination', false,
   ARRAY['penalties'], 'registration_open',
   now() - interval '15 days', now() + interval '3 days', current_date + 9, current_date + 10,
   'Pavilhão GameHall Sul', 'Rua do Mar 3, Faro',
   4000, 16, NULL, 8, 7, 12, true),

  (gen_random_uuid(), 'Open Fut9 Porto',
   'Dupla eliminação (quadro de vencidos). Inscrições já fechadas, começa em breve.',
   'Clube Juventude Demo', 'football9', 'double_elimination', false,
   ARRAY['penalties'], 'registration_closed',
   now() - interval '30 days', now() - interval '2 days', current_date + 3, current_date + 4,
   'Complexo Desportivo do Porto', 'Rua das Flores 45, Porto',
   8000, 16, NULL, 8, 11, 15, true),

  (gen_random_uuid(), 'Copa Futsal Verão',
   'Fase de grupos e eliminatórias. A decorrer.',
   'Federação Demo de Futebol', 'futsal', 'groups_knockout', true,
   ARRAY['points','head_to_head','goal_difference','goals_for','fair_play','draw'], 'ongoing',
   now() - interval '40 days', now() - interval '10 days', current_date - 2, current_date + 5,
   'Pavilhão GameHall Norte', 'Rua do Desporto 12, Porto',
   4500, 16, NULL, 8, 7, 12, true),

  (gen_random_uuid(), 'Liga Fut7 Primavera',
   'Campeonato em formato de liga. A decorrer.',
   'Associação Desportiva Demo', 'football7', 'league', false,
   ARRAY['points','head_to_head','goal_difference','goals_for','wins','draw'], 'ongoing',
   now() - interval '70 days', now() - interval '45 days', current_date - 20, current_date + 30,
   'Campo Sintético de Coimbra', 'Rua do Estádio 8, Coimbra',
   9000, 18, NULL, 6, 9, 14, true),

  (gen_random_uuid(), 'Torneio Fut7 Verão',
   'Edição terminada (campeão: Águias do Tejo).',
   'Clube Juventude Demo', 'football7', 'single_elimination', true,
   ARRAY['penalties'], 'finished',
   now() - interval '90 days', now() - interval '50 days', current_date - 35, current_date - 30,
   'Campo Sintético de Coimbra', 'Rua do Estádio 8, Coimbra',
   5000, 16, NULL, 8, 9, 14, true),

  (gen_random_uuid(), 'Taça Futsal Natal',
   'Edição terminada do ano passado.',
   'Associação Desportiva Demo', 'futsal', 'groups_knockout', true,
   ARRAY['points','head_to_head','goal_difference','goals_for','fair_play','draw'], 'finished',
   now() - interval '200 days', now() - interval '130 days', current_date - 125, current_date - 120,
   'Pavilhão Municipal de Braga', 'Av. da Liberdade 100, Braga',
   3000, 13, NULL, 4, 7, 12, true),

  (gen_random_uuid(), 'Rascunho (não aparece na app)',
   'Torneio em rascunho: serve para confirmar que não é público.',
   'Associação Desportiva Demo', 'futsal', 'league', false,
   ARRAY['points'], 'draft',
   NULL, now() + interval '30 days', current_date + 60, current_date + 90,
   'Pavilhão GameHall Sul', NULL,
   2000, 13, NULL, 8, 7, 12, true);

-- Distrito e concelho (valores válidos de Modules/Geo/PortugalGeo.cs) para testar o filtro por localidade.
UPDATE tournaments t
SET district = v.district, municipality = v.municipality
FROM (VALUES
  ('Taça GameHall 7 - Outono',      'Porto',  'Porto'),
  ('Torneio Futsal Jovem',          'Braga',  'Braga'),
  ('Liga Fut11 Lisboa',             'Lisboa', 'Lisboa'),
  ('Copa Futsal Esgotada',          'Faro',   'Faro'),
  ('Open Fut9 Porto',               'Porto',  'Vila Nova de Gaia'),
  ('Copa Futsal Verão',             'Porto',  'Matosinhos'),
  ('Liga Fut7 Primavera',           'Coimbra','Coimbra'),
  ('Torneio Fut7 Verão',            'Coimbra','Figueira da Foz'),
  ('Taça Futsal Natal',             'Braga',  'Guimarães'),
  ('Rascunho (não aparece na app)', 'Faro',   'Loulé')
) AS v(name, district, municipality)
WHERE t.is_demo AND t.name = v.name;

-- Equipas: cada torneio recebe as N primeiras da lista (nome e cor únicos por torneio).
CREATE TEMP TABLE _names ON COMMIT DROP AS
SELECT * FROM (VALUES
  (1,  'Águias do Tejo',     '#E53935'),
  (2,  'Leões do Norte',     '#FB8C00'),
  (3,  'Tubarões FC',        '#1E88E5'),
  (4,  'Dragões Urbanos',    '#43A047'),
  (5,  'Falcões United',     '#8E24AA'),
  (6,  'Lobos da Serra',     '#546E7A'),
  (7,  'Furacão Atlético',   '#00ACC1'),
  (8,  'Estrelas do Sul',    '#FDD835'),
  (9,  'Corsários SC',       '#6D4C41'),
  (10, 'Titãs da Baixa',     '#D81B60'),
  (11, 'Raposas do Vouga',   '#F4511E'),
  (12, 'Gaivotas Futsal',    '#3949AB')
) AS v(n, name, color);

WITH counts(tname, cnt) AS (VALUES
  ('Taça GameHall 7 - Outono',  5),
  ('Torneio Futsal Jovem',      3),
  ('Liga Fut11 Lisboa',        11),
  ('Copa Futsal Esgotada',      8),
  ('Open Fut9 Porto',           8),
  ('Copa Futsal Verão',         8),
  ('Liga Fut7 Primavera',       6),
  ('Torneio Fut7 Verão',        8),
  ('Taça Futsal Natal',         4),
  ('Rascunho (não aparece na app)', 2)
)
INSERT INTO teams (id, tournament_id, name, color_hex, is_demo)
SELECT gen_random_uuid(), t.id, n.name, n.color, true
FROM tournaments t
JOIN counts c ON c.tname = t.name
JOIN _names n ON n.n <= c.cnt
WHERE t.is_demo;

-- ---------------------------------------------------------------------------------------------
-- JOGADORES FICTÍCIOS, LOBBYS E CONFIRMAÇÃO (demo)
-- Utilizadores is_demo sem palavra-passe utilizável (não iniciam sessão). 264 adultos + 36 jovens (13-17).
-- Cada equipa recebe os jogadores (n-1)*22+1 .. ; o primeiro é o líder. Os mesmos jogadores aparecem em
-- vários torneios (um jogador pode estar em vários torneios, mas só numa equipa de cada).
-- ---------------------------------------------------------------------------------------------
CREATE TEMP TABLE _team_n ON COMMIT DROP AS
SELECT tm.id, tm.tournament_id, nm.n
FROM teams tm JOIN _names nm ON nm.name = tm.name
WHERE tm.is_demo;

CREATE TEMP TABLE _du ON COMMIT DROP AS
SELECT g AS idx, gen_random_uuid() AS id FROM generate_series(1, 300) g;

INSERT INTO users (id, email, password_hash, display_name, username, username_tag, birth_date, role,
                   email_verified_at, created_at, updated_at, is_demo)
SELECT du.id,
       'demo.' || lpad(du.idx::text, 3, '0') || '@gamehall.demo',
       '!demo-sem-login',
       nm.first || ' ' || nm.last,
       -- @joao.silva (único: 20 nomes x 15 apelidos) com tag fixa e previsível (para testar convites)
       translate(lower(nm.first || '.' || nm.last), 'áàâãäéèêëíìîïóòôõöúùûüçñ', 'aaaaaeeeeiiiiooooouuuucn'),
       lpad(((du.idx * 7) % 1000)::text, 3, '0'),
       CASE WHEN du.idx <= 264
            THEN date '1990-01-01' + ((du.idx * 37) % 5000)      -- adultos (~19 a 36 anos)
            ELSE date '2010-01-01' + ((du.idx * 17) % 700) END,  -- jovens (14-16 anos)
       0, now(), now(), now(), true
FROM _du du
CROSS JOIN LATERAL (SELECT
  (ARRAY['João','Rui','Tiago','Pedro','Diogo','André','Miguel','Bruno','Hugo','Nuno',
         'Rafael','Tomás','Gonçalo','Ricardo','Filipe','David','Marco','Luís','Sérgio','Vasco'])[1 + (du.idx - 1) % 20] AS first,
  (ARRAY['Silva','Costa','Mendes','Alves','Ramos','Pinto','Faria','Teixeira','Matos','Barros',
         'Ferreira','Santos','Oliveira','Pereira','Lopes'])[1 + ((du.idx - 1) / 20) % 15] AS last) nm;

-- Plano para os torneios com inscrições abertas (mínimo e máximo de jogadores vêm do torneio).
-- Sem linha no plano: a equipa tem o mínimo de jogadores e todos pagaram.
CREATE TEMP TABLE _plan (tname text, n int, members int, paid int) ON COMMIT DROP;
INSERT INTO _plan VALUES
  -- Taça GameHall 7 (mín. 9, máx. 14): confirmada / lobby cheio e confirmado / lobby cheio por pagar / completa por pagar / abaixo do mínimo
  ('Taça GameHall 7 - Outono', 1,  9,  9),
  ('Taça GameHall 7 - Outono', 2, 14, 14),
  ('Taça GameHall 7 - Outono', 3, 14, 11),
  ('Taça GameHall 7 - Outono', 4,  9,  4),
  ('Taça GameHall 7 - Outono', 5,  5,  0),
  -- Torneio Futsal Jovem (mín. 7, máx. 12): lobby cheio e confirmado / quase completa / começada
  ('Torneio Futsal Jovem', 1, 12, 12),
  ('Torneio Futsal Jovem', 2,  7,  3),
  ('Torneio Futsal Jovem', 3,  4,  0),
  -- Liga Fut11 (mín. 16, máx. 22): 11 de 12 vagas confirmadas, com lobbys cheios
  ('Liga Fut11 Lisboa', 1, 22, 22),
  ('Liga Fut11 Lisboa', 2, 20, 20),
  ('Liga Fut11 Lisboa', 3, 18, 18),
  -- Copa Futsal Esgotada (mín. 7, máx. 12): 8 de 8 confirmadas (cheio), algumas com lobby cheio
  ('Copa Futsal Esgotada', 1, 12, 12),
  ('Copa Futsal Esgotada', 2, 12, 12),
  ('Copa Futsal Esgotada', 3, 10, 10);

INSERT INTO team_members (team_id, tournament_id, user_id, position, paid_at)
SELECT x.id, x.tournament_id, du.id,
       CASE WHEN x.paid_n < x.m AND k % 4 = 0 THEN NULL   -- equipas por fechar: alguns ainda sem posição
            ELSE (ARRAY['GK','CB','CB','RB','LB','CDM','CM','CAM','RW','LW','ST','CF','RM','LM','RWB'])[1 + (k - 1) % 15]
       END,
       CASE WHEN k <= x.paid_n THEN now() - (k * interval '1 minute') END
FROM (
  SELECT tn.id, tn.tournament_id, tn.n, t.name AS tname,
         COALESCE(p.members, t.min_players_per_team) AS m,
         COALESCE(p.paid, COALESCE(p.members, t.min_players_per_team)) AS paid_n
  FROM _team_n tn
  JOIN tournaments t ON t.id = tn.tournament_id AND t.status <> 'draft'
  LEFT JOIN _plan p ON p.tname = t.name AND p.n = tn.n
) x
CROSS JOIN LATERAL generate_series(1, x.m) AS k
JOIN _du du ON du.idx = (CASE WHEN x.tname = 'Torneio Futsal Jovem' THEN 264 + (x.n - 1) * 12
                              ELSE (x.n - 1) * 22 END) + k;

-- O primeiro jogador de cada equipa é o líder (as equipas demo passam a poder receber pedidos).
UPDATE teams t
SET host_user_id = h.user_id
FROM (SELECT DISTINCT ON (team_id) team_id, user_id
      FROM team_members ORDER BY team_id, joined_at, user_id) h
WHERE t.id = h.team_id AND t.is_demo;

-- Equipa CONFIRMADA = mínimo de jogadores + todos pagaram (mesma regra da API).
UPDATE teams t
SET confirmed_at = now()
FROM tournaments tr
WHERE t.is_demo AND tr.id = t.tournament_id
  AND (SELECT count(*) FROM team_members m WHERE m.team_id = t.id) >= tr.min_players_per_team
  AND (SELECT count(*) FROM team_members m WHERE m.team_id = t.id AND m.paid_at IS NULL) = 0;

-- Definições do lobby (casos de teste): lobby fechado a pedidos e/ou membros que também convidam.
UPDATE teams t
SET closed_to_requests = v.closed, members_can_invite = v.members
FROM tournaments tr, (VALUES
  ('Taça GameHall 7 - Outono', 'Dragões Urbanos', true,  false),  -- fechado: só por convite
  ('Taça GameHall 7 - Outono', 'Tubarões FC',     false, true),   -- aberto e os membros convidam
  ('Torneio Futsal Jovem',     'Leões do Norte',  true,  true),   -- fechado e os membros convidam
  ('Liga Fut11 Lisboa',        'Furacão Atlético', true, false)   -- confirmada e fechada a pedidos
) AS v(tournament, team, closed, members)
WHERE t.is_demo AND tr.id = t.tournament_id AND tr.name = v.tournament AND t.name = v.team;

-- ---------------------------------------------------------------------------------------------
-- JOGOS, EVENTOS E DESTAQUES (demo). "n" = posição da equipa na lista acima (1 = Águias do Tejo).
-- ---------------------------------------------------------------------------------------------
-- Hash repetível e sem risco de overflow (abs de int4 mínimo daria erro).
CREATE FUNCTION pg_temp._h(text) RETURNS integer LANGUAGE sql IMMUTABLE AS
$$ SELECT abs(hashtext($1) % 2147483647) $$;


-- Liga Fut7 Primavera (6 equipas, 5 jornadas de 3 jogos, método do círculo).
INSERT INTO games (id, tournament_id, stage, group_name, round_number, round_label, match_number,
                   home_team_id, away_team_id, scheduled_at, field_name, status, home_goals, away_goals)
SELECT gen_random_uuid(), p.tournament_id, 'league', NULL, p.round, 'Jornada ' || p.round,
       row_number() OVER (ORDER BY p.round, p.hn),
       p.h, p.a,
       now() + (p.round - 3) * interval '7 days' + (p.hn * interval '2 hours'),
       'Campo ' || (1 + p.hn % 2),
       CASE WHEN p.round <= 2 THEN 'finished'
            WHEN p.round = 3 AND p.hn = 1 THEN 'running'
            WHEN p.round = 3 AND p.hn = 2 THEN 'postponed'
            WHEN p.round = 3 THEN 'scheduled'
            ELSE 'scheduled' END,
       CASE WHEN p.round <= 2 OR (p.round = 3 AND p.hn = 1) THEN pg_temp._h((p.h::text || p.a::text || 'h')) % 5 END,
       CASE WHEN p.round <= 2 OR (p.round = 3 AND p.hn = 1) THEN pg_temp._h((p.h::text || p.a::text || 'a')) % 4 END
FROM (
  SELECT x.tournament_id, x.n AS hn, y.n AS an, x.id AS h, y.id AS a,
         (CASE WHEN y.n = 6 THEN (2 * x.n) % 5 ELSE (x.n + y.n) % 5 END) + 1 AS round
  FROM _team_n x JOIN _team_n y ON y.tournament_id = x.tournament_id AND x.n < y.n
  JOIN tournaments t ON t.id = x.tournament_id AND t.name = 'Liga Fut7 Primavera'
) p;

-- Copa Futsal Verão (a decorrer): 2 grupos de 4 + eliminatórias por definir.
INSERT INTO games (id, tournament_id, stage, group_name, round_number, round_label, match_number,
                   home_team_id, away_team_id, scheduled_at, field_name, status, home_goals, away_goals)
SELECT gen_random_uuid(), p.tournament_id, 'group', p.grp, p.round, 'Jornada ' || p.round,
       row_number() OVER (ORDER BY p.grp, p.round, p.hn),
       p.h, p.a,
       now() - interval '3 days' + (p.round * interval '1 day') + (p.hn * interval '1 hour'),
       'Campo ' || (1 + p.hn % 2),
       CASE WHEN p.round <= 2 THEN 'finished'
            WHEN p.round = 3 AND p.grp = 'Grupo A' AND p.hn = 1 THEN 'running'
            ELSE 'scheduled' END,
       CASE WHEN p.round <= 2 OR (p.round = 3 AND p.grp = 'Grupo A' AND p.hn = 1)
            THEN pg_temp._h((p.h::text || p.a::text || 'h')) % 6 END,
       CASE WHEN p.round <= 2 OR (p.round = 3 AND p.grp = 'Grupo A' AND p.hn = 1)
            THEN pg_temp._h((p.h::text || p.a::text || 'a')) % 5 END
FROM (
  SELECT x.tournament_id, x.n AS hn, x.id AS h, y.id AS a,
         CASE WHEN x.n <= 4 THEN 'Grupo A' ELSE 'Grupo B' END AS grp,
         CASE WHEN (((x.n - 1) % 4) + 1, ((y.n - 1) % 4) + 1) IN ((1, 2), (3, 4)) THEN 1
              WHEN (((x.n - 1) % 4) + 1, ((y.n - 1) % 4) + 1) IN ((1, 3), (2, 4)) THEN 2
              ELSE 3 END AS round
  FROM _team_n x JOIN _team_n y ON y.tournament_id = x.tournament_id AND x.n < y.n
       AND (CASE WHEN x.n <= 4 THEN 1 ELSE 2 END) = (CASE WHEN y.n <= 4 THEN 1 ELSE 2 END)
  JOIN tournaments t ON t.id = x.tournament_id AND t.name = 'Copa Futsal Verão'
) p;

INSERT INTO games (id, tournament_id, stage, round_number, round_label, match_number, scheduled_at, field_name, status)
SELECT gen_random_uuid(), t.id, v.stage, v.round, v.label, v.match, now() + (v.match * interval '1 day'), 'Campo 1', 'scheduled'
FROM tournaments t
CROSS JOIN (VALUES
  ('round', 1, 'Meias-finais', 101), ('round', 1, 'Meias-finais', 102),
  ('round', 2, 'Final', 103), ('third_place', 2, '3.º e 4.º lugar', 104)
) AS v(stage, round, label, match)
WHERE t.is_demo AND t.name = 'Copa Futsal Verão';

-- Torneio Fut7 Verão (terminado; campeão Águias do Tejo): eliminatórias com um jogo decidido por penáltis.
INSERT INTO games (id, tournament_id, stage, round_number, round_label, match_number, home_team_id, away_team_id,
                   scheduled_at, field_name, status, home_goals, away_goals, home_penalties, away_penalties)
SELECT gen_random_uuid(), t.id, v.stage, v.round, v.label, v.match, h.id, a.id,
       t.starts_on::timestamptz + (v.match * interval '3 hours'), 'Campo 1', 'finished', v.hg, v.ag, v.hp, v.ap
FROM tournaments t
JOIN (VALUES
  ('round', 1, 'Quartos de final', 1, 1, 8, 3, 0, NULL::int, NULL::int),
  ('round', 1, 'Quartos de final', 2, 4, 5, 2, 1, NULL, NULL),
  ('round', 1, 'Quartos de final', 3, 2, 7, 2, 2, 4, 3),
  ('round', 1, 'Quartos de final', 4, 3, 6, 1, 0, NULL, NULL),
  ('round', 2, 'Meias-finais', 5, 1, 4, 2, 0, NULL, NULL),
  ('round', 2, 'Meias-finais', 6, 2, 3, 1, 0, NULL, NULL),
  ('third_place', 3, '3.º e 4.º lugar', 7, 4, 3, 1, 2, NULL, NULL),
  ('round', 3, 'Final', 8, 1, 2, 2, 2, 5, 4)
) AS v(stage, round, label, match, hn, an, hg, ag, hp, ap) ON true
JOIN _team_n h ON h.tournament_id = t.id AND h.n = v.hn
JOIN _team_n a ON a.tournament_id = t.id AND a.n = v.an
WHERE t.is_demo AND t.name = 'Torneio Fut7 Verão';

-- Taça Futsal Natal (terminada): um grupo de 4 (a equipa de menor n ganha sempre) + final e 3.º lugar.
INSERT INTO games (id, tournament_id, stage, group_name, round_number, round_label, match_number,
                   home_team_id, away_team_id, scheduled_at, field_name, status, home_goals, away_goals)
SELECT gen_random_uuid(), t.id, 'group', 'Grupo A', v.round, 'Jornada ' || v.round, v.match, h.id, a.id,
       t.starts_on::timestamptz + (v.match * interval '2 hours'), 'Campo 1', 'finished',
       1 + pg_temp._h((h.id::text || a.id::text)) % 3,
       pg_temp._h((a.id::text || h.id::text)) % 1
FROM tournaments t
JOIN (VALUES (1, 1, 1, 2), (1, 2, 3, 4), (2, 3, 1, 3), (2, 4, 2, 4), (3, 5, 1, 4), (3, 6, 2, 3))
     AS v(round, match, hn, an) ON true
JOIN _team_n h ON h.tournament_id = t.id AND h.n = v.hn
JOIN _team_n a ON a.tournament_id = t.id AND a.n = v.an
WHERE t.is_demo AND t.name = 'Taça Futsal Natal';

INSERT INTO games (id, tournament_id, stage, round_number, round_label, match_number, home_team_id, away_team_id,
                   scheduled_at, field_name, status, home_goals, away_goals)
SELECT gen_random_uuid(), t.id, v.stage, 1, v.label, v.match, h.id, a.id,
       t.starts_on::timestamptz + (v.match * interval '2 hours'), 'Campo 1', 'finished', v.hg, v.ag
FROM tournaments t
JOIN (VALUES ('third_place', '3.º e 4.º lugar', 7, 3, 4, 3, 1), ('round', 'Final', 8, 1, 2, 2, 1))
     AS v(stage, label, match, hn, an, hg, ag) ON true
JOIN _team_n h ON h.tournament_id = t.id AND h.n = v.hn
JOIN _team_n a ON a.tournament_id = t.id AND a.n = v.an
WHERE t.is_demo AND t.name = 'Taça Futsal Natal';

-- Eventos: golos (um evento por golo), assistências (cerca de 2 em cada 3 golos) e cartões.
-- Os jogadores são nomes fictícios (sem contas), escolhidos de forma repetível.
CREATE TEMP TABLE _pool ON COMMIT DROP AS
SELECT ARRAY['João Silva','Rui Costa','Tiago Mendes','Pedro Alves','Diogo Ramos',
             'André Pinto','Miguel Faria','Bruno Teixeira','Hugo Matos','Nuno Barros']::text[] AS names;

CREATE TEMP TABLE _played ON COMMIT DROP AS
SELECT g.id AS game_id, s.team_id, s.goals
FROM games g
JOIN tournaments t ON t.id = g.tournament_id AND t.is_demo
CROSS JOIN LATERAL (VALUES (g.home_team_id, g.home_goals), (g.away_team_id, g.away_goals)) AS s(team_id, goals)
WHERE g.status IN ('running', 'finished') AND s.team_id IS NOT NULL AND s.goals IS NOT NULL;

INSERT INTO game_events (id, game_id, team_id, player_name, type, minute)
SELECT gen_random_uuid(), p.game_id, p.team_id,
       pool.names[1 + pg_temp._h((p.game_id::text || p.team_id::text || k::text)) % 10],
       'goal',
       1 + pg_temp._h((p.game_id::text || p.team_id::text || k::text || 'm')) % 55
FROM _played p CROSS JOIN _pool pool
CROSS JOIN LATERAL generate_series(1, p.goals) AS k;

INSERT INTO game_events (id, game_id, team_id, player_name, type, minute)
SELECT gen_random_uuid(), p.game_id, p.team_id,
       pool.names[1 + (pg_temp._h((p.game_id::text || p.team_id::text || k::text)) % 10
                       + 1 + pg_temp._h((p.game_id::text || p.team_id::text || k::text || 'a')) % 9) % 10],
       'assist',
       1 + pg_temp._h((p.game_id::text || p.team_id::text || k::text || 'm')) % 55
FROM _played p CROSS JOIN _pool pool
CROSS JOIN LATERAL generate_series(1, p.goals) AS k
WHERE pg_temp._h((p.game_id::text || p.team_id::text || k::text || 'q')) % 3 <> 0;

INSERT INTO game_events (id, game_id, team_id, player_name, type, minute)
SELECT gen_random_uuid(), p.game_id, p.team_id,
       pool.names[1 + pg_temp._h((p.game_id::text || p.team_id::text || k::text || 'y')) % 10],
       'yellow_card',
       5 + pg_temp._h((p.game_id::text || p.team_id::text || k::text || 'ym')) % 50
FROM _played p CROSS JOIN _pool pool
CROSS JOIN LATERAL generate_series(1, pg_temp._h((p.game_id::text || p.team_id::text || 'yc')) % 3) AS k;

INSERT INTO game_events (id, game_id, team_id, player_name, type, minute)
SELECT gen_random_uuid(), p.game_id, p.team_id,
       pool.names[1 + pg_temp._h((p.game_id::text || p.team_id::text || 'r')) % 10],
       'red_card',
       20 + pg_temp._h((p.game_id::text || p.team_id::text || 'rm')) % 35
FROM _played p CROSS JOIN _pool pool
WHERE pg_temp._h((p.game_id::text || p.team_id::text || 'rc')) % 7 = 0;

-- Vídeos de destaque (demo): um clip de exemplo público dos documentos do Flutter, apenas para testar o leitor.
INSERT INTO game_highlights (id, game_id, url, title, duration_seconds)
SELECT gen_random_uuid(), x.id, 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
       'Resumo do jogo (vídeo de exemplo)', 10
FROM (
  SELECT g.id, row_number() OVER (PARTITION BY g.tournament_id ORDER BY g.match_number) AS rn
  FROM games g JOIN tournaments t ON t.id = g.tournament_id AND t.is_demo
  WHERE g.status = 'finished'
) x
WHERE x.rn <= 2;

COMMIT;

SELECT status, count(*) AS torneios FROM tournaments WHERE is_demo GROUP BY status ORDER BY status;
SELECT g.status, count(*) AS jogos FROM games g JOIN tournaments t ON t.id = g.tournament_id WHERE t.is_demo GROUP BY g.status ORDER BY g.status;
SELECT tr.name AS torneio, tr.max_teams AS vagas, count(*) AS equipas, count(t.confirmed_at) AS confirmadas
FROM tournaments tr JOIN teams t ON t.tournament_id = tr.id
WHERE tr.is_demo AND tr.status = 'registration_open' GROUP BY tr.id ORDER BY tr.name;


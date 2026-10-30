-- GameHall Torneios - migração 018: fim do torneio e votação do melhor jogador / melhor guarda-redes.
--
-- Estados do torneio (já existiam): registration_open -> registration_closed ("inscrições fechadas", continua "aberto")
-- -> ongoing (quando começa o primeiro jogo) -> finished (quando o resultado do último jogo é publicado).
-- finished_at = momento em que terminou; voting_window_hours = quantas horas depois o gestor ainda pode abrir
-- votações (definição dos admins, guardada em cada torneio quando termina; mudar a definição só afeta torneios
-- futuros e os que terminaram nas últimas 24 horas).

ALTER TABLE tournaments ADD COLUMN finished_at timestamptz NULL;
ALTER TABLE tournaments ADD COLUMN voting_window_hours integer NULL CHECK (voting_window_hours BETWEEN 0 AND 168);
UPDATE tournaments SET finished_at = updated_at, voting_window_hours = 6 WHERE status = 'finished';

-- Definições da plataforma, só os admins as mudam (por agora com SQL; o painel de admin vem mais tarde).
CREATE TABLE platform_settings (
  key         text        PRIMARY KEY,
  value       text        NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now()
);
INSERT INTO platform_settings (key, value) VALUES
  ('voting_window_hours', '6'),             -- o gestor só pode abrir uma ronda até X horas depois de o torneio terminar
  ('voting_min_voter_email_hours', '24'),   -- quem não participou só vota com o email verificado há mais de X horas
  ('voting_min_duration_minutes', '30'),    -- duração mínima de uma ronda
  ('voting_max_duration_minutes', '180');   -- duração máxima de uma ronda

-- Uma ronda de votação (1 = votação normal; 2 = desempate só entre os empatados no topo).
CREATE TABLE voting_rounds (
  id             uuid        PRIMARY KEY,
  tournament_id  uuid        NOT NULL REFERENCES tournaments (id) ON DELETE CASCADE,
  round_number   integer     NOT NULL CHECK (round_number IN (1, 2)),
  opened_at      timestamptz NOT NULL,
  closes_at      timestamptz NOT NULL,
  CONSTRAINT ck_voting_rounds_dates CHECK (closes_at > opened_at),
  CONSTRAINT ux_voting_rounds UNIQUE (tournament_id, round_number)
);

-- Quem se pode votar em cada categoria numa ronda.
CREATE TABLE voting_candidates (
  round_id  uuid NOT NULL REFERENCES voting_rounds (id) ON DELETE CASCADE,
  category  text NOT NULL CHECK (category IN ('best_player', 'best_goalkeeper')),
  user_id   uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  team_id   uuid NOT NULL REFERENCES teams (id) ON DELETE CASCADE,
  PRIMARY KEY (round_id, category, user_id)
);

-- Um voto por pessoa e categoria em cada ronda (pode ser mudado até a ronda fechar). Ninguém vota em si próprio.
CREATE TABLE votes (
  round_id      uuid        NOT NULL,
  category      text        NOT NULL,
  voter_id      uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  candidate_id  uuid        NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (round_id, category, voter_id),
  FOREIGN KEY (round_id, category, candidate_id)
    REFERENCES voting_candidates (round_id, category, user_id) ON DELETE CASCADE,
  CONSTRAINT ck_votes_not_self CHECK (voter_id <> candidate_id)
);
CREATE INDEX ix_votes_candidate ON votes (round_id, category, candidate_id);

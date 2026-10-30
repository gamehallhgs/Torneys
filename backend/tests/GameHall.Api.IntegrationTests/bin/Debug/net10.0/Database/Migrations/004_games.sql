-- GameHall Torneios - migração 004: jogos, eventos (golos, assistências, cartões) e vídeos de destaque.
-- Os jogos são apagados em cascata com o torneio (por isso os dados demo desaparecem com "make seed-remove").

CREATE TABLE games (
  id              uuid        PRIMARY KEY,
  tournament_id   uuid        NOT NULL REFERENCES tournaments (id) ON DELETE CASCADE,
  -- group = fase de grupos; league = jornada de liga; round = eliminatória; third_place = 3.º/4.º lugar
  stage           text        NOT NULL CHECK (stage IN ('group', 'league', 'round', 'third_place')),
  group_name      text        NULL,
  round_number    integer     NOT NULL DEFAULT 1 CHECK (round_number >= 1),
  round_label     text        NULL,                 -- "Quartos de final", "Jornada 3"...
  match_number    integer     NOT NULL DEFAULT 1 CHECK (match_number >= 1),
  home_team_id    uuid        NULL REFERENCES teams (id) ON DELETE SET NULL,   -- NULL = ainda por definir
  away_team_id    uuid        NULL REFERENCES teams (id) ON DELETE SET NULL,
  scheduled_at    timestamptz NULL,
  field_name      text        NULL,
  status          text        NOT NULL DEFAULT 'scheduled'
                  CHECK (status IN ('scheduled', 'running', 'finished', 'cancelled', 'postponed')),
  home_goals      integer     NULL CHECK (home_goals >= 0),
  away_goals      integer     NULL CHECK (away_goals >= 0),
  home_penalties  integer     NULL CHECK (home_penalties >= 0),   -- só em eliminatórias empatadas
  away_penalties  integer     NULL CHECK (away_penalties >= 0),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_games_different_teams CHECK (home_team_id IS NULL OR away_team_id IS NULL OR home_team_id <> away_team_id)
);
CREATE INDEX ix_games_tournament ON games (tournament_id, scheduled_at, round_number, match_number);

CREATE TABLE game_events (
  id           uuid        PRIMARY KEY,
  game_id      uuid        NOT NULL REFERENCES games (id) ON DELETE CASCADE,
  team_id      uuid        NOT NULL REFERENCES teams (id) ON DELETE CASCADE,
  user_id      uuid        NULL REFERENCES users (id) ON DELETE SET NULL,
  player_name  text        NOT NULL,                 -- nome mostrado; anonimizado se a conta for eliminada
  type         text        NOT NULL CHECK (type IN ('goal', 'assist', 'yellow_card', 'red_card')),
  minute       integer     NULL CHECK (minute BETWEEN 0 AND 130),
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_game_events_game ON game_events (game_id, minute);
CREATE INDEX ix_game_events_user ON game_events (user_id) WHERE user_id IS NOT NULL;

-- Vídeos curtos (máx. 1 minuto, até 1080p). Por agora só guardamos o endereço; o carregamento
-- de vídeos pelo gestor/árbitro vem com os painéis respetivos.
CREATE TABLE game_highlights (
  id                uuid        PRIMARY KEY,
  game_id           uuid        NOT NULL REFERENCES games (id) ON DELETE CASCADE,
  url               text        NOT NULL,
  title             text        NULL,
  duration_seconds  integer     NOT NULL CHECK (duration_seconds BETWEEN 1 AND 60),
  created_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_game_highlights_game ON game_highlights (game_id);

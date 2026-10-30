-- GameHall Torneios - migração 002: torneios e equipas (base).
-- A coluna is_demo marca dados de demonstração: "make seed-remove" apaga tudo o que for is_demo
-- (e só isso), por isso nunca se mistura com dados reais.

CREATE TABLE tournaments (
  id                      uuid        PRIMARY KEY,
  name                    text        NOT NULL,
  description             text        NULL,
  organizer_name          text        NOT NULL,
  sport                   text        NOT NULL CHECK (sport IN ('football7', 'football9', 'football11', 'futsal')),
  format                  text        NOT NULL CHECK (format IN ('single_elimination', 'double_elimination', 'groups_knockout', 'league')),
  has_third_place         boolean     NOT NULL DEFAULT false,
  tiebreakers             text[]      NOT NULL DEFAULT '{}',   -- ordem dos critérios de desempate
  status                  text        NOT NULL CHECK (status IN ('draft', 'registration_open', 'registration_closed', 'ongoing', 'finished', 'cancelled')),
  registration_opens_at   timestamptz NULL,
  registration_closes_at  timestamptz NOT NULL,
  starts_on               date        NOT NULL,
  ends_on                 date        NOT NULL,
  location_name           text        NOT NULL,
  location_address        text        NULL,
  entry_fee_cents         integer     NOT NULL DEFAULT 0 CHECK (entry_fee_cents >= 0),  -- por equipa
  min_age                 integer     NOT NULL DEFAULT 13 CHECK (min_age >= 13),
  max_age                 integer     NULL,
  max_teams               integer     NOT NULL CHECK (max_teams >= 2),
  min_players_per_team    integer     NOT NULL CHECK (min_players_per_team >= 1),   -- titulares + suplentes
  max_players_per_team    integer     NOT NULL,
  is_demo                 boolean     NOT NULL DEFAULT false,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_tournaments_dates CHECK (ends_on >= starts_on),
  CONSTRAINT ck_tournaments_age CHECK (max_age IS NULL OR max_age >= min_age),
  CONSTRAINT ck_tournaments_players CHECK (max_players_per_team >= min_players_per_team)
);
CREATE INDEX ix_tournaments_status_start ON tournaments (status, starts_on);
CREATE INDEX ix_tournaments_is_demo ON tournaments (is_demo) WHERE is_demo;

-- Base das equipas (a fase 4 acrescenta jogadores, pedidos, convites e lobby).
CREATE TABLE teams (
  id             uuid        PRIMARY KEY,
  tournament_id  uuid        NOT NULL REFERENCES tournaments (id) ON DELETE CASCADE,
  name           text        NOT NULL,
  color_hex      text        NOT NULL CHECK (color_hex ~ '^#[0-9A-F]{6}$'),
  host_user_id   uuid        NULL REFERENCES users (id) ON DELETE SET NULL,
  is_demo        boolean     NOT NULL DEFAULT false,
  created_at     timestamptz NOT NULL DEFAULT now()
);
-- Nome e cor únicos por torneio.
CREATE UNIQUE INDEX ux_teams_tournament_name ON teams (tournament_id, lower(name));
CREATE UNIQUE INDEX ux_teams_tournament_color ON teams (tournament_id, color_hex);
CREATE INDEX ix_teams_is_demo ON teams (is_demo) WHERE is_demo;

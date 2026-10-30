-- GameHall Torneios - migração 003: membros das equipas, pedidos para entrar e convites.
-- Regras garantidas pela própria base de dados (além das da API):
--   * um jogador só pode estar numa equipa por torneio (ux_team_members_tournament_user);
--   * só pode haver um pedido/convite pendente por par equipa-utilizador.

ALTER TABLE teams ADD CONSTRAINT ux_teams_id_tournament UNIQUE (id, tournament_id);

CREATE TABLE team_members (
  team_id        uuid        NOT NULL,
  tournament_id  uuid        NOT NULL,
  user_id        uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  position       text        NULL CHECK (position IN
                   ('GK', 'RB', 'CB', 'LB', 'RWB', 'LWB', 'CDM', 'CM', 'CAM', 'RM', 'LM', 'RW', 'LW', 'CF', 'ST')),
  joined_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (team_id, user_id),
  CONSTRAINT fk_team_members_team FOREIGN KEY (team_id, tournament_id)
    REFERENCES teams (id, tournament_id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX ux_team_members_tournament_user ON team_members (tournament_id, user_id);
CREATE INDEX ix_team_members_user ON team_members (user_id);

CREATE TABLE join_requests (
  id             uuid        PRIMARY KEY,
  team_id        uuid        NOT NULL REFERENCES teams (id) ON DELETE CASCADE,
  tournament_id  uuid        NOT NULL REFERENCES tournaments (id) ON DELETE CASCADE,
  user_id        uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  status         text        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled')),
  created_at     timestamptz NOT NULL DEFAULT now(),
  decided_at     timestamptz NULL
);
CREATE UNIQUE INDEX ux_join_requests_pending ON join_requests (team_id, user_id) WHERE status = 'pending';
CREATE INDEX ix_join_requests_user ON join_requests (user_id) WHERE status = 'pending';

CREATE TABLE team_invites (
  id               uuid        PRIMARY KEY,
  team_id          uuid        NOT NULL REFERENCES teams (id) ON DELETE CASCADE,
  tournament_id    uuid        NOT NULL REFERENCES tournaments (id) ON DELETE CASCADE,
  invited_user_id  uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  invited_by       uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  status           text        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
  created_at       timestamptz NOT NULL DEFAULT now(),
  decided_at       timestamptz NULL
);
CREATE UNIQUE INDEX ux_team_invites_pending ON team_invites (team_id, invited_user_id) WHERE status = 'pending';
CREATE INDEX ix_team_invites_user ON team_invites (invited_user_id) WHERE status = 'pending';

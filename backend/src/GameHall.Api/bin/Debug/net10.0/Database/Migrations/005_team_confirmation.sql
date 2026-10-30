-- GameHall Torneios - migração 005: confirmação de equipas.
-- Criar equipas é ilimitado. Uma equipa só fica CONFIRMADA (confirmed_at) quando tem o mínimo de jogadores
-- e todos os jogadores pagaram (paid_at). Só as primeiras max_teams equipas confirmadas ocupam vaga;
-- quando o torneio enche, as restantes são eliminadas. O módulo de pagamentos (futuro) preenche paid_at.

ALTER TABLE teams ADD COLUMN confirmed_at timestamptz NULL;
ALTER TABLE team_members ADD COLUMN paid_at timestamptz NULL;

CREATE INDEX ix_teams_confirmed ON teams (tournament_id) WHERE confirmed_at IS NOT NULL;

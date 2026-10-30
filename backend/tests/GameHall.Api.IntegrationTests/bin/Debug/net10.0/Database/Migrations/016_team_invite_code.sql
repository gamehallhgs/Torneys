-- GameHall Torneios - migração 016: convite por código (GH-XXXX).
-- Cada equipa tem um código. O líder escolhe se o código está ativo, se dá entrada direta (senão cria um
-- pedido para o líder aceitar) e se os membros o podem ver. Regenerar o código: máximo 3 por hora.

-- Alfabeto sem letras confusas (sem I, L, O, 0, 1): 31 símbolos, 4 posições.
CREATE FUNCTION gh_new_invite_code() RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  c text;
BEGIN
  LOOP
    c := 'GH-' || (SELECT string_agg(substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1), '')
                   FROM generate_series(1, 4));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM teams WHERE invite_code = c);
  END LOOP;
  RETURN c;
END
$$;

ALTER TABLE teams
  ADD COLUMN invite_code         text    NULL,
  ADD COLUMN invite_code_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN code_direct_entry   boolean NOT NULL DEFAULT true,
  ADD COLUMN members_see_code    boolean NOT NULL DEFAULT false;

UPDATE teams SET invite_code = gh_new_invite_code();

ALTER TABLE teams
  ALTER COLUMN invite_code SET NOT NULL,
  ALTER COLUMN invite_code SET DEFAULT gh_new_invite_code(),
  ADD CONSTRAINT ck_teams_invite_code CHECK (invite_code ~ '^GH-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{4}$');
CREATE UNIQUE INDEX ux_teams_invite_code ON teams (invite_code);

CREATE TABLE team_code_regens (
  team_id     uuid        NOT NULL REFERENCES teams (id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_team_code_regens ON team_code_regens (team_id, created_at);

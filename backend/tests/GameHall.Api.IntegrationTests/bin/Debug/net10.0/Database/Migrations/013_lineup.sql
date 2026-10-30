-- GameHall Torneios - migração 013: formação da equipa (estilo FIFA).
-- teams.formation: ex. '4-4-2' (guarda-redes + linhas). team_members.slot: lugar no campo
-- (0 = guarda-redes, 1.. = linhas da defesa para o ataque, da esquerda para a direita); NULL = suplente.
ALTER TABLE teams ADD COLUMN formation text NULL;
ALTER TABLE team_members ADD COLUMN slot integer NULL CHECK (slot IS NULL OR slot >= 0);
CREATE UNIQUE INDEX ux_team_members_slot ON team_members (team_id, slot) WHERE slot IS NOT NULL;

-- GameHall Torneios - migração 007: definições do lobby (só o líder as altera, a qualquer momento).
--   closed_to_requests : o lobby não aceita pedidos de entrada de fora (só entra quem o líder convidar).
--   members_can_invite : além do líder, os restantes membros também podem convidar.
ALTER TABLE teams ADD COLUMN closed_to_requests boolean NOT NULL DEFAULT false;
ALTER TABLE teams ADD COLUMN members_can_invite boolean NOT NULL DEFAULT false;

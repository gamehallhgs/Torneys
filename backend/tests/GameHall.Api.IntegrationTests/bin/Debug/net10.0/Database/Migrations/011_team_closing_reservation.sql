-- GameHall Torneios - migração 011: fechar equipa, reserva de vaga, pagamento (simulado) e penalização.
--
-- Vocabulário:
--   equipa PRIVADA  = não aceita pedidos de entrada (só convites)  -> is_private (antes closed_to_requests)
--   equipa FECHADA  = o líder fechou o lobby: ninguém entra nem sai e o pagamento fica disponível (closed_at)
-- Estados de uma equipa: formação -> fechada em fila (sem vaga livre) -> vaga reservada 30 min -> confirmada.
--   closed_at              : quando o líder fechou (define a ordem de chegada da fila)
--   payment_mode / share   : 'split' (cada um paga a sua parte, arredondada para cima) ou 'total' (o líder paga tudo)
--   reserved_at / expires  : vaga reservada e prazo para pagar (30 min)
--   confirmed_at           : todos pagaram (a vaga fica garantida; já existia)
-- A vaga conta como ocupada enquanto reserved_at não for nulo.

ALTER TABLE teams RENAME COLUMN closed_to_requests TO is_private;

ALTER TABLE teams
  ADD COLUMN closed_at               timestamptz NULL,
  ADD COLUMN payment_mode            text        NULL,
  ADD COLUMN share_cents             integer     NULL,
  ADD COLUMN reserved_at             timestamptz NULL,
  ADD COLUMN reservation_expires_at  timestamptz NULL;

ALTER TABLE team_members ADD COLUMN ready boolean NOT NULL DEFAULT false;

-- Equipas já confirmadas passam a ter o estado completo (fechadas, com vaga reservada e pagamento dividido).
UPDATE teams t
SET closed_at = t.confirmed_at,
    reserved_at = t.confirmed_at,
    reservation_expires_at = t.confirmed_at,
    payment_mode = 'split',
    share_cents = (SELECT CASE WHEN c.n = 0 THEN 0 ELSE (tr.entry_fee_cents + c.n - 1) / c.n END
                   FROM (SELECT count(*)::int AS n FROM team_members m WHERE m.team_id = t.id) c)
FROM tournaments tr
WHERE t.confirmed_at IS NOT NULL AND tr.id = t.tournament_id;

UPDATE team_members m SET ready = true
FROM teams t WHERE t.id = m.team_id AND t.confirmed_at IS NOT NULL;

ALTER TABLE teams
  ADD CONSTRAINT ck_teams_payment_mode CHECK (payment_mode IS NULL OR payment_mode IN ('split', 'total')),
  ADD CONSTRAINT ck_teams_share CHECK (share_cents IS NULL OR share_cents >= 0),
  -- Sem fecho não há mais nada; com fecho há modo e valor.
  ADD CONSTRAINT ck_teams_closed_state CHECK (
    (closed_at IS NULL AND payment_mode IS NULL AND share_cents IS NULL
       AND reserved_at IS NULL AND reservation_expires_at IS NULL AND confirmed_at IS NULL)
    OR (closed_at IS NOT NULL AND payment_mode IS NOT NULL AND share_cents IS NOT NULL)),
  -- A vaga e o prazo andam juntos; confirmar exige vaga reservada.
  ADD CONSTRAINT ck_teams_reservation CHECK (
    (reserved_at IS NULL) = (reservation_expires_at IS NULL)
    AND (confirmed_at IS NULL OR reserved_at IS NOT NULL));

CREATE INDEX ix_teams_reserved ON teams (tournament_id) WHERE reserved_at IS NOT NULL;
CREATE INDEX ix_teams_queue ON teams (tournament_id, closed_at) WHERE closed_at IS NOT NULL AND reserved_at IS NULL;
CREATE INDEX ix_teams_expiring ON teams (reservation_expires_at) WHERE reserved_at IS NOT NULL AND confirmed_at IS NULL;

-- Penalização de quem não pagou a tempo: não pode reservar vaga (a sua equipa não pode fechar) até until_at.
CREATE TABLE reservation_penalties (
  user_id        uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  tournament_id  uuid        NOT NULL REFERENCES tournaments (id) ON DELETE CASCADE,
  until_at       timestamptz NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, tournament_id)
);

-- GameHall Torneios - migração 009: central de notificações.
-- Genérica: "type" diz o que é e "data" leva as referências (por agora só "team_invite" com {"inviteId": ...}).
-- Os textos e o estado (pendente, aceite...) são lidos no momento da listagem, por isso nunca ficam desatualizados.
CREATE TABLE notifications (
  id          uuid        PRIMARY KEY,
  user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  type        text        NOT NULL,
  data        jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at  timestamptz NOT NULL DEFAULT now(),
  read_at     timestamptz NULL
);
CREATE INDEX ix_notifications_user ON notifications (user_id, created_at DESC);
CREATE INDEX ix_notifications_unread ON notifications (user_id) WHERE read_at IS NULL;

-- Convites que já estavam pendentes passam a aparecer como notificações novas.
INSERT INTO notifications (id, user_id, type, data, created_at)
SELECT gen_random_uuid(), i.invited_user_id, 'team_invite', jsonb_build_object('inviteId', i.id), i.created_at
FROM team_invites i
WHERE i.status = 'pending';

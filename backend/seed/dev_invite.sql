-- SÓ PARA TESTES: a equipa (do líder dela) convida a conta com o email indicado, como se o líder tivesse
-- enviado o convite na app. Cria o convite e a notificação (pontinho vermelho + aceitar/recusar).
-- Uso:  make invite-sim TEAM="Dragões Urbanos" TORNEIO="Outono" EMAIL=eu@exemplo.pt
--       (Windows: .\scripts\dev.ps1 invite-sim "Dragões Urbanos" eu@exemplo.pt "Outono")
-- TORNEIO é um pedaço do nome do torneio (para distinguir equipas com o mesmo nome em torneios diferentes).
-- Só convida quem ainda não está numa equipa desse torneio e se a equipa não estiver confirmada nem cheia.
WITH pick AS (
  SELECT t.id AS team_id, t.tournament_id, t.host_user_id AS host, u.id AS invitee
  FROM teams t
  JOIN tournaments tr ON tr.id = t.tournament_id AND tr.status = 'registration_open'
  JOIN users u ON lower(u.email) = lower(:'email')
  WHERE lower(t.name) = lower(:'team')
    AND tr.name ILIKE '%' || :'tournament' || '%'
    AND t.host_user_id IS NOT NULL
    AND t.host_user_id <> u.id
    AND t.confirmed_at IS NULL
    AND (SELECT count(*) FROM team_members m WHERE m.team_id = t.id) < tr.max_players_per_team
    AND NOT EXISTS (SELECT 1 FROM team_members m WHERE m.tournament_id = t.tournament_id AND m.user_id = u.id)
    AND NOT EXISTS (SELECT 1 FROM team_invites i WHERE i.team_id = t.id AND i.invited_user_id = u.id AND i.status = 'pending')
  LIMIT 1
), inv AS (
  INSERT INTO team_invites (id, team_id, tournament_id, invited_user_id, invited_by)
  SELECT gen_random_uuid(), team_id, tournament_id, invitee, host FROM pick
  RETURNING id, invited_user_id
)
INSERT INTO notifications (id, user_id, type, data)
SELECT gen_random_uuid(), invited_user_id, 'team_invite', jsonb_build_object('inviteId', id::text) FROM inv;

SELECT n.created_at AS notificacao, t.name AS equipa, tr.name AS torneio, i.status
FROM notifications n
JOIN team_invites i ON i.id = (n.data->>'inviteId')::uuid
JOIN teams t ON t.id = i.team_id JOIN tournaments tr ON tr.id = t.tournament_id
JOIN users u ON u.id = n.user_id
WHERE lower(u.email) = lower(:'email') AND n.read_at IS NULL
ORDER BY n.created_at DESC;

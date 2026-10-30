-- Testar a votação com a TUA conta (só desenvolvimento).
--   make voting-sim ACTION=verified    EMAIL=eu@exemplo.pt   -> email verificado há 2 dias (já podes votar)
--   make voting-sim ACTION=recent      EMAIL=eu@exemplo.pt   -> email verificado há 1 hora (NÃO podes votar: falta 1 dia)
--   make voting-sim ACTION=participant EMAIL=eu@exemplo.pt   -> entras numa equipa confirmada de "Liga Votação Aberta"
--                                                              (participantes votam mesmo com o email recente)
--   make voting-sim ACTION=reset       EMAIL=eu@exemplo.pt   -> apaga os teus votos e a tua participação nos torneios de teste
-- Variáveis psql: action, email.
\set ON_ERROR_STOP on
BEGIN;

SELECT id AS uid FROM users WHERE lower(email) = lower(:'email') AND NOT is_demo \gset
\if :{?uid}
\else
  \echo 'Conta não encontrada para :email'
  ROLLBACK;
  \quit
\endif

\if :{?action}
\else
  \set action verified
\endif

-- Em qualquer ação: o email verificado conforme a ação.
UPDATE users SET email_verified_at = CASE :'action'
    WHEN 'recent' THEN now() - interval '1 hour'
    WHEN 'participant' THEN now() - interval '1 hour'
    ELSE now() - interval '2 days' END
WHERE id = :'uid';

-- Tira sempre a conta dos torneios de teste de votação antes de a (re)colocar.
DELETE FROM votes WHERE voter_id = :'uid';
DELETE FROM team_members m USING tournaments t
WHERE m.user_id = :'uid' AND t.id = m.tournament_id AND t.is_demo AND t.status = 'finished';

INSERT INTO team_members (team_id, tournament_id, user_id, position, paid_at)
SELECT tm.id, tm.tournament_id, :'uid', 'CM', now()
FROM teams tm JOIN tournaments t ON t.id = tm.tournament_id
WHERE :'action' = 'participant' AND t.is_demo AND t.name = 'Liga Votação Aberta' AND tm.name = 'Tubarões FC';

SELECT :'action' AS acao, u.email, u.email_verified_at,
       EXISTS (SELECT 1 FROM team_members m JOIN tournaments t ON t.id = m.tournament_id
               WHERE m.user_id = u.id AND t.is_demo AND t.name = 'Liga Votação Aberta') AS participante
FROM users u WHERE u.id = :'uid';
COMMIT;

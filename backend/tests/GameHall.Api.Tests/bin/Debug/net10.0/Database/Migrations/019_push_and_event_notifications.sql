-- GameHall Torneios - migração 019: notificações push, emails de aviso, notificações de jogos e de votação.
--
-- Como funciona a entrega: TODAS as notificações nascem na tabela "notifications" (central da app). Dois
-- serviços em segundo plano (PushDispatcher e EmailDispatcher) olham para as que ainda não foram entregues
-- (pushed_at / emailed_at vazios) e enviam o push / email só dos tipos que o produto definiu. Assim, quem cria
-- a notificação não precisa de saber nada sobre push nem email.

-- Interruptor geral de push (Perfil). Por defeito ligado; o telemóvel só recebe se o sistema operativo deixar.
ALTER TABLE users ADD COLUMN push_enabled boolean NOT NULL DEFAULT true;

-- Um registo por telemóvel/instalação (token do Firebase Cloud Messaging).
CREATE TABLE device_tokens (
  id            uuid        PRIMARY KEY,
  user_id       uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  token         text        NOT NULL,
  platform      text        NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  last_seen_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ux_device_tokens_token UNIQUE (token)
);
CREATE INDEX ix_device_tokens_user ON device_tokens (user_id);

-- Estado de entrega. As notificações que já existem não devem gerar push/email de repente.
ALTER TABLE notifications ADD COLUMN pushed_at  timestamptz NULL;
ALTER TABLE notifications ADD COLUMN emailed_at timestamptz NULL;
UPDATE notifications SET pushed_at = now(), emailed_at = now();
CREATE INDEX ix_notifications_undelivered ON notifications (created_at)
  WHERE pushed_at IS NULL OR emailed_at IS NULL;

-- Jogos: "Jogo a começar" avisa uma única vez (30 min antes); mudar a hora volta a permitir o aviso.
ALTER TABLE games ADD COLUMN start_notified_at timestamptz NULL;

-- Votação: cada ronda avisa uma vez quando abre; o torneio avisa uma vez quando saem os resultados.
ALTER TABLE voting_rounds ADD COLUMN opened_notified_at timestamptz NULL;
ALTER TABLE tournaments   ADD COLUMN voting_results_notified_at timestamptz NULL;
-- Votações já existentes (seeds antigos) não avisam retroativamente.
UPDATE voting_rounds SET opened_notified_at = now();
UPDATE tournaments SET voting_results_notified_at = now() WHERE status = 'finished';

-- ---------------------------------------------------------------------------------------------------------
-- "Jogo marcado / alterado": avisa os jogadores das duas equipas quando o jogo ganha data, muda a data/hora ou o
-- campo, é adiado ou cancelado. É um trigger para funcionar seja quem for que altere o jogo (painel do gestor,
-- árbitro, scripts) sem ninguém se esquecer de avisar. As equipas de demonstração nunca avisam ninguém.
-- ---------------------------------------------------------------------------------------------------------
CREATE FUNCTION gh_game_change_notify() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_title   text;
  v_when    text;
  v_msg     text;
  v_home    text;
  v_away    text;
  v_tourn   text;
  v_changed boolean := false;
BEGIN
  IF NEW.status IN ('running', 'finished') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.scheduled_at IS DISTINCT FROM OLD.scheduled_at THEN
      NEW.start_notified_at := NULL;     -- nova hora: o aviso "a começar" volta a ser possível
    END IF;

    IF OLD.status IN ('running', 'finished') THEN
      RETURN NEW;
    END IF;

    IF NEW.status = 'cancelled' AND OLD.status <> 'cancelled' THEN
      v_title := 'Jogo cancelado'; v_changed := true;
    ELSIF NEW.status = 'postponed' AND OLD.status <> 'postponed' THEN
      v_title := 'Jogo adiado'; v_changed := true;
    ELSIF NEW.scheduled_at IS NOT NULL AND OLD.scheduled_at IS NULL THEN
      v_title := 'Jogo marcado'; v_changed := true;
    ELSIF NEW.status = 'scheduled'
          AND (NEW.scheduled_at IS DISTINCT FROM OLD.scheduled_at OR NEW.field_name IS DISTINCT FROM OLD.field_name)
          AND NEW.scheduled_at IS NOT NULL THEN
      v_title := 'Jogo alterado'; v_changed := true;
    END IF;
  ELSE
    IF NEW.scheduled_at IS NOT NULL AND NEW.status = 'scheduled' THEN
      v_title := 'Jogo marcado'; v_changed := true;
    END IF;
  END IF;

  IF NOT v_changed OR (NEW.home_team_id IS NULL AND NEW.away_team_id IS NULL) THEN
    RETURN NEW;
  END IF;

  SELECT name INTO v_home FROM teams WHERE id = NEW.home_team_id;
  SELECT name INTO v_away FROM teams WHERE id = NEW.away_team_id;
  SELECT name INTO v_tourn FROM tournaments WHERE id = NEW.tournament_id;

  v_msg := COALESCE(v_home, 'A definir') || ' vs ' || COALESCE(v_away, 'A definir') || ' (' || COALESCE(v_tourn, '') || ')';
  IF NEW.scheduled_at IS NOT NULL AND NEW.status = 'scheduled' THEN
    v_when := to_char(NEW.scheduled_at AT TIME ZONE 'Europe/Lisbon', 'DD/MM "às" HH24:MI');
    v_msg := v_msg || ': ' || v_when || COALESCE(' · ' || NEW.field_name, '') || '.';
  ELSIF NEW.status = 'postponed' THEN
    v_msg := v_msg || ': a nova data ainda não está definida.';
  ELSE
    v_msg := v_msg || '.';
  END IF;

  INSERT INTO notifications (id, user_id, type, data)
  SELECT gen_random_uuid(), m.user_id, 'game_changed',
         jsonb_build_object(
           'tournamentId', NEW.tournament_id, 'tournamentName', COALESCE(v_tourn, ''), 'gameId', NEW.id,
           'title', v_title, 'message', v_msg)
  FROM team_members m
  JOIN teams t ON t.id = m.team_id
  WHERE m.team_id IN (NEW.home_team_id, NEW.away_team_id) AND NOT t.is_demo;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_games_change_notify
  BEFORE INSERT OR UPDATE ON games
  FOR EACH ROW EXECUTE FUNCTION gh_game_change_notify();

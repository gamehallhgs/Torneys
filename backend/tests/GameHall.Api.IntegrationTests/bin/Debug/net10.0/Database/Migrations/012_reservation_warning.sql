-- GameHall Torneios - migração 012: aviso de "tempo a acabar" (enviado uma só vez por reserva).
ALTER TABLE teams ADD COLUMN expiry_warned_at timestamptz NULL;

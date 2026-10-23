-- GameHall Torneios - migração 006: marca utilizadores de demonstração (jogadores fictícios das equipas demo).
-- "make seed-remove" apaga tudo o que for is_demo (utilizadores incluídos). Estes utilizadores não têm
-- palavra-passe utilizável: não conseguem iniciar sessão.
ALTER TABLE users ADD COLUMN is_demo boolean NOT NULL DEFAULT false;
CREATE INDEX ix_users_is_demo ON users (is_demo) WHERE is_demo;

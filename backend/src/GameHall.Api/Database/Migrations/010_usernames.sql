-- GameHall Torneios - migração 010: username único (@hugo) + tag fixa de 3 algarismos (#482).
--  * username: 3 a 20 caracteres, minúsculas, números, "." e "_"; não começa nem acaba em "." ou "_"; sem ".." seguidos.
--    É único (sem distinguir maiúsculas: guardamos sempre em minúsculas). Mostra-se como @hugo.
--  * username_tag: 3 algarismos ao acaso, atribuídos na criação da conta e que NÃO mudam quando o username muda.
--    Para convidar é preciso o par completo (hugo#482); serve de travão contra convites em massa a nomes fáceis.
--  * username_changed_at: a mudança é permitida 1 vez por mês (a primeira mudança é livre).
--  * username_history: o username antigo fica reservado 30 dias (só o antigo dono o pode recuperar).
--  * username_lookup_failures: tentativas falhadas de convidar por username#tag (máx. 10 por hora por utilizador).
ALTER TABLE users ADD COLUMN username text NULL;
ALTER TABLE users ADD COLUMN username_tag text NULL;
ALTER TABLE users ADD COLUMN username_changed_at timestamptz NULL;

-- Utilizadores que já existem: username gerado a partir do nome (podem mudá-lo livremente uma vez).
WITH s AS (
  SELECT id, created_at, deleted_at,
         trim(both '.' from regexp_replace(
           translate(lower(display_name), 'áàâãäéèêëíìîïóòôõöúùûüçñ', 'aaaaaeeeeiiiiooooouuuucn'),
           '[^a-z0-9]+', '.', 'g')) AS s3
  FROM users
), b AS (
  SELECT id, created_at, deleted_at,
         CASE WHEN length(trim(both '.' from left(s3, 14))) < 3 THEN 'jogador'
              ELSE trim(both '.' from left(s3, 14)) END AS base
  FROM s
), r AS (
  SELECT id, deleted_at, base,
         (base = ANY (ARRAY['admin','administrador','administrator','root','system','sistema','suporte','support',
                            'gamehall','moderador','staff','arbitro','gestor','organizador','removido'])) AS reserved,
         row_number() OVER (PARTITION BY base ORDER BY created_at, id) AS rn
  FROM b
)
UPDATE users u
SET username = CASE
      WHEN r.deleted_at IS NOT NULL THEN 'removido_' || substr(replace(u.id::text, '-', ''), 1, 11)
      WHEN r.reserved OR r.rn > 1 THEN r.base || '_' || r.rn::text
      ELSE r.base END,
    username_tag = lpad(floor(random() * 1000)::int::text, 3, '0')
FROM r
WHERE r.id = u.id;

ALTER TABLE users ALTER COLUMN username SET NOT NULL;
ALTER TABLE users ALTER COLUMN username_tag SET NOT NULL;
ALTER TABLE users ADD CONSTRAINT ck_users_username
  CHECK (username ~ '^[a-z0-9][a-z0-9._]{1,18}[a-z0-9]$' AND username !~ '\.\.');
ALTER TABLE users ADD CONSTRAINT ck_users_username_tag CHECK (username_tag ~ '^[0-9]{3}$');
CREATE UNIQUE INDEX ux_users_username ON users (username);

CREATE TABLE username_history (
  username     text        PRIMARY KEY,
  user_id      uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  released_at  timestamptz NOT NULL
);

CREATE TABLE username_lookup_failures (
  id          bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_username_lookup_failures ON username_lookup_failures (user_id, created_at);

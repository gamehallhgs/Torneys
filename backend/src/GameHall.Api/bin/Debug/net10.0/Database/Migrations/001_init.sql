-- GameHall Torneios - migração 001: contas, sessões, códigos de email, consentimentos, auditoria.
-- As migrações são aplicadas por ordem de nome de ficheiro, uma só vez, no arranque da API.
-- NUNCA edites uma migração já aplicada: cria uma nova (002_..., 003_...).

CREATE TABLE users (
  id                  uuid        PRIMARY KEY,
  email               text        NOT NULL,                 -- guardado em minúsculas
  password_hash       text        NOT NULL,                 -- Argon2id (nunca a palavra-passe)
  display_name        text        NOT NULL,
  birth_date          date        NOT NULL,
  role                integer     NOT NULL DEFAULT 0 CHECK (role BETWEEN 0 AND 3), -- 0 Player, 1 Referee, 2 Manager, 3 Admin
  email_verified_at   timestamptz NULL,
  failed_login_count  integer     NOT NULL DEFAULT 0,
  locked_until        timestamptz NULL,
  created_at          timestamptz NOT NULL,
  updated_at          timestamptz NOT NULL,
  deleted_at          timestamptz NULL
);
CREATE UNIQUE INDEX ux_users_email ON users (email);

CREATE TABLE refresh_tokens (
  id                 uuid        PRIMARY KEY,
  user_id            uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  family_id          uuid        NOT NULL,                  -- uma "família" = uma sessão num dispositivo
  family_created_at  timestamptz NOT NULL,
  token_hash         text        NOT NULL,                  -- SHA-256 do token (o token em si nunca é guardado)
  created_at         timestamptz NOT NULL,
  expires_at         timestamptz NOT NULL,
  revoked_at         timestamptz NULL,
  replaced_by        uuid        NULL,
  device_name        text        NULL,
  ip_hash            text        NULL
);
CREATE UNIQUE INDEX ux_refresh_tokens_hash ON refresh_tokens (token_hash);
CREATE INDEX ix_refresh_tokens_user ON refresh_tokens (user_id);
CREATE INDEX ix_refresh_tokens_family ON refresh_tokens (family_id);

CREATE TABLE email_codes (
  id          uuid        PRIMARY KEY,
  user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  purpose     integer     NOT NULL,                         -- 0 verificar email, 1 repor palavra-passe
  code_hash   text        NOT NULL,                         -- HMAC do código de 6 dígitos
  expires_at  timestamptz NOT NULL,
  attempts    integer     NOT NULL DEFAULT 0,
  used_at     timestamptz NULL,
  created_at  timestamptz NOT NULL
);
CREATE INDEX ix_email_codes_user_purpose ON email_codes (user_id, purpose, created_at DESC);

-- Prova de consentimento: cada aceitação (ou retirada) é um registo novo, nunca se edita.
-- Mantém-se mesmo depois de a conta ser anonimizada (evidência legal).
CREATE TABLE user_consents (
  id             uuid        PRIMARY KEY,
  user_id        uuid        NOT NULL REFERENCES users (id),
  document_type  text        NOT NULL,                      -- terms | privacy | image_rights | ...
  version        text        NOT NULL,
  content_hash   text        NOT NULL,                      -- SHA-256 do texto aceite
  granted        boolean     NOT NULL,
  ip_hash        text        NULL,
  created_at     timestamptz NOT NULL
);
CREATE INDEX ix_user_consents_user ON user_consents (user_id, document_type, created_at DESC);

CREATE TABLE audit_log (
  id          bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     uuid        NULL,                             -- sem FK de propósito: o registo sobrevive à conta
  action      text        NOT NULL,
  ip_hash     text        NULL,
  created_at  timestamptz NOT NULL
);
CREATE INDEX ix_audit_log_user ON audit_log (user_id, created_at DESC);

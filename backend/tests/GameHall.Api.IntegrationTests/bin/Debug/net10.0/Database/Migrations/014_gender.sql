-- GameHall Torneios - migração 014: género dos utilizadores e dos torneios.
-- Utilizador: male, female, non_binary, other (escolhido ao criar a conta).
-- Torneio: o mesmo + 'mixed' (misto: entram todos os géneros). Contas já existentes ficam 'other'.
ALTER TABLE users ADD COLUMN gender text NULL;
UPDATE users SET gender = 'other' WHERE gender IS NULL;
ALTER TABLE users
  ALTER COLUMN gender SET NOT NULL,
  ADD CONSTRAINT ck_users_gender CHECK (gender IN ('male', 'female', 'non_binary', 'other'));

ALTER TABLE tournaments
  ADD COLUMN gender text NOT NULL DEFAULT 'mixed',
  ADD CONSTRAINT ck_tournaments_gender CHECK (gender IN ('male', 'female', 'non_binary', 'other', 'mixed'));

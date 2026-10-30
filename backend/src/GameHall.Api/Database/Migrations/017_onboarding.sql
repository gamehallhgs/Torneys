-- Mini-guia de boas-vindas: quando o utilizador o viu (ou saltou). NULL = ainda não viu.
ALTER TABLE users ADD COLUMN IF NOT EXISTS onboarding_seen_at timestamptz NULL;

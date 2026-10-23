-- Remove TODOS os dados de demonstração (e só esses). Seguro de correr várias vezes.
-- Equipas, jogos, eventos e destaques são apagados em cascata com os torneios; apagamos também por is_demo.
BEGIN;
DELETE FROM teams WHERE is_demo;
DELETE FROM tournaments WHERE is_demo;
DELETE FROM users WHERE is_demo;
COMMIT;
SELECT 'Dados de demonstração removidos.' AS resultado;

-- GameHall Torneios - migração 015: regras do torneio (texto definido pelo gestor).
-- Enquanto não houver painel do gestor, o lobby mostra um texto de exemplo quando está vazio.
ALTER TABLE tournaments ADD COLUMN rules_text text NULL;

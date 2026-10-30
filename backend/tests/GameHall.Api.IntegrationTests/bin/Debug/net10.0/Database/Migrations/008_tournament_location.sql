-- GameHall Torneios - migração 008: distrito e concelho do torneio (filtro por localidade na lista).
-- Valores válidos: ver Modules/Geo/PortugalGeo.cs (18 distritos de Portugal continental e respetivos concelhos).
-- Ficam NULL nos torneios antigos; o painel do gestor passará a exigi-los ao criar um torneio.
ALTER TABLE tournaments ADD COLUMN district text NULL;
ALTER TABLE tournaments ADD COLUMN municipality text NULL;
ALTER TABLE tournaments ADD CONSTRAINT ck_tournaments_municipality_needs_district
    CHECK (municipality IS NULL OR district IS NOT NULL);
CREATE INDEX ix_tournaments_district ON tournaments (district, municipality);

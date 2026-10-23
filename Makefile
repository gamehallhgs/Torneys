# Atalhos para Linux/macOS. No Windows usa:  .\scripts\dev.ps1 <comando>
.PHONY: help setup up down logs reset test api-logs seed seed-remove pay-sim

help:
	@echo "make setup  - cria o ficheiro .env a partir de .env.example (se não existir)"
	@echo "make up     - arranca API, PostgreSQL e MailHog (docker compose)"
	@echo "make down   - pára tudo (mantém os dados)"
	@echo "make reset  - pára tudo E APAGA a base de dados"
	@echo "make logs   - mostra os logs da API"
	@echo "make seed        - cria torneios de DEMONSTRAÇÃO (marcados is_demo)"
	@echo "make seed-remove - apaga SÓ os dados de demonstração"
	@echo "make pay-sim TEAM=\"Nome\" - (testes) marca todos os jogadores da equipa como pagos"
	@echo "make test   - corre os testes do backend (usa a imagem .NET, não precisas do SDK)"

setup:
	@test -f .env || (cp .env.example .env && echo ".env criado")

up: setup
	docker compose up --build -d
	@echo "API:     http://localhost:8080/health"
	@echo "MailHog: http://localhost:8025"

down:
	docker compose down

reset:
	docker compose down -v

logs:
	docker compose logs -f api

test:
	docker run --rm -v "$(CURDIR)/backend":/src -w /src mcr.microsoft.com/dotnet/sdk:10.0 dotnet test

seed:
	docker compose exec -T postgres psql -U gamehall -d gamehall -v ON_ERROR_STOP=1 < backend/seed/demo_tournaments.sql

seed-remove:
	docker compose exec -T postgres psql -U gamehall -d gamehall -v ON_ERROR_STOP=1 < backend/seed/remove_demo.sql

pay-sim:
	@test -n "$(TEAM)" || (echo 'Uso: make pay-sim TEAM="Nome da equipa"' && exit 1)
	docker compose exec -T postgres psql -U gamehall -d gamehall -v ON_ERROR_STOP=1 -v team="$(TEAM)" < backend/seed/dev_mark_paid.sql

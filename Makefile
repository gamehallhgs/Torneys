# Atalhos para Linux/macOS. No Windows usa:  .\scripts\dev.ps1 <comando>
.PHONY: help setup up down logs reset test test-integration api-logs seed seed-remove pay-sim invite-sim team-sim voting-sim fix-genders

help:
	@echo "make setup  - cria o ficheiro .env a partir de .env.example (se não existir)"
	@echo "make up     - arranca API, PostgreSQL e MailHog (docker compose)"
	@echo "make down   - pára tudo (mantém os dados)"
	@echo "make reset  - pára tudo E APAGA a base de dados"
	@echo "make logs   - mostra os logs da API"
	@echo "make seed        - cria torneios de DEMONSTRAÇÃO (marcados is_demo)"
	@echo "make voting-sim  - testa a votação com a tua conta (ver backend/seed/dev_voting.sql)"
	@echo "make seed-remove - apaga SÓ os dados de demonstração"
	@echo "make pay-sim TEAM=\"Nome\" - (testes) paga por todos os jogadores de uma equipa com vaga reservada (confirma-a)"
	@echo "make team-sim ACTION=ready|expire|release|full|status TEAM=\"Nome\" TORNEIO=\"parte do nome\" - (testes) preparar, expirar reserva, libertar vaga, encher torneio"
	@echo "make invite-sim TEAM=\"Nome\" TORNEIO=\"parte do nome\" EMAIL=a@b.pt - (testes) a equipa convida essa conta"
	@echo "make test   - corre os testes do backend (usa a imagem .NET, não precisas do SDK). Os de integração aparecem como skipped."
	@echo "make test-integration - corre também os testes de integração com um PostgreSQL de verdade (precisa do Docker a correr)"

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

test-integration:
	-docker network create gh-test >/dev/null 2>&1
	-docker rm -f gh-test-pg >/dev/null 2>&1
	docker run -d --rm --name gh-test-pg --network gh-test -e POSTGRES_PASSWORD=test postgres:16 >/dev/null
	@until docker exec gh-test-pg pg_isready -U postgres >/dev/null 2>&1; do sleep 1; done
	docker run --rm --network gh-test -e GAMEHALL_TEST_PG="Host=gh-test-pg;Username=postgres;Password=test;Database=postgres" \
	  -v "$(CURDIR)/backend":/src -w /src mcr.microsoft.com/dotnet/sdk:10.0 dotnet test tests/GameHall.Api.IntegrationTests; \
	  status=$$?; docker rm -f gh-test-pg >/dev/null 2>&1; exit $$status

seed:
	docker compose exec -T postgres psql -U gamehall -d gamehall -v ON_ERROR_STOP=1 < backend/seed/demo_tournaments.sql
	docker compose exec -T postgres psql -U gamehall -d gamehall -v ON_ERROR_STOP=1 < backend/seed/demo_voting.sql

seed-remove:
	docker compose exec -T postgres psql -U gamehall -d gamehall -v ON_ERROR_STOP=1 < backend/seed/remove_demo.sql

pay-sim:
	@test -n "$(TEAM)" || (echo 'Uso: make pay-sim TEAM="Nome da equipa"' && exit 1)
	docker compose exec -T postgres psql -U gamehall -d gamehall -v ON_ERROR_STOP=1 -v team="$(TEAM)" < backend/seed/dev_mark_paid.sql

team-sim:
	@test -n "$(ACTION)" || (echo 'Uso: make team-sim ACTION=ready|expire|release|full|status TEAM="Nome" TORNEIO="parte do nome"' && exit 1)
	docker compose exec -T postgres psql -U gamehall -d gamehall -v ON_ERROR_STOP=1 -v action="$(ACTION)" -v team="$(TEAM)" -v tournament="$(TORNEIO)" < backend/seed/dev_team_sim.sql

fix-genders:
	docker compose exec -T postgres psql -U gamehall -d gamehall -v ON_ERROR_STOP=1 < backend/seed/fix_genders_until_2026_10_29.sql

voting-sim:
	@test -n "$(EMAIL)" || (echo 'Uso: make voting-sim ACTION=verified|recent|participant|reset EMAIL=eu@exemplo.pt' && exit 1)
	docker compose exec -T postgres psql -U gamehall -d gamehall -v ON_ERROR_STOP=1 -v action="$(or $(ACTION),verified)" -v email="$(EMAIL)" < backend/seed/dev_voting.sql

invite-sim:
	@test -n "$(TEAM)" -a -n "$(EMAIL)" || (echo 'Uso: make invite-sim TEAM="Nome da equipa" TORNEIO="parte do nome do torneio" EMAIL=eu@exemplo.pt' && exit 1)
	docker compose exec -T postgres psql -U gamehall -d gamehall -v ON_ERROR_STOP=1 -v team="$(TEAM)" -v email="$(EMAIL)" -v tournament="$(TORNEIO)" < backend/seed/dev_invite.sql

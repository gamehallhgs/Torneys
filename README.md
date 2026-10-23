# GameHall Torneios

Área de torneios de futebol (futebol 7, 9, 11 e futsal) da aplicação GameHall: equipas, inscrições, bracket interativo, estatísticas e highlights.

> **Estado: Fase 5 de 5 (parte do utilizador normal: jogos, classificação, quadro, estatísticas)** — historial: fase 1 — esqueleto do projeto, Docker, base de dados, autenticação segura e aceitação de Termos e Condições.
> Ver [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md) para o plano completo.

## O que já funciona (fase 1)

- API em C# (ASP.NET Core, .NET 10) + PostgreSQL, tudo em Docker
- Registo com verificação de email por código, login, sessões com refresh tokens rotativos
- Palavras-passe com Argon2id, bloqueio por tentativas falhadas, limites de pedidos, verificação contra fugas de dados
- Idade mínima de 13 anos (validada no servidor)
- Termos e Condições e Política de Privacidade versionados, com prova de aceitação
- Recuperação de palavra-passe, alteração de palavra-passe, exportar dados e eliminar conta (RGPD)
- Emails de teste via MailHog

**Ainda não incluído:** app Flutter (fases 2 a 5: conta, torneios, equipas e jogos; ver mobile/README.md), login com Google/Apple (fase 2), torneios, equipas, bracket, pagamentos, painel do gestor/árbitro.

## Requisitos

| | Linux | Windows |
|---|---|---|
| Docker | Docker Engine + plugin Compose | Docker Desktop (com WSL2 ativado) |
| Git | `sudo apt install git` (ou equivalente) | Git for Windows |
| .NET 10 SDK | **opcional** (só para depurar fora do Docker) | **opcional** |
| Flutter | só a partir da fase 2 | só a partir da fase 2 |

## Arrancar o backend

**Linux / macOS**
```bash
make setup      # cria o ficheiro .env (valores de desenvolvimento)
make up         # constrói e arranca API + PostgreSQL + MailHog
```

**Windows (PowerShell)**
```powershell
.\scripts\dev.ps1 setup
.\scripts\dev.ps1 up
```

**Em qualquer sistema, sem Make nem scripts**
```bash
cp .env.example .env        # Windows: copy .env.example .env
docker compose up --build -d
```

Depois de arrancar:

| Serviço | URL |
|---|---|
| API (estado) | http://localhost:8080/health |
| API (pronta, testa a base de dados) | http://localhost:8080/health/ready |
| MailHog (emails de teste) | http://localhost:8025 |

Para parar: `make down` / `.\scripts\dev.ps1 down`. Para apagar também a base de dados: `make reset` / `.\scripts\dev.ps1 reset`.
Para ver os logs da API: `make logs` / `.\scripts\dev.ps1 logs`.

## Experimentar a API

Abre [`backend/requests.http`](backend/requests.http) no VS Code (extensão "REST Client") ou no Rider/Visual Studio e corre os pedidos pela ordem: registo → ler o código no MailHog → verificar email → login.
Descrição de todos os endpoints em [`docs/API.md`](docs/API.md).

## Testes

```bash
make test                      # Linux
.\scripts\dev.ps1 test         # Windows
```
Corre os testes dentro de um contentor com o SDK .NET (não precisas de o instalar). Se tiveres o SDK: `cd backend && dotnet test`.

## Estrutura

```
gamehall-torneios/
├── backend/               API C# (src/GameHall.Api) e testes (tests/)
│   └── src/GameHall.Api/
│       ├── Common/            opções, erros, utilitários HTTP
│       ├── Database/          migrações SQL e acesso a dados
│       ├── Infrastructure/    segurança (hash, tokens) e email
│       ├── Modules/           Auth, Legal, Me (cada módulo é uma pasta)
│       └── Legal/             Termos e Privacidade (Markdown)
├── mobile/                app Flutter (fases 2 a 5: conta, torneios, equipas e jogos; ver mobile/README.md)
├── docs/                  arquitetura, API, segurança, lista de verificação pré-lançamento
├── infra/                 configuração do proxy (produção)
├── scripts/               atalhos para Windows
├── docker-compose.yml     desenvolvimento
└── docker-compose.prod.yml  modelo de produção (ainda não usar)
```

## Antes de lançar

Lê [`docs/CHECKLIST_LANCAMENTO.md`](docs/CHECKLIST_LANCAMENTO.md). Os textos legais têm campos `[PREENCHER ...]` e a API **recusa arrancar em produção** enquanto existirem. São modelos: pede revisão a um advogado ou especialista em RGPD.

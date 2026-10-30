# Testes de integração (PostgreSQL de verdade)

Cada teste cria a sua **própria base de dados**, aplica todas as migrações (como no arranque da API) e apaga-a no fim.
Usam os serviços reais (`TeamService`, `VotingService`, `ReservationService`, serviços de ciclo de vida, `NotificationDispatcher`…)
e a API completa (`WebApplicationFactory`) para a autorização.

## Como correr

- **Com Docker (mais fácil):** `make test-integration` (Windows: `.\scripts\dev.ps1 test-integration`). Arranca um Postgres temporário, corre os testes e apaga-o.
- **Com um Postgres teu:** define `GAMEHALL_TEST_PG` com a ligação (utilizador que possa criar bases de dados) e corre `dotnet test tests/GameHall.Api.IntegrationTests`:
  `Host=localhost;Username=postgres;Password=test;Database=postgres`
- **Sem a variável** os testes aparecem como *skipped* (é o que acontece em `make test`).
- **CI:** `.github/workflows/backend.yml` tem um serviço PostgreSQL e corre-os em cada push.

## O que cobrem

| Ficheiro | O quê |
|---|---|
| `MigrationsAndSeedsTests` | migrações desde zero, repetir não muda nada, 4 instâncias a arrancar juntas, seeds de demo 2× e remoção, numeração sem buracos |
| `LifecycleTests` | inscrições → fechadas → a decorrer → terminado; jogo adiado mantém o torneio a decorrer; janela de votação |
| `TeamFlowTests` | criar equipa, nomes/cores únicos, filtro de palavras, idade, género (todas as combinações), código de convite (entrar, pedido, cheio, regenerar 3×/hora, limite de tentativas) |
| `ConcurrencyTests` | última vaga (8 varrimentos em paralelo), todos a pagar ao mesmo tempo, mesmo username, 2 mudanças de username, votos em paralelo |
| `VotingFlowTests` | abrir rondas e janela de 6 h, quem pode votar (24 h de email), voto em si, guarda-redes, empate → 2.ª ronda → resultados, avisos de votação |
| `DeliveryTests` | push/email só nos tipos combinados, interruptor geral, tokens mortos, avisos antigos, jogo marcado/alterado/adiado/cancelado, jogo a começar |
| `UsernameAndNextGameTests` | 1 mudança grátis de username, reserva de 30 dias, próximo jogo do torneio e meu próximo jogo |
| `AuthorizationHttpTests` | sem sessão 401, termos por aceitar 403, token falso, notificações de outros, só o líder gere a equipa, tokens de push |

Os dados de teste são criados por SQL direto (`Seed` em `Infrastructure.cs`) para os testes não dependerem do que estão a testar.

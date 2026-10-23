# Arquitetura

## Visão geral

```
 App Flutter (utilizadores, Android/iOS)        Painel web (gestor/árbitro, mais tarde)
              │                                              │
              └──────────────── HTTPS (REST + JWT) ──────────┘
                                   │
                         Caddy (HTTPS automático)           ← só em produção
                                   │
                          API ASP.NET Core (C#)             ← monólito modular
              ┌───────────┬────────┴────────┬──────────────┐
          PostgreSQL    Redis*           MinIO/S3*       MailHog (dev) / SMTP (prod)
                      (cache, filas)    (vídeos)
```
\* previstos para fases seguintes.

## Decisões

| Decisão | Escolha | Porquê |
|---|---|---|
| Backend | C# / ASP.NET Core (.NET 10, LTS) | Escolha do projeto; segurança e desempenho maduros |
| Estilo | Monólito modular (pastas por módulo) | Simples de gerir por uma equipa pequena; módulos extraíveis mais tarde |
| Base de dados | PostgreSQL | Dados muito relacionais (torneios, equipas, jogos, estatísticas) |
| Acesso a dados | Dapper + SQL explícito | Transparente e previsível; sem geração de migrações automática |
| Migrações | Ficheiros `.sql` numerados, aplicados no arranque | Simples e auditável. Nunca editar uma migração já aplicada |
| Autenticação | JWT curto (15 min) + refresh token rotativo | Sessões revogáveis por dispositivo, deteção de roubo |
| Tempo real (fase 4+) | SignalR (WebSockets) | Atualização do bracket e pedidos de equipa em direto |
| Push (fase 4+) | Firebase Cloud Messaging | Gratuito, Android e iOS |
| App móvel | Flutter | Uma base de código para Android e iOS |

## Roles

`Player` (utilizador), `Referee` (árbitro), `Manager` (gestor), `Admin`.
Fica guardado em `users.role`. Mais tarde, a função **por entidade** (gestor da associação X; árbitro com permissões só para marcadores ou só para highlights) será uma tabela de permissões própria: o gestor de uma entidade delega permissões a perfis.

## Legal por desenho

- Termos e Privacidade versionados (`Legal:TermsVersion`, `Legal:PrivacyVersion`).
- Cada aceitação fica em `user_consents` com versão, hash do texto e data.
- O token de acesso leva a claim `legal_ok`. **Todos** os endpoints exigem `legal_ok=true` por defeito (política *fallback*); só os de autenticação, `/legal` e `/me` a dispensam.
- Quando subires a versão de um documento, os utilizadores existentes são obrigados a aceitar de novo no próximo `refresh`.
- A API não arranca em produção com textos legais por preencher.

## Plano por fases

1. **Fase 1 (esta):** esqueleto, Docker, autenticação segura, termos.
2. **Fase 2:** app Flutter com tema GameHall; registo, login, termos; login Google/Apple.
3. **Fase 3:** torneios (lista, filtros por estado e data, detalhe) e dados de teste removíveis (`GameHall.DevSeed`, schema `dev_seed`, comando `seed:remove`).
4. **Fase 4:** equipas, lobby (sem chat), posições (as do FIFA), convites por link/lista/direto, pedidos de entrada, transferência de host, regra de uma equipa por torneio.
5. **Fase 5:** bracket interativo (eliminação simples, dupla, grupos + eliminatórias, liga, 3.º/4.º lugar), desempates configuráveis, estatísticas, cartões, highlights por jogo (máx. 1 min, 1080p).

**Fora do âmbito por agora:** pagamentos, painel do gestor, painel do árbitro, votação de melhor jogador/guarda-redes, chat, ligação às reservas.

## Regras de domínio já decididas

- Só futebol 7, 9, 11 e futsal.
- Idade mínima 13 anos; escalões etários definidos pelo gestor por torneio.
- Um jogador só pode estar numa equipa por torneio.
- Equipa participante = cumpre mínimo/máximo de jogadores definido pelo gestor (e, mais tarde, inscrição paga). Equipas incompletas são removidas quando as inscrições fecham; o gestor pode abrir período suplementar.
- Estados de jogo: agendado, a decorrer, terminado, cancelado, adiado (adiado = agendado com nova data, com histórico).
- Horas em UTC (Portugal continental) e guardadas em `timestamptz`.

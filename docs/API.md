# API (fase 1)

Base: `http://localhost:8080`. Corpo em JSON. Erros em formato ProblemDetails com um campo `code` estável:

```json
{ "title": "Email ou palavra-passe incorretos.", "status": 401, "code": "invalid_credentials" }
```
Erros de validação trazem também `errors`: `{ "password": ["..."] }`.

## Estado
| Método | Caminho | Descrição |
|---|---|---|
| GET | `/health` | A API está viva |
| GET | `/health/ready` | A API consegue falar com a base de dados |

## Legal (público)
| Método | Caminho | Descrição |
|---|---|---|
| GET | `/api/v1/legal/current` | Versões atuais dos documentos |
| GET | `/api/v1/legal/terms` | Termos e Condições (Markdown) |
| GET | `/api/v1/legal/privacy` | Política de Privacidade (Markdown) |

## Autenticação (público)
| Método | Caminho | Corpo | Resposta |
|---|---|---|---|
| POST | `/api/v1/auth/register` | `email, password, displayName, username, birthDate (AAAA-MM-DD), acceptTerms, acceptPrivacy, termsVersion, privacyVersion` | 202 (sempre igual para o email). 403 `age_too_young` se < 13 anos. 400 `validation_error` com `fields.username` se o username for inválido, reservado ou já estiver em uso |
| POST | `/api/v1/auth/verify-email` | `email, code` | 204, ou 400 `invalid_code` |
| POST | `/api/v1/auth/resend-verification` | `email` | 202 |
| POST | `/api/v1/auth/login` | `email, password, deviceName?` | 200 com tokens; 401 `invalid_credentials`; 403 `email_not_verified` |
| POST | `/api/v1/auth/refresh` | `refreshToken` | 200 com novos tokens; 401 `invalid_refresh_token` |
| POST | `/api/v1/auth/logout` | `refreshToken` | 204 |
| POST | `/api/v1/auth/forgot-password` | `email` | 202 |
| POST | `/api/v1/auth/reset-password` | `email, code, newPassword` | 204, ou 400 |

Resposta de login/refresh:
```json
{
  "tokenType": "Bearer",
  "accessToken": "...",
  "expiresIn": 900,
  "refreshToken": "...",
  "user": { "id": "...", "email": "...", "displayName": "...", "username": "hugo", "usernameTag": "482", "usernameNextChangeAt": null, "role": "Player", "emailVerified": true, "birthDate": "2008-05-01" },
  "legal": { "termsVersion": "1.0.0", "privacyVersion": "1.0.0", "requiresAcceptance": false }
}
```
Se `legal.requiresAcceptance` for `true`, a app mostra os documentos e chama `POST /me/consents`; depois faz `refresh` para obter um token com `legal_ok=true`.

## O próprio utilizador (`Authorization: Bearer <accessToken>`)
| Método | Caminho | Corpo | Descrição |
|---|---|---|---|
| GET | `/api/v1/me` | | Perfil |
| PATCH | `/api/v1/me/username` | `username` | Muda o username (1 vez por mês; a tag mantém-se). `{username, tag, nextChangeAt}`. 409 `username_taken`, `username_reserved`, `username_change_cooldown` (a mensagem diz a data) |
| POST | `/api/v1/me/consents` | `termsVersion, privacyVersion` | Aceitar as versões atuais |
| POST | `/api/v1/me/change-password` | `currentPassword, newPassword` | Termina todas as sessões |
| POST | `/api/v1/me/logout-all` | | Termina todas as sessões |
| GET | `/api/v1/me/export` | | Exportar os dados (RGPD) |
| POST | `/api/v1/me/delete` | `password` | Eliminar e anonimizar a conta |

### Username e tag
- **Username** (`@hugo`): único, 3 a 20 caracteres, só minúsculas, números, `.` e `_`; não começa nem acaba em `.` ou `_`; sem `..`. Guarda-se sempre em minúsculas (`Hugo` = `hugo`). Há nomes reservados (`admin`, `suporte`...) e nada que contenha `gamehall` (ver `UsernameRules.Reserved`).
- **Tag** (`#482`): 3 algarismos ao acaso atribuídos na criação da conta; **não muda** quando se muda o username. Só o próprio a vê (`user.usernameTag`); os outros jogadores só veem o `@username`. Para convidar é preciso o par completo, `hugo#482`.
- Mudar: 1 vez por mês (a primeira mudança é livre). O username antigo fica reservado 30 dias (só o antigo dono o pode recuperar). Ao eliminar a conta o username liberta-se.
- O email nunca é mostrado a outros jogadores nem no perfil da app.

| Método | Caminho | Descrição |
|---|---|---|
| GET | `/api/v1/usernames/check?username=hugo` | Público (usado no registo), 30 pedidos por minuto por IP. `{available, reason?, message?}` (`reason`: `invalid`, `reserved`, `taken`, `recently_used`) |

Todos os outros endpoints (fases seguintes) exigem sessão **e** termos em dia.

## Torneios (exige sessão e termos em dia)
| Método | Caminho | Parâmetros | Descrição |
|---|---|---|---|
| GET | `/api/v1/tournaments` | `status` (`open`, `ongoing`, `finished`), `from`, `to` (`yyyy-MM-dd`; torneios que se sobrepõem ao intervalo), `sport` (`football7`, `football9`, `football11`, `futsal`), `district`, `municipality` (ver Localidades), `page`, `pageSize` (máx. 50) | Lista paginada. `ongoing` inclui inscrições fechadas e a decorrer. Rascunhos e cancelados nunca aparecem. |
| GET | `/api/v1/tournaments/{id}` | | Detalhe, equipas inscritas e `eligibility` do utilizador (`canCreateTeam` + `reason`: `registration_closed`, `age_too_young`, `age_too_old`, `tournament_full`). 404 `tournament_not_found`. |

Lista: `{ "items": [ {id,name,organizerName,sport,format,status,startsOn,endsOn,locationName,district,municipality,entryFeeCents,teamsRegistered,maxTeams,minAge,maxAge,ageLabel,registrationClosesAt} ], "total", "page", "pageSize" }`

Detalhe: `{ "summary": {...como na lista...}, description, hasThirdPlace, tiebreakers[], locationAddress, registrationOpensAt, minPlayersPerTeam, maxPlayersPerTeam, teams:[{id,name,colorHex}], eligibility:{canCreateTeam,reason} }`

`status` de cada torneio: `registration_open`, `registration_closed`, `ongoing`, `finished`.

Códigos de desempate (`tiebreakers`, por ordem de aplicação): `points`, `head_to_head`, `goal_difference`, `goals_for`, `goals_against`, `wins`, `fair_play`, `draw`; nas eliminatórias, `penalties`.

## Localidades (exige sessão e termos em dia)
| Método | Caminho | Descrição |
|---|---|---|
| GET | `/api/v1/geo/districts` | Os 18 distritos de Portugal continental com os seus concelhos (278): `[ {name, municipalities[]} ]`, por ordem alfabética |

Cada torneio tem `district` e `municipality` (podem ser `null` em torneios antigos). Na lista, `district=Porto` mostra só os torneios desse distrito e `district=Porto&municipality=Matosinhos` só os desse concelho. O concelho tem de pertencer ao distrito e exige o distrito; senão `400` com `fields.district` / `fields.municipality`. Os nomes são exatos (com acentos), como em `/geo/districts`. Açores e Madeira (regiões autónomas) ainda não estão incluídos.

## Equipas, lobby, pedidos e convites (exige sessão e termos em dia)

Erros: ProblemDetails com `code` estável. Ações sem corpo de resposta devolvem `204`.

| Método e rota | Descrição |
|---|---|
| `POST /api/v1/tournaments/{id}/teams` `{name, colorHex}` | Cria equipa (quem cria é o líder). `201` com o lobby. Erros: `team_name_taken`, `team_color_taken`, `already_in_team`, `registration_closed`, `age_too_young`, `age_too_old`, `tournament_full` |
| `GET /api/v1/teams/{id}` | Lobby. Qualquer jogador vê `members` (nome, `username` e posição) de qualquer equipa; `paid` só aparece para membros (`null` para os outros). Só o líder vê `requests` e `invites`. `team.closedToRequests` e `team.membersCanInvite` são as definições; `me` indica o que o utilizador pode fazer (`canRequestToJoin`, `joinBlockedReason`, `canInvite`) |
| `PATCH /api/v1/teams/{id}/settings` `{closedToRequests?, membersCanInvite?}` | Só o líder, a qualquer momento (só muda os campos enviados; `400` se não vier nenhum). Ver Definições do lobby |
| `POST /api/v1/teams/{id}/join-requests` | Pedir para entrar |
| `POST /api/v1/teams/{id}/invites` `{email}` ou `{username: "hugo#482"}` | Convite direto (líder, ou qualquer membro se `membersCanInvite`). Por username#tag: `404 user_not_found` ("Este utilizador não se encontra na app.") se o par não existir (conta por verificar conta como inexistente), `429 too_many_failed_lookups` ao fim de 10 tentativas falhadas por hora, `400` se faltar a tag. Máx. 40 convites pendentes por equipa (`too_many_invites`). Outros membros: `403 invite_not_allowed`; não-membros: `403 not_team_member`. `409 cannot_invite_self` se o email for o do próprio; `409 invitee_already_in_team` ("O jogador X já se encontra numa equipa do mesmo torneio.") se o convidado já está numa equipa desse torneio. Para emails sem conta (ou por verificar) a resposta é sempre `202`, igual à de sucesso, para não revelar quem tem conta |
| `POST /api/v1/teams/{id}/position` `{position}` | Posição principal (`GK,RB,CB,LB,RWB,LWB,CDM,CM,CAM,RM,LM,RW,LW,CF,ST`) |
| `POST /api/v1/teams/{id}/transfer-host` `{userId}` | Passar a liderança |
| `POST /api/v1/teams/{id}/leave` | Sair (só com inscrições abertas). Líder com outros membros: `host_must_transfer`. Último membro: a equipa é eliminada |
| `POST /api/v1/teams/{id}/members/{userId}/remove` | Remover jogador (líder) |
| `POST /api/v1/join-requests/{id}/accept\|reject\|cancel` | Líder decide; o próprio cancela |
| `POST /api/v1/invites/{id}/accept\|decline\|cancel` | Convidado responde; o líder cancela |
| `GET /api/v1/my/teams`, `/my/invites`, `/my/join-requests` | Listas do utilizador |

Regras: uma equipa por jogador por torneio; nome e cor únicos por torneio; ao aceitar um pedido/convite os outros pendentes do jogador no torneio são cancelados. O detalhe do torneio inclui `myTeamId` e `myTeam` (`id`, `name`, `colorHex`, `isHost`, `membersCount`) quando o utilizador está numa equipa.
A lista de torneios aceita `status=mine`: só os torneios em que o utilizador é membro de uma equipa (os que ainda não terminaram primeiro).
Um serviço em segundo plano (de minuto a minuto, `Lifecycle:Enabled`) fecha as inscrições à hora marcada e remove as equipas abaixo do mínimo de jogadores.

### Definições do lobby (só o líder)

- **Lobby fechado** (`closedToRequests`): ninguém de fora pode pedir para entrar (`409 lobby_closed`, `me.joinBlockedReason = lobby_closed`); só entra quem for convidado. Pedidos que já estavam pendentes mantêm-se para o líder decidir. Convites continuam a funcionar.
- **Membros convidam** (`membersCanInvite`): se ligado, qualquer membro pode enviar convites; se desligado, só o líder. Os convites pendentes só o líder os vê e cancela.
- Qualquer jogador pode ver os membros de outras equipas, mas só pode pedir para entrar se não estiver já noutra equipa do torneio (`already_in_team`), a equipa não estiver confirmada nem completa e o lobby estiver aberto.

## Notificações (exige sessão e termos em dia)
| Método | Caminho | Descrição |
|---|---|---|
| GET | `/api/v1/notifications` | Até 50 notificações, mais recentes primeiro: `{ unreadCount, items:[{id,type,createdAt,read,invite}] }`. Por agora só existe `type = team_invite`, com `invite: {inviteId,status,teamId,teamName,colorHex,tournamentId,tournamentName,invitedByName}` (`status`: `pending`, `accepted`, `declined`, `cancelled`) |
| GET | `/api/v1/notifications/unread-count` | `{ count }`: leve, a app pergunta de tempos a tempos para mostrar o pontinho vermelho |
| POST | `/api/v1/notifications/read-all` | Marca todas como lidas (a app chama ao abrir a central). `204` |

Quando alguém convida um jogador (`POST /teams/{id}/invites`), é criada uma notificação para o convidado na mesma transação do convite (e continua a ser enviado o email). Só se cria se o convite for novo: reenviar um convite ainda pendente não duplica. Para responder: `POST /api/v1/invites/{inviteId}/accept|decline` (como antes). Os textos e o `status` lêem-se do convite no momento da listagem, por isso nunca ficam desatualizados; se a equipa for eliminada, a notificação desaparece.

## Jogos, classificação e estatísticas (só leitura; exige sessão e termos em dia)

| Rota | Descrição |
|---|---|
| `GET /api/v1/tournaments/{id}/games?status=` | Jogos do torneio (`scheduled`, `running`, `finished`, `cancelled`, `postponed`). Ordenados por data, ronda e número |
| `GET /api/v1/games/{id}` | Jogo com `events` (golos, assistências, cartões) e `highlights` (vídeos) |
| `GET /api/v1/tournaments/{id}/standings` | Classificação por grupo (liga = um grupo sem nome; eliminatórias = vazio) |
| `GET /api/v1/tournaments/{id}/stats` | Top 10 de marcadores, assistências, amarelos e vermelhos |

- Fases de um jogo (`stage`): `group`, `league`, `round` (eliminatória), `third_place`. O quadro de eliminatórias monta-se na app com `roundNumber`/`roundLabel`; equipas ainda por definir vêm com `id`, `name` e `colorHex` a `null`.
- Resultado (`homeGoals`/`awayGoals`) só existe em jogos a decorrer ou terminados; `homePenalties`/`awayPenalties` só em empates decididos por penáltis.
- Classificação: vitória 3 pontos, empate 1; só contam jogos terminados. Os desempates seguem a ordem do torneio (`tiebreakers`); "pontos" é sempre o primeiro. `head_to_head` conta só os jogos entre as equipas empatadas. `fair_play`: amarelo = 1, vermelho = 3 (ganha quem tiver menos). `draw` e `penalties` não se aplicam a tabelas: se sobrar um empate, ordena-se por nome (sem acentos).
- Estatísticas contam jogos a decorrer e terminados. Ao eliminar uma conta, os eventos ficam mas passam a "Jogador removido".
- Erros: `tournament_not_found`, `game_not_found`, `validation_error` (estado inválido).
- Os vídeos (máx. 1 minuto, até 1080p) são só endereços por agora; o carregamento fica para os painéis do gestor/árbitro.

## Confirmação de equipas e vagas

- **Criar equipas é ilimitado** enquanto as inscrições estão abertas. Só deixa de ser possível quando as equipas **confirmadas** já ocupam todas as vagas (`tournament_full`).
- Uma equipa fica **confirmada** (`confirmed`) quando tem o mínimo de jogadores e **todos** pagaram (`paid` em cada membro). Ficam confirmadas as primeiras `maxTeams` que cumprirem os requisitos, pela ordem em que o último pagamento foi feito.
- Quando as vagas se esgotam, as equipas **não confirmadas são eliminadas** (as de demonstração nunca) e o torneio aparece como `isFull`.
- Uma equipa confirmada fica **fechada**: não aceita pedidos nem convites e ninguém sai ou é removido (`team_confirmed`). A posição e a transferência de líder continuam permitidas.
- Na lista e no detalhe do torneio: `teamsRegistered` (criadas), `teamsConfirmed` (ocupam vaga) e `isFull`. O lobby traz `team.confirmed`, `tournament.teamsConfirmed/maxTeams` e `members[].paid`.
- A confirmação corre de minuto a minuto (`TeamConfirmationService`) e pode ser chamada logo após um pagamento. O módulo de pagamentos (ainda por fazer) só tem de preencher `team_members.paid_at`.
- Para testar sem pagamentos: `make pay-sim TEAM="Nome da equipa"` (Windows: `.\scripts\dev.ps1 pay-sim "Nome da equipa"`) marca os jogadores como pagos; a equipa é confirmada no minuto seguinte.
- No fecho das inscrições continuam a ser removidas as equipas abaixo do mínimo de jogadores. Quando houver pagamentos, o fecho deverá remover também as não confirmadas (por decidir).


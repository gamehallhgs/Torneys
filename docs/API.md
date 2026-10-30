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
| POST | `/api/v1/auth/register` | `email, password, displayName, username, birthDate (AAAA-MM-DD), gender (male, female, non_binary, other), acceptTerms, acceptPrivacy, termsVersion, privacyVersion` | 202 (sempre igual para o email). 403 `age_too_young` se < 13 anos. 400 `validation_error` com `fields.username` se o username for inválido, reservado ou já estiver em uso |
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
  "user": { "id": "...", "email": "...", "displayName": "...", "username": "hugo", "usernameTag": "482", "usernameChangesLeft": 1, "role": "Player", "emailVerified": true, "birthDate": "2008-05-01", "gender": "male" },
  "legal": { "termsVersion": "1.0.0", "privacyVersion": "1.0.0", "requiresAcceptance": false }
}
```
Se `legal.requiresAcceptance` for `true`, a app mostra os documentos e chama `POST /me/consents`; depois faz `refresh` para obter um token com `legal_ok=true`.

## O próprio utilizador (`Authorization: Bearer <accessToken>`)
| Método | Caminho | Corpo | Descrição |
|---|---|---|---|
| GET | `/api/v1/me` | | Perfil |
| PATCH | `/api/v1/me/username` | `username` | Muda o username (**só 1 vez por conta**; mudanças seguintes serão pagas no futuro; a tag mantém-se). `{username, tag, changesLeft}`. 409 `username_taken`, `username_reserved`, `username_change_used` |
| PATCH | `/api/v1/me/name` | `displayName` | Muda o nome que aparece, sempre que o utilizador quiser (2–40 caracteres). Devolve o utilizador. 400 `validation_error` |
| POST | `/api/v1/me/consents` | `termsVersion, privacyVersion` | Aceitar as versões atuais |
| POST | `/api/v1/me/change-password` | `currentPassword, newPassword` | Termina todas as sessões |
| POST | `/api/v1/me/logout-all` | | Termina todas as sessões |
| GET | `/api/v1/me/export` | | Exportar os dados (RGPD) |
| POST | `/api/v1/me/delete` | `password` | Eliminar e anonimizar a conta |

### Username e tag
- **Username** (`@hugo`): único, 3 a 20 caracteres, só minúsculas, números, `.` e `_`; não começa nem acaba em `.` ou `_`; sem `..`. Guarda-se sempre em minúsculas (`Hugo` = `hugo`). Há nomes reservados (`admin`, `suporte`...) e nada que contenha `gamehall` (ver `UsernameRules.Reserved`).
- **Tag** (`#482`): 3 algarismos ao acaso atribuídos na criação da conta; **não muda** quando se muda o username. Só o próprio a vê (`user.usernameTag`); os outros jogadores só veem o `@username`. Para convidar é preciso o par completo, `hugo#482`.
- Mudar: só 1 vez por conta (as seguintes serão pagas no futuro, ainda não implementado). O username antigo fica reservado 30 dias (só o antigo dono o pode recuperar). Ao eliminar a conta o username liberta-se.
- O email nunca é mostrado a outros jogadores nem no perfil da app.

| Método | Caminho | Descrição |
|---|---|---|
| GET | `/api/v1/usernames/check?username=hugo` | Público (usado no registo), 30 pedidos por minuto por IP. `{available, reason?, message?}` (`reason`: `invalid`, `reserved`, `taken`, `recently_used`) |

Todos os outros endpoints (fases seguintes) exigem sessão **e** termos em dia.

## Torneios (exige sessão e termos em dia)
| Método | Caminho | Parâmetros | Descrição |
|---|---|---|---|
| GET | `/api/v1/tournaments` | `status` (`open`, `ongoing`, `finished`), `from`, `to` (`yyyy-MM-dd`; torneios que se sobrepõem ao intervalo), `sport` (`football7`, `football9`, `football11`, `futsal`), `district`, `municipality` (ver Localidades), `page`, `pageSize` (máx. 50) | Lista paginada. `ongoing` inclui inscrições fechadas e a decorrer. Rascunhos e cancelados nunca aparecem. |
| GET | `/api/v1/tournaments/{id}` | | Detalhe, equipas inscritas e `eligibility` do utilizador (`canCreateTeam` + `reason`: `registration_closed`, `age_too_young`, `age_too_old`, `tournament_full`, `player_penalized`). 404 `tournament_not_found`. |

Lista: `{ "items": [ {id,name,organizerName,sport,format,status,startsOn,endsOn,locationName,district,municipality,entryFeeCents,teamsRegistered,maxTeams,minAge,maxAge,ageLabel,registrationClosesAt} ], "total", "page", "pageSize" }`

Detalhe: `{ "summary": {...como na lista...}, description, hasThirdPlace, tiebreakers[], locationAddress, registrationOpensAt, minPlayersPerTeam, maxPlayersPerTeam, teams:[{id,name,colorHex,confirmed,isPrivate,state}], eligibility:{canCreateTeam,reason} }`

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
| `POST /api/v1/tournaments/{id}/teams` `{name, colorHex}` | Cria equipa (quem cria é o líder). `201` com o lobby. Erros: `team_name_taken`, `team_color_taken`, `already_in_team`, `registration_closed`, `age_too_young`, `age_too_old`, `tournament_full`, `player_penalized` |
| `GET /api/v1/teams/{id}` | Lobby. Qualquer jogador vê `members` (nome, `username` e posição) de qualquer equipa; `paid` só aparece para membros (`null` para os outros). Só o líder vê `requests` e `invites`. `team.isPrivate` e `team.membersCanInvite` são as definições; `me` indica o que o utilizador pode fazer (`canRequestToJoin`, `joinBlockedReason`, `canInvite`) |
| `PATCH /api/v1/teams/{id}/settings` `{isPrivate?, membersCanInvite?, inviteCodeEnabled?, codeDirectEntry?, membersSeeCode?}` | Só o líder, em formação (só muda os campos enviados; `400` se não vier nenhum). Ver Definições do lobby |
| `POST /api/v1/teams/{id}/invite-code/regenerate` | Só o líder, em formação. Gera código novo → `{code, regensLeft}`. Máx. 3 por hora (`429 invite_code_regen_limit`) |
| `GET /api/v1/invite-codes/{code}` | Pré-visualiza a equipa do código → `{teamId, teamName, colorHex, tournamentName, membersCount, maxPlayers, directEntry, blockedReason, blockedMessage}`. `404 invite_code_invalid`; falhas contam para `429 too_many_failed_lookups` |
| `POST /api/v1/invite-codes/{code}/join` | Entra (`200 {teamId, joined:true}`) ou, sem entrada direta, cria pedido (`202 {teamId, joined:false}`). Mesmos erros de elegibilidade que `join-requests` |
| `POST /api/v1/me/onboarding-seen` | Marca o mini-guia como visto (`204`). `onboardingSeen` vem em `/me` e no login |

O lobby traz `inviteCode: {code, enabled, directEntry, membersSeeCode, regensLeft}`: o líder vê sempre (só em formação); membros só se estiver ativo e o líder permitir (`code` null caso contrário); outros, `null`.
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

- **Equipa privada** (`isPrivate`): ninguém de fora pode pedir para entrar (`409 lobby_private`, `me.joinBlockedReason = lobby_private`); só entra quem for convidado. (Não confundir com equipa *fechada*, que é a que já está pronta para pagamento.) Pedidos que já estavam pendentes mantêm-se para o líder decidir. Convites continuam a funcionar.
- **Membros convidam** (`membersCanInvite`): se ligado, qualquer membro pode enviar convites; se desligado, só o líder. Os convites pendentes só o líder os vê e cancela.
- Qualquer jogador pode ver os membros de outras equipas, mas só pode pedir para entrar se não estiver já noutra equipa do torneio (`already_in_team`), a equipa não estiver fechada nem completa e não for privada.

## Notificações (exige sessão e termos em dia)
| Método | Caminho | Descrição |
|---|---|---|
| GET | `/api/v1/notifications` | Até 50 notificações, mais recentes primeiro: `{ unreadCount, items:[{id,type,createdAt,read,invite,request,event}] }`. Tipos: `team_invite` (`invite`), `join_request` (`request`: pedido para entrar, visto pelo líder; `status` `pending`/`accepted`/`rejected`/`cancelled`), `team_closed`, `slot_reserved`, `team_confirmed`, `request_decided`, `reservation_expiring`, `reservation_expired`, `team_eliminated` (`event: {teamId,teamName,colorHex,tournamentName,title,message,teamExists}`, texto já composto no servidor) |
| GET | `/api/v1/notifications/unread-count` | `{ count }`: leve, a app pergunta de tempos a tempos para mostrar o pontinho vermelho |
| POST | `/api/v1/notifications/read-all` | Marca todas como lidas (a app chama ao abrir a central). `204` |

Notificações de equipa (criadas na mesma transação do evento): **pedido para entrar** → o líder (aceitar/recusar: `POST /api/v1/join-requests/{id}/accept|reject`); **equipa fechada** → todos os membros, a dizer se têm de pagar (dividido, com o valor) ou não (total) e se há vaga ou ficaram em fila; **vaga reservada** → quando uma equipa em fila recebe vaga; **equipa confirmada** → todos pagaram. Os avisos de equipa guardam o texto e ficam mesmo que a equipa seja eliminada (`teamExists=false`). Lista completa (in-app, push, email): `docs/NOTIFICACOES.md`.

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

## Fecho da equipa, reserva de vaga e pagamento (simulado)

Vocabulário: equipa **privada** = não aceita pedidos de entrada (só convites); equipa **fechada** = o líder fechou o lobby (ninguém entra nem sai) e o pagamento fica disponível.

**Estados** (`reservation.state` no lobby, `state` em `/my/teams`): `forming` (em formação) -> `queued` (fechada, sem vaga livre: fila por ordem de chegada) -> `reserved` (vaga reservada, 30 min para pagar) -> `confirmed` (todos pagaram). A vaga conta como ocupada desde `reserved`.

| Rota | Quem | Descrição |
|---|---|---|
| `POST /teams/{id}/ready` `{ready}` | membro | Marca-se como preparado (ou deixa de estar). Só em formação. O líder conta sempre como preparado |
| `POST /teams/{id}/close` `{paymentMode}` | líder | `split` (cada um paga a sua parte, arredondada para cima) ou `total` (o líder paga tudo). Exige o mínimo de jogadores e todos os membros preparados. Se houver vaga livre fica logo `reserved` (30 min), senão `queued`. Cancela pedidos e convites pendentes |
| `POST /teams/{id}/pay` | membro | **Pagamento simulado** (no futuro chama a API real). `split`: paga a sua parte; `total`: só o líder, por todos. Quando todos pagaram a equipa fica `confirmed` |
| `POST /teams/{id}/reopen` | líder | Volta à formação (liberta a vaga e os pagamentos reservados, sem custos). Só se ainda não está `confirmed` |
| `POST /teams/{id}/disband` | líder | Elimina a equipa. Só se ainda não está `confirmed` |

- O lobby traz `reservation` (`state`, `closedAt`, `expiresAt`, `queuePosition`, `slotsTaken`, `maxTeams`, `reservationMinutes`, `penaltyMinutes`), `payment` (`feeCents`, `mode`, `shareCents`, `members`, `collectedCents`, `extraCents`, `roundedUp`, `paidCount`, `iPaid`, `canPay`, `cannotPayReason`) e em `me`: `ready`, `penaltyUntil`, `canClose`, `closeBlockedReason`/`closeBlockedMessage`, `canReopen`, `canDisband`. `members[].ready` e `members[].paid` só aparecem para membros.
- **Arredondamento**: o preço (`entryFeeCents`, por equipa) divide-se pelos membros no momento do fecho e arredonda-se para cima; `roundedUp`/`extraCents` avisam o líder de que a equipa paga a mais (a app mostra-o antes de fechar).
- **Fila**: ao fechar sem vaga livre, a equipa entra em `queued`; quando uma vaga é libertada passa à primeira da fila (quem fechou primeiro). Pontos de libertação: reserva expirada, `reopen`, `disband`.
- **Expiração** (processo em segundo plano, de 15 em 15 s): passados 30 min sem todos pagarem, a equipa volta a `forming` e os pagamentos são libertados sem custos. Quem devia ter pago e não pagou (no modo `total`, só o líder) fica **15 minutos penalizado** nesse torneio: não pode criar equipa, pedir para entrar nem aceitar convites (`409 player_penalized`; também não o podem convidar nem aceitar o pedido dele), e a sua equipa não pode fechar (`409 members_penalized`) até acabar. Se já está na equipa, continua nela. Os que pagaram ficam livres (podem sair, criar outra equipa ou o líder remove o penalizado e fecha de novo). As equipas de demonstração nunca expiram.
- **Equipa fechada**: ninguém entra, sai ou é removido (`409 team_closed`, ou `team_confirmed` se confirmada). Posição e transferência de líder continuam permitidas. Equipa `confirmed` não pode desistir (`409 team_confirmed_locked`).
- Erros do fecho: `below_min_players`, `members_not_ready`, `members_penalized`, `team_closed`, `registration_closed`. Erros de pagamento: `team_not_closed`, `team_in_queue`, `team_confirmed`, `reservation_expired`, `only_host_pays`, `already_paid`.
- Bloqueios no código: sempre **primeiro o torneio, depois a equipa** (evita deadlocks). Toda a atribuição de vagas passa por `ReservationAllocator` com o torneio bloqueado.
- **Criar equipas** continua ilimitado enquanto as inscrições estão abertas; só deixa de ser possível quando as confirmadas ocupam todas as vagas (`tournament_full`), caso em que as equipas sem vaga são eliminadas (as de demonstração nunca). Com todas as vagas só *reservadas*, criar equipas é possível: ficam na fila se fecharem.
- `teamsRegistered` (criadas), `teamsConfirmed` (todas pagas) e `isFull` (= todas as vagas reservadas ou confirmadas, sem vaga livre agora: etiqueta **Reservado** ou **Lotado**) e `isSoldOut` (= todas confirmadas: etiqueta **Lotado**) na lista e no detalhe.
- Para testar: `make team-sim ACTION=ready|expire|release|full|status TEAM="Nome" TORNEIO="parte do nome"` e `make pay-sim TEAM="Nome"` (Windows: `.\scripts\dev.ps1 team-sim ...`, ver `Makefile`). O futuro módulo de pagamentos só tem de substituir o corpo de `TeamService.PayAsync`.
- No fecho das inscrições continuam a ser removidas as equipas abaixo do mínimo de jogadores. As equipas em `forming`/`queued` acima do mínimo ficam por decidir (ver `docs/FUTURO.md`).

### Fecho das inscrições e vagas (regras)
- Ao terminar o prazo, são eliminadas todas as equipas que **não fecharam**. Ficam as confirmadas, as com vaga reservada (a pagar; o pagamento continua disponível) e as fechadas em fila.
- A fila continua a andar depois do prazo: se uma reserva expirar, a vaga passa à fila. Uma equipa cuja reserva expira depois do prazo é eliminada (já não pode voltar à formação). Quando todas as vagas estão confirmadas, as equipas em fila são eliminadas.
- Depois do prazo o líder já não pode reabrir (`reopen_after_deadline`), só desistir.
- Com a vaga confirmada, ninguém entra nem é convidado e `PATCH /teams/{id}/settings` devolve `409 team_confirmed_locked` (a app esconde as definições).
- Estado "em pagamento" = vaga reservada (`state = reserved`).

### Formação (estilo FIFA)
| Método | Caminho | Corpo | Descrição |
|---|---|---|---|
| PUT | `/api/v1/teams/{id}/lineup` | `{ formation, slots:[{userId, slot}] }` | Só o líder. Escolhe a formação da modalidade e quem joga em cada lugar (0 = guarda-redes; depois cada linha da defesa para o ataque, da esquerda para a direita); quem não vem na lista fica suplente. 400 `validation_error` (campo `lineup`) se a formação não existe na modalidade, o lugar está fora do campo ou repetido, ou o jogador não é da equipa |

O lobby devolve `lineup: {formation, formations[], slotCount}` e cada membro tem `slot` (null = suplente). Formações: futebol 7 `2-3-1, 3-2-1, 2-2-2, 3-3`; futebol 9 `3-3-2, 3-4-1, 2-4-2, 4-3-1`; futebol 11 `4-4-2, 4-3-3, 3-5-2, 4-2-3-1, 5-3-2`; futsal `1-2-1, 2-2, 1-1-2, 3-1`.

### Género
- Cada utilizador tem um género (`male`, `female`, `non_binary`, `other`) escolhido no registo (`validation_error` em `fields.gender` se faltar). `GET /me` devolve `gender`.
- Cada torneio tem `gender`: `male`, `female`, `non_binary`, `other` ou `mixed` (misto: todos os géneros). Só entra (criar equipa, pedir para entrar, aceitar convite) quem tem o mesmo género do torneio; senão `403 gender_not_allowed` (e `eligibility.reason = gender_not_allowed` no detalhe do torneio).
- Contas já existentes ficam com `other` (migração 014).

### Plantel por defeito e resultados
- O plantel (formação e titulares) é opcional: não é preciso para fechar nem pagar. Vale para todos os jogos.
- `GET /games/{id}` devolve `homeSquad` e `awaySquad`: `{formation, isFormal, players:[{displayName, position, slot, isStarter}]}`. Com plantel definido (`isFormal=true`): titulares por lugar (slot 0 = guarda-redes) e suplentes. Sem plantel: `isFormal=false`, sem formação nem slots, e `players` é a lista dos membros ordenada por posição (guarda-redes ao avançado; sem posição no fim). Mais tarde o gestor/árbitro poderá mudar o plantel por jogo.

### Notificações: apagar, expulso, novo líder; regras; penalizados
- `DELETE /api/v1/notifications/{id}` apaga uma notificação (`204`, `404` se não é do utilizador); `DELETE /api/v1/notifications` limpa todas (`204`). Apagar um convite/pedido só o tira da central.
- Novos tipos (eventos de equipa): `removed_from_team` (o líder expulsou-te) e `now_leader` (a liderança passou para ti).
- `PATCH /teams/{id}/settings` com a equipa fechada devolve `409 team_closed` (confirmada: `team_confirmed_locked`). A app esconde as definições enquanto a equipa não está em formação.
- O lobby devolve `tournament.rules` (regras do torneio; texto de exemplo até haver painel do gestor, coluna `tournaments.rules_text`, migração 015). A app mostra-as ao líder ao fechar a equipa.
- Cada membro do lobby traz `penalized` (só visível para os membros): a app mostra uma bolinha vermelha em vez do sinal de preparado/pago.
- `GET /tournaments?status=mine&scope=open|ongoing|finished` filtra "Os meus torneios" por estado.



## Torneios terminados: pódio, prémios e votação

| Pedido | Notas |
|---|---|
| `GET /api/v1/tournaments/{id}/results` | `{podium:[{place,teamId,name,colorHex}], bestPlayer, bestGoalkeeper, voting}`. Só tem dados se o torneio estiver terminado (senão tudo vazio). `bestPlayer`/`bestGoalkeeper` = `null` sem votação; `{status:"pending"\|"final", winners:[{userId,displayName,position,teamId,teamName,colorHex}]}` (vários vencedores = co-vencedores). `voting` = votação aberta agora: `{roundNumber (2 = desempate), closesAt, canVote, cannotVoteReason, categories:[{category, myVote, candidates:[...]}]}` |
| `PUT /api/v1/tournaments/{id}/voting/votes` `{category, candidateUserId}` | Vota ou muda o voto (`204`). `409 voting_closed`, `409 cannot_vote_self`, `404 candidate_not_found`, `403 email_not_verified_long_enough` |

`GET /api/v1/tournaments/{id}` passa a trazer `rules` (regulamento). Filtros da lista: `open` = `registration_open` + `registration_closed`; `ongoing` = só `ongoing`.


## Notificações, push e próximo jogo (adicionado 2026-10-29)

- `GET /api/v1/notifications` — além dos tipos de equipa, devolve `info` nos tipos `voting_opened`, `voting_second_round`, `voting_results`, `game_starting`, `game_changed`: `{tournamentId, tournamentName, gameId?, title, message, tournamentExists}`.
- `PUT /api/v1/me/push` `{enabled}` — interruptor geral de push. `200` com o utilizador (`pushEnabled`).
- `POST /api/v1/me/devices` `{token, platform}` (`android`|`ios`|`web`) — regista o token do telemóvel (um token só pertence a uma conta). `204`.
- `POST /api/v1/me/devices/remove` `{token}` — remove-o (ao sair). `204`.
- `GET /api/v1/tournaments/{id}/next-games` — `{ next, mine }` (jogos como em `/games`; `null` = não há). `next` = o jogo a decorrer ou o mais cedo por jogar; `mine` = o mesmo para a equipa do utilizador (null se não joga). A app usa-o na página de um torneio `ongoing`.
- Nomes: usernames, nomes de equipa e nomes de jogador com palavras proibidas devolvem `400 validation` com «Este nome não é permitido. Escolhe outro.» (lista em `Common/ProfanityFilter.cs`).

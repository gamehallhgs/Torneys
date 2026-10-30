# GameHall Torneios — Notificações

Estado: ✅ feito · — não se aplica. Canais: **App** (central/sino), **Push** (telemóvel), **Email**.
Regra: **push** só nos eventos essenciais (e o utilizador tem um interruptor geral no Perfil); **email** só em quatro; **votação** só na app.

| Evento | Quem recebe | App | Push | Email |
|---|---|---|---|---|
| Convite para uma equipa | Convidado | ✅ | ✅ | ✅ |
| Pedido para entrar na equipa | Líder | ✅ | ✅ | ✅ |
| Equipa fechada (quem paga o quê; vaga ou fila) | Todos os membros | ✅ | — | — |
| **Vaga reservada** (saiu da fila) | Todos os membros | ✅ | ✅ | ✅ |
| **Equipa confirmada** (todos pagaram) | Todos os membros | ✅ | ✅ | ✅ |
| **Tempo a acabar** («falta 5 minutos», uma só vez) | Só quem ainda tem de pagar | ✅ | ✅ | ✅ (só se a equipa ainda não está confirmada) |
| **Reserva expirada** (e penalização, se não pagou) | Todos os membros | ✅ | ✅ | — |
| Pedido aceite ou recusado | Jogador | ✅ | — | — |
| Equipa eliminada | Membros | ✅ | — | — |
| Expulso da equipa / passou a líder | Jogador | ✅ | — | — |
| Entrou alguém com o código | Líder | ✅ | — | — |
| **Jogo a começar** (30 min antes) | Jogadores das duas equipas | ✅ | ✅ | — |
| **Jogo marcado / alterado / adiado / cancelado** | Jogadores das duas equipas | ✅ | ✅ | — |
| **Votação aberta** | Quem participou no torneio | ✅ | — | — |
| **Segunda ronda - Votação aberta** | Quem participou no torneio | ✅ | — | — |
| **Resultados da votação** (com os vencedores) | Participantes e quem votou | ✅ | — | — |

«Resultado publicado» de um jogo **não** gera push (decisão de 2026-10-29).

## Como funciona (para quem mexer no código)

1. **Tudo nasce na tabela `notifications`** (central da app). Quem cria o evento não sabe nada de push nem de email.
2. `NotificationDispatcher` (de 15 em 15 s) lê as que ainda não foram entregues (`pushed_at` / `emailed_at` vazios) e envia **só** os tipos de `NotificationTypes.PushTypes` / `EmailTypes`. Cada notificação é reclamada antes do envio (no pior caso perde-se um aviso, nunca se repete) e avisos com mais de 1 hora já não saem. Mudar o que vai por push ou email = mudar essas duas listas (e `tests/.../DeliveryRulesTests.cs`, que as fixa).
3. Push: interface `IPushSender`. `Push:Provider = log` (por defeito) só escreve no log; `fcm` usa o Firebase Cloud Messaging (API HTTP v1) com a conta de serviço. Tokens inválidos são apagados sozinhos.
4. Interruptor geral: `users.push_enabled` (`PUT /api/v1/me/push {enabled}`). Desligado = nenhum push; a central da app não muda.
5. Tokens: `POST /api/v1/me/devices {token, platform}` ao iniciar sessão; `POST /api/v1/me/devices/remove {token}` ao sair.
6. **Jogo marcado/alterado**: trigger `gh_game_change_notify` (migração 019) — funciona seja quem for que altere o jogo (painel do gestor, árbitro, script). **Jogo a começar**: `GameStartingService` (1 min). Equipas de demonstração nunca avisam ninguém.
7. **Votação**: `VotingNotificationService` (1 min): abre ronda → aviso (1 vez por ronda); resultados quando as rondas fecharam e não há empate por desempatar (1 vez por torneio; se ninguém votou, não há aviso).
8. «Tempo a acabar» também só é entregue (push/email) a quem ainda tem de pagar; os outros membros continuam a vê-lo na app.

## Ligar o Firebase (quando quiseres push a sério)

1. Consola Firebase → novo projeto → adicionar app Android (e iOS). Descarrega `google-services.json` / `GoogleService-Info.plist`.
2. Firebase → Definições → Contas de serviço → «Gerar nova chave privada» (ficheiro JSON). **Nunca** vai para o git.
3. Backend: `Push__Provider=fcm`, `Push__Fcm__ProjectId=<id do projeto>`, `Push__Fcm__ServiceAccountFile=/caminho/chave.json` (montar o ficheiro no Docker como segredo).
4. App: `flutter pub add firebase_core firebase_messaging`, `flutterfire configure`, e implementar `PushService` (`mobile/lib/core/push_service.dart`) com `FirebaseMessaging.instance` (`getToken`, `onTokenRefresh`, `requestPermission`); passar a instância ao `AuthController(push: ...)` em `app.dart`. Enquanto isto não for feito a app usa `NoPushService` e continua a funcionar sem push.
5. iOS: ativar Push Notifications + Background Modes e carregar a chave APNs no Firebase (precisa de conta Apple Developer).
6. Pedir a permissão de notificações com uma frase clara (a Apple exige).

## Notas

- Os avisos de equipa e de torneio guardam o texto composto no servidor; convites e pedidos desaparecem se a equipa for eliminada.
- A central permite apagar notificações (deslizar) e «Limpar tudo».
- `member_joined`: o líder é avisado quando alguém entra com o código de convite (abre o lobby).
- Avisos de torneio/jogo (`voting_*`, `game_*`) vêm em `info: {tournamentId, tournamentName, gameId?, title, message, tournamentExists}` e abrem o torneio.

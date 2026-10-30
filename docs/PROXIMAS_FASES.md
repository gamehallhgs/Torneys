# GameHall Torneios — Próximas fases

## 1. Convite por código `GH-XXXX` — FEITO

O código é um atalho para entrar na equipa sem o líder convidar toda a gente.

- Cada equipa tem um código (`GH-` + 4 caracteres sem letras confusas: sem I, L, O, 0, 1).
- Definições do líder (só enquanto a equipa está em formação):
  - **Ativar código** (por defeito desligado). Desligado = o código não funciona.
  - **Entrada direta** (por defeito ligado). Ligado: quem usa o código entra logo e o líder recebe a notificação `member_joined`. Desligado: cria-se um pedido de entrada normal que o líder aceita ou recusa.
  - **Os membros veem o código** (por defeito desligado). Só o líder vê, a não ser que o permita.
- **Gerar código novo**: o antigo deixa de funcionar; máximo **3 por hora** por equipa (`429 invite_code_regen_limit`).
- Quem usa o código passa pelas mesmas regras de sempre (inscrições abertas, idade, género, já está noutra equipa, penalização, equipa cheia ou fechada). Funciona também com a equipa privada: o código é o convite.
- Tentativas com código inexistente/desligado contam para o limite de tentativas falhadas (10/hora, o mesmo das pesquisas de username).
- App: "Tenho um código" na lista de torneios (ver equipa → confirmar), quadro "Código da equipa" no lobby.

## 2. Nível opcional do torneio — ADIADO

Decisão do Hugo: **não fazer para já**; decide-se no futuro se se quer. Nada foi implementado.

## 3. Mini-guia de boas-vindas — FEITO

5 ecrãs (Encontra torneios; Cria ou entra numa equipa; Fecha e paga a tempo; Prepara o plantel; Fica a par). Aparece uma vez depois do primeiro login, pode ser saltado (`Saltar`) e é reaberto em Perfil → "Ver guia". Guardado na conta (`users.onboarding_seen_at`, `onboardingSeen` em `/me` e no login, `POST /api/v1/me/onboarding-seen`). Por agora usa ícones; ilustrações mais tarde.

## 4. Torneios terminados: pódio, melhor jogador e melhor guarda-redes — FEITO (lado do utilizador)

**Estados do torneio.** Aberto = `registration_open` (inscrições abertas) e `registration_closed` (etiqueta «Inscrições fechadas», entre o prazo e o primeiro jogo; continua a contar como «aberto» nos filtros). A decorrer = `ongoing`, a partir da hora do primeiro jogo. Terminado = `finished`, quando o resultado do último jogo é publicado (`tournaments.finished_at`). A transição é automática (`TournamentLifecycleService`, minuto a minuto).

**Página de um torneio terminado**, por esta ordem: Informação e Regras, Pódio, Melhor jogador e Melhor guarda-redes (lado a lado, ou a votação aberta), Equipas, Regulamento.

**Pódio.** Liga: os 3 primeiros da classificação. Eliminatórias: campeão e finalista saem da final, o 3.º do jogo de atribuição (sem esse jogo, os dois derrotados das meias-finais ficam ambos em 3.º).

**Votação** (duas categorias: melhor jogador, que inclui guarda-redes, e melhor guarda-redes):
- Aberta pelo gestor, durante o tempo que ele definir (limites dos admins), só dentro da janela (por defeito 6 h depois de o torneio terminar). Se não a abrir, não há prémios.
- Candidatos: todos os jogadores das equipas confirmadas, mesmo que não tenham jogado. Melhor guarda-redes: quem escolheu a posição GK.
- Podem votar os participantes e quem tem o email verificado há mais de 1 dia. Todos os votos valem o mesmo. Ninguém vota em si próprio. O voto muda-se até a ronda fechar. Votos secretos: só se mostra o vencedor, nunca contagens.
- **Empate:** o gestor pode abrir a ronda 2 (desempate) só com os empatados e só nas categorias empatadas. Se voltar a empatar, ficam os N empatados (co-vencedores). Sem ronda 2: enquanto a janela está aberta o prémio aparece como «Empate: a aguardar desempate»; depois de fechar, ficam os co-vencedores.
- **As duas rondas têm de acabar dentro da janela** (6 h depois de o torneio terminar): o fecho de cada ronda não pode passar do fim da janela (`round_exceeds_window`). A duração também é limitada pelos admins (por defeito 30 min a 3 h). A ronda 2 só abre depois de a ronda 1 fechar, por isso a 1.ª tem de ser curta se se quiser deixar espaço para um desempate.
- Perfil do vencedor: nome, equipa e posição (nunca `@username#tag`, email ou idade).
- Admins (definições em `platform_settings`, só por SQL até haver painel): `voting_window_hours` (6), `voting_min_voter_email_hours` (24), `voting_min_duration_minutes` (30), `voting_max_duration_minutes` (180). Mudar a janela só se aplica a torneios futuros e aos que terminaram nas últimas 24 h (cada torneio guarda a sua janela em `voting_window_hours` quando termina; ao mudar a definição, atualizar também `tournaments.voting_window_hours` desses torneios).

**Por fazer (próximos passos):** notificação «votação aberta» aos participantes e «resultado» aos vencedores; painel do gestor (abrir/fechar rondas) — a lógica já existe em `VotingService.OpenRoundAsync`, sem endpoint; só os seeds criam rondas por agora.

## 5. Notificações, próximo jogo e filtro de nomes — FEITO (2026-10-29)
- Push (servidor pronto, falta ligar o Firebase), emails «falta 5 minutos», «vaga reservada» e «equipa confirmada», avisos de jogo (a começar / marcado / alterado) e de votação (só na app). Ver `docs/NOTIFICACOES.md`.
- Página de um torneio a decorrer: «Próximo jogo do torneio» e «O meu próximo jogo».
- Filtro de palavras proibidas em usernames, nomes de equipa e nomes de jogador (`Common/ProfanityFilter.cs`; lista curta; extras sugeridos: paneleiro, fdp, nazi, hitler, família de «foder»).
- Pergunta legal sobre menores como vencedores públicos: `docs/CHECKLIST_LANCAMENTO.md`.
- Testes de integração com Postgres real e CI: ver `backend/tests/GameHall.Api.IntegrationTests/README.md`.

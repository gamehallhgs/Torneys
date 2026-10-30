# App móvel (Flutter) — GameHall Torneios

Fases 2 e 3: conta e autenticação + lista e detalhe de torneios (só leitura). Equipas e lobby chegam na fase 4.

## O que já faz
- **Torneios** (ecrã principal): separadores *Abertos / A decorrer / Terminados*, filtro por datas e por modalidade, "puxar para atualizar", "Ver mais"; ecrã de detalhe com informação, regras (formato, desempates por ordem), equipas inscritas e se podes criar equipa (idade, vagas, inscrições abertas)
- Criar conta (nome, email, **data de nascimento real, mínimo 13 anos**, palavra-passe, aceitação **não pré-marcada** dos Termos e da Política de Privacidade)
- Verificar email com código de 6 dígitos (e reenviar)
- Iniciar sessão, terminar sessão, terminar sessão em todos os dispositivos
- Recuperar palavra-passe por código
- Voltar a aceitar os Termos/Política quando a versão muda
- Perfil: alterar palavra-passe, exportar os meus dados (RGPD), eliminar conta, ler Termos e Política
- Sessão segura: refresh token no Keychain/Keystore, access token só em memória, **renovação de sessão serializada** (um só pedido de cada vez)

Ainda **não** tem: login Google/Apple (precisa das tuas contas de programador), criar equipas / lobby, jogos e quadro, notificações push.

## Pré-requisitos
- [Flutter](https://docs.flutter.dev/get-started/install) **3.27 ou superior** (`flutter doctor` sem erros)
- Android Studio (emulador Android) — no Linux e no Windows. iOS só compila num Mac.
- A API a correr (na raiz do repositório: `make up` no Linux, `.\scripts\dev.ps1 up` no Windows)

## Primeira vez
O repositório não inclui as pastas `android/` e `ios/` (são geradas pelo Flutter). Corre uma vez:

Linux/macOS:
```bash
cd mobile
bash tool/setup.sh
```
Windows (PowerShell):
```powershell
cd mobile
powershell -ExecutionPolicy Bypass -File tool\setup.ps1
```
O script gera as pastas, permite HTTP local **só em debug**, ajusta o `minSdk` para 23 e corre `flutter pub get`.

## Correr
```bash
flutter run                       # emulador Android (usa http://10.0.2.2:8080)
flutter run -d chrome             # (opcional) para ver rapidamente no browser
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080   # telemóvel real, IP do teu PC
```
Os emails (códigos de verificação) aparecem no MailHog: http://localhost:8025

## Testes
```bash
flutter test
flutter analyze
```

## Logótipo
Coloca o logótipo exportado do Figma em `assets/images/logo.png` (instruções em `assets/images/README.md`). Sem ele, a app mostra "GAME HALL" em texto.

## Estrutura
```
lib/
  main.dart, app.dart           arranque e navegação raiz (muda conforme o estado da sessão)
  core/                         API, sessão, tema, validações, armazenamento seguro
  widgets/                      botões, campos e fundo no estilo GameHall
  features/auth/screens/        boas-vindas, registo, login, verificação, recuperação, termos
  features/home/                início (provisório)
  features/profile/             perfil, alterar palavra-passe, exportar dados, eliminar conta
```

## Regras importantes
- **Nunca** guardar tokens em `SharedPreferences` ou em ficheiros: só no `TokenStore`.
- Todas as chamadas à API passam pelo `ApiClient`; o refresh é feito só pelo `AuthController` (dois refresh em simultâneo fazem a API fechar a sessão por suspeita de roubo).
- Em produção a API tem de usar HTTPS (o HTTP só está permitido em debug).

## Instalar tudo de uma vez ("requirements")
No Flutter, as bibliotecas Dart já vêm do `pubspec.yaml` (`flutter pub get`). O que falta é o resto (Flutter, JDK, Android SDK, emulador, Docker), que se instala com:
- Linux (Ubuntu/Debian): `bash scripts/install-prereqs-linux.sh` (na raiz do repositório)
- Windows: `powershell -ExecutionPolicy Bypass -File scripts\install-prereqs-windows.ps1`

## Se o emulador fechar ou a app não deixar entrar
1. Ver o que aconteceu (com a app a correr, noutro terminal): `flutter run -v 2>&1 | tee run.log` e, se o emulador fechar, `adb logcat -d | tail -200`.
   As linhas da app começam por `[GameHall]`.
2. O emulador a fechar sozinho é quase sempre do emulador, não da app. Confirma:
   - `ls -l /dev/kvm` tem de existir e ser acessível (`sudo adduser $USER kvm`, reiniciar sessão);
   - Android Studio > Device Manager > editar o dispositivo > *Graphics*: `Software` (se a placa gráfica for problemática);
   - RAM do emulador 2048 MB ou mais e pelo menos 8 GB livres no PC;
   - *Cold Boot Now* no menu do dispositivo.
3. Alternativa sem emulador: telemóvel real por USB (ativa *Depuração USB*) com `flutter run --dart-define=API_BASE_URL=http://IP_DO_PC:8080`.

## Correr no browser (Chrome) — sem emulador
Útil para testar o fluxo de conta enquanto o emulador não funciona.
1. Atualiza a API para a versão com CORS de desenvolvimento: `docker compose up --build -d` (na raiz).
2. Em `mobile/`: `bash tool/setup.sh` (volta a correr; agora gera também a pasta `web/`).
3. `flutter run -d chrome --web-port 5000 --dart-define=API_BASE_URL=http://localhost:8080`

Atenção: `http://10.0.2.2:8080` só funciona **dentro do emulador Android** (é o "endereço do teu PC" visto de lá). No browser usa sempre `http://localhost:8080`.

## Emulador a desligar sozinho: imagem do sistema
No log aparece `sdk gphone16k x86 64`: é a imagem **"16 KB Page Size"** do Android 15, experimental e instável em x86. Cria outro dispositivo em Android Studio > Device Manager > Create Device > Pixel 7 > escolhe uma imagem **sem "16 KB"** (ex.: API 34 "Google APIs" x86_64, ou API 35 normal) e usa esse.

## Dados de demonstração (torneios de teste)
Na raiz do repositório, com a API a correr:
```bash
make seed          # cria 10 torneios de demonstração (abertos, a decorrer, terminados, cheio, rascunho...)
make seed-remove   # apaga SÓ os dados de demonstração (tudo o que tem is_demo = true)
```
Windows: `.\scripts\dev.ps1 seed` e `.\scripts\dev.ps1 seed-remove`. Podes correr `make seed` outra vez para refrescar as datas. Os dados reais nunca são tocados.

## Fase 4: equipas e lobby

- No detalhe de um torneio: **Criar equipa** (nome + cor únicos), ou tocar numa equipa para **pedir para entrar**.
- Separador **Os meus torneios** na lista (ao lado de Abertos, A decorrer e Terminados): só os torneios em que estás numa equipa. No topo aparecem os convites recebidos (aceitar/recusar) e os pedidos enviados (cancelar).
- Ao abrir um torneio em que já tens equipa, o primeiro cartão é o atalho para o lobby (nome da equipa e nº de jogadores).
- Lobby: posições estilo FIFA, convidar por email, aceitar/recusar pedidos, passar a liderança, remover, sair.
- Para testar a sério precisas de duas contas (regista a segunda com outro email; o MailHog recebe os códigos).
- As equipas da demo (`make seed`) têm líder e jogadores demo (ver "Casos de demonstração" abaixo). Só aceitam pedidos de entrada se não estiverem confirmadas nem cheias.

## Fase 5: jogos, classificação, quadro, estatísticas e vídeos

- No detalhe de um torneio que já não está em inscrições aparece **Jogos, classificação e estatísticas**.
- Separadores conforme o formato: Jogos · Classificação (liga e grupos) · Quadro (eliminatórias e grupos) · Estatísticas.
- Toca num jogo para ver os eventos (golos, assistências, cartões) e os vídeos de destaque.
- Dados para ver: `make seed` (ou `.\scripts\dev.ps1 seed`) cria jogos, eventos e vídeos de exemplo em quatro torneios:
  *Liga Fut7 Primavera* (liga), *Copa Futsal Verão* (grupos + eliminatórias por definir), *Torneio Fut7 Verão* (eliminatórias terminadas, com penáltis) e *Taça Futsal Natal*.
- Depois de atualizar corre `flutter pub get` (nova dependência: `video_player`). Os vídeos de exemplo vêm de um endereço público dos documentos do Flutter, por isso precisam de internet.
- Se já geraste a pasta `android/` antes: para **versões de produção** o manifesto precisa de `<uses-permission android:name="android.permission.INTERNET" />` (o `tool/setup.sh`/`setup.ps1` já o acrescenta em projetos novos; em debug não é preciso).
- Tudo é só leitura: marcar resultados, cartões e vídeos é trabalho dos painéis do gestor e do árbitro (ainda por fazer).

## Fechar a equipa, reservar vaga e pagar (fase 9)

Vocabulário: equipa **privada** = não aceita pedidos de entrada; equipa **fechada** = pronta para pagamento (ninguém entra nem sai).

1. **Preparado:** cada jogador (menos o líder) liga "Estou preparado" no lobby. O líder vê quem já está.
2. **Fechar:** com o mínimo de jogadores e todos preparados, o líder escolhe **pagamento dividido** (cada um paga a sua parte, arredondada para cima: a app avisa se a equipa paga a mais) ou **total** (o líder paga tudo) e fecha a equipa. Pode reabri-la ou eliminá-la enquanto a vaga não estiver confirmada.
3. **Vaga:** havendo vaga livre, fica reservada **30 minutos** (contador no lobby). Sem vaga, a equipa entra numa **fila** por ordem de chegada e a app mostra a posição.
4. **Pagar:** o botão **Pagar (simulado)** regista o pagamento (ainda não se cobra nada). Quando todos pagaram, a vaga fica confirmada e a equipa já não pode desistir.
5. **Prazo falhado:** a equipa volta à formação, os pagamentos são libertados sem custos e quem não pagou fica **15 minutos penalizado** (a sua equipa não pode fechar). Os outros ficam livres de sair ou de o líder remover o penalizado.

- Os cartões mostram "x/N equipas confirmadas · y em formação". Nos torneios com inscrições abertas: etiqueta laranja **Lotado** quando todas as vagas estão confirmadas; etiqueta azul **Reservado** quando todas estão reservadas ou confirmadas mas nem todas confirmadas (se uma reserva falhar, abre vaga). Em ambos os casos ainda se pode criar equipa e ficar na fila; só no **Lotado** já não.
- O lobby atualiza sozinho de 15 em 15 s enquanto a equipa está na fila ou a pagar.
- **Penalização:** quem não pagou a tempo não pode criar equipa, pedir para entrar nem aceitar convites em nenhuma equipa desse torneio durante 15 minutos (continua na sua equipa, se lá estiver).
- Testes: `make team-sim ACTION=ready TEAM="Nome"` (todos preparados), `ACTION=expire` (expira a reserva), `ACTION=release` (liberta uma vaga), `ACTION=full TORNEIO="Outono"` (torneio com todas as vagas reservadas: aparece **Reservado** e testa-se a fila), `ACTION=status`; `make pay-sim TEAM="Nome"` paga por todos. A API processa as reservas de 15 em 15 s.
- Com `make seed` há um torneio cheio (*Copa Futsal Esgotada*), outro quase cheio (*Liga Fut11 Lisboa*) e dois com equipas fechadas a pagar e outras em formação.

## Casos de demonstração (`make seed`)

O seed cria **300 utilizadores demo** (`demo.NNN@gamehall.demo`, marcados `is_demo`, **não conseguem iniciar sessão**) e preenche lobbys com jogadores, posições e pagamentos. `make seed-remove` apaga tudo, utilizadores incluídos. Torneios com inscrições abertas:

| Torneio | Máx. equipas | O que mostra |
|---|---|---|
| Copa Futsal Esgotada | 8 | **Lotado**: 8/8 confirmadas (lobbys de 7, 10 e 12 jogadores, todos pagos) |
| Liga Fut11 Lisboa | 12 | **Quase cheio**: 11/12 confirmadas (1 vaga), equipas de 16 a 22 jogadores |
| Taça GameHall 7 - Outono | 16 | 2 confirmadas (uma no mínimo, outra com lobby cheio 14/14), 2 com **vaga reservada a pagar** (9 jogadores com 4 pagos; 14 com 11 pagos) e 1 em formação (5/9, alguns preparados) |
| Torneio Futsal Jovem (13-17) | 12 | 1 confirmada (12/12), 1 com vaga reservada a pagar (7 jogadores, 3 pagos) e 1 em formação (4 jogadores) |

Os torneios a decorrer, fechados e terminados têm todas as equipas confirmadas. As reservas demo têm 30 minutos a partir do `make seed` e nunca expiram sozinhas (volta a correr `make seed` para renovar o contador).

## Lobby: definições, ver outras equipas e filtro por localidade

- Em **qualquer equipa** podes tocar e ver os jogadores e as posições; só não podes pedir para entrar se já estás noutra equipa do mesmo torneio.
- O líder tem **Definições do lobby** (a qualquer momento): **Equipa privada** (não aceita pedidos de fora, só convites) e **Os membros também podem convidar** (por defeito só o líder convida).
- Na lista de torneios há um botão **Localidade**: escolhe o distrito (18) e, se quiseres, o concelho; só aparecem os torneios dessa zona. O mesmo botão tem "Todo o país" para limpar.
- Corrigido: no filtro de modalidades já podes voltar a **Todas as modalidades**.
- Casos de demo: *Dragões Urbanos* (Taça Outono) é privada; *Tubarões FC* (Taça Outono) deixa os membros convidar; *Leões do Norte* (Futsal Jovem) tem as duas definições ligadas. Os torneios demo estão em Porto, Braga, Lisboa, Faro e Coimbra (vários concelhos).

## Notificações (sino ao lado de "Os meus torneios")

- O sino fica na linha dos separadores (Abertos, A decorrer, Terminados, Os meus torneios). Aparece um **pontinho vermelho** quando há notificações novas; a app verifica de 45 em 45 segundos e ao voltar à app.
- Por agora só existem **convites para equipas**: quem recebe vê quem o convidou, a equipa e o torneio, com **Aceitar** / **Recusar** (e "Ver equipa e jogadores"). Depois de tratado o cartão mostra o resultado. Abrir a central marca tudo como lido (o pontinho desaparece).
- Os convites **já não aparecem em "Os meus torneios"**; lá ficam só os pedidos que enviaste.
- Para testar sem segunda conta: `make invite-sim TEAM="Dragões Urbanos" TORNEIO="Outono" EMAIL=o.teu@email.pt` (Windows: `.\scripts\dev.ps1 invite-sim "Dragões Urbanos" o.teu@email.pt "Outono"`). A equipa demo convida a tua conta e o sino ganha o pontinho no ciclo seguinte (ou puxa para atualizar).

## Avisos ao convidar

Ao convidar por email, o resultado aparece dentro da caixa "Convidar jogador": **verde** quando o convite é enviado e **vermelho** quando não pode ser, por exemplo "O jogador X já se encontra numa equipa do mesmo torneio." ou "Não te podes convidar a ti próprio.".

## Username (@) e tag (#)

- Ao **criar conta** escolhes o **nome** (como os outros te veem) e um **username** único (3 a 20 caracteres: minúsculas, números, `.` e `_`). A app diz "Disponível" ou o motivo enquanto escreves.
- Recebes também uma **tag de 3 algarismos** (ex.: `#482`) ao acaso, que **não muda** mesmo que mudes o username. O teu identificador completo é `@hugo#482` (no Perfil, com botão para copiar). Só tu vês a tua tag.
- **Perfil:** mostra o nome e o username (o email já não aparece). "Mudar username": só 1 vez por conta (as seguintes serão pagas no futuro); o antigo fica reservado 30 dias.
- **Convidar** (lobby): o mesmo campo aceita **email** ou **`username#tag`** (ex.: `hugo#482`). Se o username#tag não existir, o aviso vermelho diz "Este utilizador não se encontra na app."; se existir, o aviso verde diz "@hugo foi convidado para o lobby." (e a pessoa recebe a notificação). Máximo de 10 tentativas falhadas por hora e 40 convites pendentes por equipa.
- Nos lobbys os jogadores aparecem como "Nome @username" (sem a tag).
- Contas que já existiam receberam um username gerado a partir do nome e uma tag; podes mudá-lo logo uma vez, mesmo que seja o primeiro mês.
- Demo: os 300 jogadores demo têm username e tag previsíveis, por exemplo `joao.silva#007`, `rui.silva#014`, `tiago.silva#021` (tag = 7 × número). Experimenta convidá-los pelo lobby de uma equipa tua.

## Notificações de equipa, "Em pagamento" e nome (fase 9b)
- Central de notificações: convites, **pedidos para entrar** (o líder aceita/recusa), **equipa fechada** (quem paga o quê), **vaga reservada** e **equipa confirmada**.
- Estado da equipa com vaga reservada chama-se **Em pagamento** (`TeamState.label`).
- Com a vaga confirmada o líder já não vê as definições do lobby e ninguém entra nem é convidado.
- Perfil → **Mudar nome**: o nome visível pode mudar sempre que quiseres (`PATCH /api/v1/me/name`).
- Depois do prazo das inscrições só ficam equipas confirmadas, em pagamento e em fila (ver `docs/API.md`).
- Fase 10: também chegam avisos de pedido aceite/recusado, tempo a acabar (5 min), reserva expirada (com penalização) e equipa eliminada. Migração 012 (`expiry_warned_at`).
- Fase 12 (parcial): contagem decrescente nos cartões de torneio (últimos 3 dias; escalões 3/2/1 dias, 12 h, 1 h, 30 min) e skeleton na lista de torneios (`widgets/skeleton.dart`). Por fazer: menu de filtros, ecrã inicial, sinal verde/vermelho aberta/privada.
- Filtros: um só botão "Filtros" (modalidade, datas, localidade) com o número de filtros ativos e etiquetas removíveis; saudação "Olá, nome" no topo.
- Lista de equipas do torneio: ponto verde (aceita pedidos) / vermelho (privada ou fechada) e estado (em formação, em fila, em pagamento).
- Fase 13: formação estilo FIFA (campo + banco). O líder escolhe a formação e quem joga em cada lugar; todos veem (`LineupScreen`). Migração 013.
- Género: escolhido no registo (masculino, feminino, não binário, outro). Torneios têm categoria de género (ou misto) e só entra quem corresponde.
- Aceitar um convite nas notificações abre logo o lobby da equipa. O guarda-redes no campo foi subido e cada jogador mostra a sua posição.
- O líder define o plantel (formação e titulares) antes de fechar a equipa; o detalhe do jogo mostra o plantel das duas equipas.
- Plantel opcional: sem plantel formal, o jogo mostra a lista dos membros por posição (guarda-redes → avançado).
- Notificações: deslizar para apagar e "Limpar tudo"; avisos de expulsão e de novo líder.
- Ao fechar a equipa o líder vê o painel "Regras do torneio" (texto de exemplo); com a equipa fechada as definições do lobby desaparecem.
- Penalizados aparecem com uma bolinha vermelha no lobby. "Os meus torneios" tem filtro Todos/Abertos/A decorrer/Terminados.


## Código de convite e guia

- `features/teams/join_by_code_screen.dart`: "Tenho um código" (ver equipa → confirmar).
- Lobby: quadro "Código da equipa" (`TeamCode`).
- `features/onboarding/welcome_guide_screen.dart`: mini-guia de 5 ecrãs, mostrado uma vez (`AppUser.onboardingSeen`) e em Perfil → "Ver guia".


## Torneios terminados

- `features/voting/`: modelos, repositório e widgets (`PodiumCard`, `AwardsRow`, `VotingPanel`). A página do torneio (`tournament_detail_screen.dart`) reordena as secções quando o torneio está terminado.

## Push, próximo jogo e avisos (2026-10-29)
- `lib/core/push_service.dart`: `PushService` (por defeito `NoPushService`: a app funciona sem push). Para ligar o Firebase ver `docs/NOTIFICACOES.md`.
- Perfil: interruptor «Notificações push» (`PushSwitchTile`) → `PUT /me/push`.
- Notificações de torneio/jogo (`voting_*`, `game_*`) abrem o torneio; página de um torneio a decorrer mostra «O meu próximo jogo» e «Próximo jogo do torneio».
- Testes: `test/push_and_next_game_test.dart`.

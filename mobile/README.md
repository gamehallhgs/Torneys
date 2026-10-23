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

## Equipas confirmadas e etiqueta "Cheio"

- Qualquer pessoa pode criar equipas (sem limite). Uma equipa só fica **confirmada** quando tem o mínimo de jogadores e todos pagaram; ficam no torneio as primeiras N confirmadas e as restantes são eliminadas quando as vagas esgotam.
- Os cartões mostram "x/N equipas confirmadas · y em formação". Nos torneios com inscrições abertas e todas as vagas confirmadas aparece a etiqueta laranja **Cheio**.
- O lobby mostra se a equipa está confirmada ou o que falta (jogadores e pagamentos). Uma equipa confirmada fica fechada.
- Os pagamentos ainda não existem na app: para testar, `make pay-sim TEAM="Nome da equipa"` simula o pagamento e a equipa fica confirmada no minuto seguinte.
- Com `make seed` há um torneio cheio (*Copa Futsal Esgotada*), outro quase cheio (*Liga Fut11 Lisboa*) e dois com equipas ainda por confirmar.

## Casos de demonstração (`make seed`)

O seed cria **300 utilizadores demo** (`demo.NNN@gamehall.demo`, marcados `is_demo`, **não conseguem iniciar sessão**) e preenche lobbys com jogadores, posições e pagamentos. `make seed-remove` apaga tudo, utilizadores incluídos. Torneios com inscrições abertas:

| Torneio | Máx. equipas | O que mostra |
|---|---|---|
| Copa Futsal Esgotada | 8 | **Cheio**: 8/8 confirmadas (lobbys de 7, 10 e 12 jogadores, todos pagos) |
| Liga Fut11 Lisboa | 12 | **Quase cheio**: 11/12 confirmadas (1 vaga), equipas de 16 a 22 jogadores |
| Taça GameHall 7 - Outono | 16 | 2 confirmadas (uma no mínimo, outra com lobby cheio 14/14) e 3 em formação: abaixo do mínimo (5/9, 0 pagos), completa com pagamentos em falta (9, 4 pagos) e lobby cheio com 11/14 pagos |
| Torneio Futsal Jovem (13-17) | 12 | 1 confirmada (12/12) e 2 em formação (7 jogadores com 3 pagos; 4 jogadores sem pagamentos) |

Os torneios a decorrer, fechados e terminados têm todas as equipas confirmadas. Para confirmar uma equipa em formação: `make pay-sim TEAM="Nome da equipa"`.

## Lobby: definições, ver outras equipas e filtro por localidade

- Em **qualquer equipa** podes tocar e ver os jogadores e as posições; só não podes pedir para entrar se já estás noutra equipa do mesmo torneio.
- O líder tem **Definições do lobby** (a qualquer momento): **Lobby fechado** (não aceita pedidos de fora, só convites) e **Os membros também podem convidar** (por defeito só o líder convida).
- Na lista de torneios há um botão **Localidade**: escolhe o distrito (18) e, se quiseres, o concelho; só aparecem os torneios dessa zona. O mesmo botão tem "Todo o país" para limpar.
- Corrigido: no filtro de modalidades já podes voltar a **Todas as modalidades**.
- Casos de demo: *Dragões Urbanos* (Taça Outono) tem o lobby fechado; *Tubarões FC* (Taça Outono) deixa os membros convidar; *Leões do Norte* (Futsal Jovem) tem as duas definições ligadas. Os torneios demo estão em Porto, Braga, Lisboa, Faro e Coimbra (vários concelhos).

# GameHall Torneios — Papéis e permissões (lista viva)

Tudo o que já foi pensado para **gestores, árbitros e admins** e ainda não está feito. Quando chegar a altura de
definir os papéis (roles) e as permissões, parte-se desta lista. Atualizar sempre que sair uma ideia nova.
Última atualização: 2026-10-27.

Hoje só existe o papel `Player` (`users.role`). Os restantes estão previstos (`Referee`, `Manager`, `Admin`).
Plano: permissões **por entidade** (um gestor de uma associação/clube delega permissões a perfis) numa tabela própria.

## Gestor (clube ou associação)
- Criar e editar torneios: modalidade, formato, **género** (masculino, feminino, não binário, outro, **misto**), escalão etário, preço, vagas, jogadores por equipa, datas, local (distrito e concelho obrigatórios), desempates, 3.º lugar.
- Abrir um período suplementar de inscrições.
- Remover uma equipa do torneio.
- Calendário automático e gestão de campos/horários; adiar ou cancelar jogos.
- Comunicados aos participantes.
- Painel financeiro (pagamentos, faturas), exportações.
- Disciplina: suspensões (cartões acumulados).
- **Alterar o plantel de uma equipa por jogo** (hoje há um plantel por defeito igual para todos os jogos).
- Delegar permissões a outros perfis da entidade (ex.: só marcadores, só highlights).
- Página pública do torneio com QR e placar ao vivo.
- Níveis do torneio (rótulo opcional).
- **Escrever as regras do torneio** (aparecem ao líder quando fecha a equipa; hoje há um texto de exemplo, `tournaments.rules_text`).

- **Torneio que nunca acaba (importante para o painel do gestor):** um torneio só passa a «terminado» quando **não resta nenhum jogo `scheduled`, `running` ou `postponed`** (ver `TournamentLifecycleService`). Se ficar um jogo adiado ou por jogar para sempre, o torneio fica **«a decorrer» indefinidamente** e a votação/pódio nunca abrem. O painel do gestor tem de ter, por isso: **cancelar jogo** (passa a `cancelled`, não conta), **adiar com nova data** e **terminar o torneio manualmente** (força `finished`, `finished_at = agora`, com confirmação e auditoria). Mudar a data/campo/estado de um jogo já avisa os jogadores sozinho (trigger).
- **Denúncias de jogadores:** ver «Admin» e `FUTURO.md`.

## Árbitro
- Painel/app com **modo offline** e ficha de jogo digital.
- Registar golos, assistências, cartões, resultado e penáltis; fechar o jogo.
- Carregar vídeos de destaque (máx. 1 min, 1080p).
- Confirmar ou **alterar o plantel por jogo** (titulares e suplentes das duas equipas).
- Permissões parciais (só marcadores / só highlights).

## Admin (plataforma)
- Bloquear e desbloquear contas de utilizadores.
- Gerir gestores e árbitros (criar, suspender, permissões).
- Lista de utilizadores a rever (denúncias, bloqueios), nomes e usernames proibidos.
- **Painel de denúncias** com filtro por jogador (futuro, ver `FUTURO.md`). O filtro automático de nomes (`Common/ProfanityFilter.cs`) é curto de propósito: o admin bloqueia a conta quando for preciso.
- Ver auditoria (`audit_log`), sessões e avisos de novo dispositivo.
- Mudar o género de uma conta (hoje o género escolhido no registo não se altera na app; pedido de correção por suporte).
- Acesso a configurações legais e versões de termos.

## Segurança comum
- MFA obrigatório para gestores, árbitros e admins; lista de sessões; aviso de novo dispositivo.
- Todas as ações sensíveis ficam em auditoria.

## Princípios de arquitetura (modularidade)
- Monólito modular: uma pasta por módulo em `backend/src/GameHall.Api/Modules/`; o que cada módulo regista está em `ModuleRegistration.cs` (serviços, tarefas, rotas).
- Cada módulo tem a sua loja (SQL) e o seu serviço; os módulos não escrevem no SQL uns dos outros, falam por serviços.
- Regras de negócio em classes puras (`*Rules`, `Formations`) com testes; endpoints finos.
- Os novos painéis (gestor, árbitro, admin) entram como módulos novos, com a sua política de autorização, sem tocar nos módulos do jogador.

## Votação do melhor jogador / guarda-redes (adicionado 2026-10-29)
- **Gestor:** abrir a votação de um torneio terminado (duração dentro dos limites dos admins) de modo a que acabe até 6 h depois do fim; abrir a ronda 2 de desempate (só empatados, só categorias empatadas), que também tem de acabar dentro da janela; decidir não fazer votação (então não há prémios). Endpoints por criar (`VotingService.OpenRoundAsync` já tem as regras).
- **Admin:** definir a janela para abrir votações (por defeito 6 h; afeta torneios futuros e os que terminaram há menos de 24 h), a duração mínima/máxima de cada ronda (30 min / 3 h) e há quantas horas o email tem de estar verificado para votar sem ter participado (24 h). Hoje: tabela `platform_settings`.
- **Notificações de votação:** já existem (só na app), disparadas pelo servidor quando o gestor abre uma ronda e quando saem os resultados (ver `NOTIFICACOES.md`).
- **Ideias adiadas:** restringir candidatos a quem jogou quando houver presenças por jogo.

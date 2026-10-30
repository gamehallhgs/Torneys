# GameHall Torneios — Em espera (futuro)

Lista do que foi discutido e **decidido adiar**. Atualizar sempre que algo entra ou sai.
Última atualização: 2026-10-26.

## Vocabulário (decidido)
- **Equipa fechada** = pronta para pagamento (ninguém entra, ninguém sai).
- **Equipa privada** = não aceita pedidos de entrada de fora (só convites).
- (Fase 9: `closed_to_requests` / `lobby_closed` passaram a `is_private` / `lobby_private`.)

## Decisões em aberto (fase 9)
- (Decidido) No fecho das inscrições: ficam confirmadas, em pagamento e em fila; as que não fecharam são eliminadas; as em fila saem quando todas as vagas estão confirmadas.
- Se o líder reabre a equipa quando já havia gente na fila, a equipa perde o lugar (volta ao fim ao fechar de novo). Pode ser preciso um limite de reaberturas.
- A penalização de 15 min é por torneio: o jogador não pode criar nem entrar em equipas, e a equipa onde está não pode fechar. (Decidido.)
- Notificações do ciclo de vida (fase 10): vaga reservada, tempo a acabar, reserva expirada, penalização, confirmada, eliminada, pedido aceite/recusado.

## Próximas fases do jogador
Convite por código e mini-guia já feitos (ver `docs/PROXIMAS_FASES.md`). **Nível opcional do torneio: adiado, o Hugo decide no futuro se quer.**

## Depois de acabar o lado do utilizador
(Lista completa de capacidades de gestores, árbitros e admins: `docs/PAPEIS_E_PERMISSOES.md`.)
- Painel do gestor (clubes e associações): lógica, segurança, interface, serviços, permissões.
- Painel/app do árbitro (modo offline, ficha de jogo digital).
- MFA obrigatório para gestores, árbitros e admins; lista de sessões; aviso de novo dispositivo.
- Admins podem bloquear contas de utilizadores. Gestor do torneio pode remover uma equipa.
- Gestor obrigado a indicar distrito e concelho ao criar torneio.
- Calendário automático, comunicados, painel financeiro, disciplina (suspensões), exportações.
- Página pública do torneio com QR e placar ao vivo.

## Pagamentos reais (versão futura)
- Para já: botão que **simula** o pagamento (futuramente chama a API real).
- Saldo reservado (congelado) e só debitado quando todos os membros confirmarem.
- Fatura certificada, NIF, prestador (MB WAY, Multibanco, cartão); webhooks assinados e idempotência.
- Quem paga por menores (13+): por decidir (responsável legal / clube).
- Sem reembolsos (regra de negócio decidida).

## Parte social (versão futura)
- Amigos, perfil público de jogador, estatísticas pessoais, emblemas.
- "Quem me pode convidar" (todos / amigos / ninguém).
- "Procuro equipa" / "equipa procura jogadores".
- Cartão de resultado partilhável, denunciar/bloquear utilizadores.
- Chat, votações.

## Outras funcionalidades adiadas
- "O meu próximo jogo" (hora, local, mapa, calendário).
- Lista de espera em torneios cheios.
- Avisos de calor/chuva, informação de acessibilidade do recinto, boleias.
- Termo de responsabilidade e contacto de emergência na inscrição.
- Desbloqueio biométrico (sem necessidade por agora).
- Login Google/Apple.
- Torneios abertos a todos (nível passa a ter mais relevo; por agora o nível é opcional e pode ficar vazio).
- Açores e Madeira nas localidades.
- ✅ Filtro de palavrões feito (`Common/ProfanityFilter.cs`; lista curta de propósito). Falta o botão de bloquear conta no painel de admin.
- Lista final de usernames reservados (por decidir).

## Operação e legal (antes do lançamento)
- Cópias de segurança com teste de restauro, monitorização e alertas.
- Preencher os `[PREENCHER]` dos documentos legais; rever com advogado (RGPD, termos, menores, faturação, subcontratantes).
- Publicar a app e o domínio (necessário para links de convite funcionarem de verdade).
- Exportar o logótipo para `mobile/assets/images/logo.png`; repositório GitHub.
- Mudar o género da conta (hoje só por suporte/admin).
- Filtro de torneios por género.
- Plantel por jogo (gestor/árbitro).

- **Mudanças de username pagas:** cada conta tem 1 mudança gratuita (`UsernameRules.FreeChanges`); a partir daí será paga. Falta definir preço e pagamento; por agora não há mais mudanças. (Regra mudada em 2026-10-29: antes era 1 por mês.)

## Denunciar jogadores (futuro, ainda não implementar)
- Botão **«Denunciar perfil»** no perfil de um jogador (com motivo e comentário opcional).
- **Painel de denúncias para admins**: lista com filtro **por jogador** (ver todas as denúncias de uma pessoa), por motivo, por estado; ações: ignorar, avisar, **bloquear a conta**.
- O filtro de palavras (lista curta) não resolve tudo: o admin bloquear a conta é a rede de segurança para nomes que escaparam ao filtro.
- A Apple exige, para conteúdo gerado por utilizadores (nomes de equipa, usernames), mecanismo de denúncia/bloqueio e contacto: ver `CHECKLIST_LANCAMENTO.md`.

## Push (feito o lado do servidor)
- Falta ligar o Firebase na app (passos em `docs/NOTIFICACOES.md`).

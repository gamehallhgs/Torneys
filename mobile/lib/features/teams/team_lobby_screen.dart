import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth_scope.dart';
import '../../core/error_messages.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../widgets/gh_widgets.dart';
import 'lineup_screen.dart';
import 'team_models.dart';
import 'teams_repository.dart';

/// Lobby da equipa (sem chat): membros e posições; ações do líder; pedir para entrar.
class TeamLobbyScreen extends StatefulWidget {
  const TeamLobbyScreen({super.key, required this.teamId});

  final String teamId;

  @override
  State<TeamLobbyScreen> createState() => _TeamLobbyScreenState();
}

class _TeamLobbyScreenState extends State<TeamLobbyScreen> {
  TeamLobby? _lobby;
  String? _error;
  String? _info;
  bool _busy = false;
  bool _started = false;
  final _inviteEmail = TextEditingController();

  // Forma de pagamento escolhida pelo líder ao fechar a equipa: 'split' (dividido) ou 'total'.
  String _mode = 'split';

  // Contador da reserva (1 s) e atualização automática enquanto a equipa está em fila ou a pagar.
  Timer? _ticker;
  int _ticks = 0;

  // Resultado do último convite: aparece dentro da caixa "Convidar jogador" (vermelho = erro, verde = enviado).
  String? _inviteError;
  String? _inviteInfo;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final l = _lobby;
    if (!mounted || l == null || !(l.isQueued || l.isReserved)) {
      return;
    }
    _ticks++;
    final overdue = l.isReserved && l.secondsLeft <= 0;
    if (!_busy && (_ticks % 15 == 0 || (overdue && _ticks % 4 == 0))) {
      _load();
    } else if (l.isReserved) {
      setState(() {}); // atualiza o contador
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _inviteEmail.dispose();
    super.dispose();
  }

  TeamsRepository get _repo => TeamsRepository(AuthScope.of(context).api);

  Future<void> _load() async {
    try {
      final lobby = await _repo.lobby(widget.teamId);
      if (mounted) {
        setState(() {
          _lobby = lobby;
          _error = null;
        });
      }
    } catch (e, st) {
      debugPrint('[GameHall] lobby falhou: $e\n$st');
      if (mounted) {
        setState(() => _error = friendlyError(e));
      }
    }
  }

  /// Executa uma ação, mostra o erro (se houver) e volta a carregar o lobby.
  Future<bool> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) {
      return false;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    var ok = false;
    try {
      await action();
      ok = true;
      _info = success;
    } catch (e, st) {
      debugPrint('[GameHall] ação do lobby falhou: $e\n$st');
      _error = friendlyError(e);
    }
    if (mounted) {
      await _load();
      if (mounted) {
        setState(() => _busy = false);
      }
    }
    return ok;
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GhColors.surface,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _pickPosition(TeamLobby lobby) async {
    final current = lobby.me?.position;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: GhColors.surface,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('A tua posição principal',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            for (final code in TeamLabels.positionCodes)
              ListTile(
                leading: _PositionChip(code),
                title: Text(TeamLabels.position(code)),
                trailing: code == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(ctx).pop(code),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await _run(() => _repo.setPosition(lobby.id, picked), success: 'Posição guardada.');
    }
  }

  Future<void> _sendInvite(TeamLobby lobby) async {
    if (_busy) {
      return;
    }
    final input = _inviteEmail.text.trim();
    // "hugo#482" (ou "@hugo#482") = username#tag; qualquer outra coisa tem de ser um email.
    final isHandle = input.contains('#');
    final handle = isHandle ? Validators.parseHandle(input) : null;
    final problem = isHandle
        ? (handle == null ? 'Escreve o username com a tag de 3 algarismos, por exemplo hugo#482.' : null)
        : (Validators.email(input) != null ? 'Indica um email ou um username#tag válido.' : null);
    if (problem != null) {
      setState(() {
        _inviteError = problem;
        _inviteInfo = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _inviteError = null;
      _inviteInfo = null;
      _error = null;
      _info = null;
    });
    try {
      if (handle != null) {
        await _repo.invite(lobby.id, username: '${handle.username}#${handle.tag}');
        _inviteInfo = '@${handle.username} foi convidado para o lobby.';
      } else {
        await _repo.invite(lobby.id, email: input);
        // Sem mensagem: por privacidade não dizemos se o email tem conta.
        _inviteInfo = null;
      }
      _inviteEmail.clear();
    } catch (e, st) {
      debugPrint('[GameHall] convite falhou: $e\n$st');
      _inviteError = friendlyError(e);
    }
    if (mounted) {
      await _load();
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _leave(TeamLobby lobby) async {
    final confirmed = await _confirm(
      'Sair da equipa',
      lobby.membersCount <= 1
          ? 'És o único membro: a equipa será eliminada.'
          : 'Tens a certeza de que queres sair?',
      'Sair',
    );
    if (!confirmed || !mounted) {
      return;
    }
    final ok = await _run(() => _repo.leave(lobby.id));
    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _transfer(TeamLobby lobby, TeamMember m) async {
    final confirmed = await _confirm(
      'Passar a liderança',
      '${m.displayName} passa a ser o líder da equipa e tu ficas como jogador.',
      'Passar',
    );
    if (confirmed) {
      await _run(() => _repo.transferHost(lobby.id, m.userId), success: 'Liderança transferida.');
    }
  }

  Future<void> _remove(TeamLobby lobby, TeamMember m) async {
    final confirmed = await _confirm(
      'Remover jogador',
      'Remover ${m.displayName} da equipa?',
      'Remover',
    );
    if (confirmed) {
      await _run(() => _repo.removeMember(lobby.id, m.userId));
    }
  }

  /// 0 -> "0 €" (nos textos de pagamento "Grátis" soa mal).
  String _eur(int cents) => cents <= 0 ? '0 €' : Fmt.money(cents);

  Future<void> _closeTeam(TeamLobby l) async {
    final p = l.payment;
    final split = _mode == 'split';
    final rounding = split && p.roundedUp
        ? '\n\nO valor foi arredondado para cima: a equipa paga ${_eur(p.collectedCents)} '
            'em vez de ${_eur(p.feeCents)} (+${_eur(p.extraCents)}).'
        : '';
    final who = split
        ? 'Cada um dos ${l.membersCount} jogadores paga ${_eur(p.shareCents)}.'
        : 'Pagas ${_eur(p.feeCents)} por toda a equipa.';
    final text = '$who$rounding\n\nDepois de fechar, ninguém entra nem sai. Se houver vaga livre, fica reservada '
        'durante ${l.reservation.reservationMinutes} minutos para pagarem; quem não pagar a tempo '
        'fica ${l.reservation.penaltyMinutes} minutos penalizado. Sem vaga livre, a equipa entra na fila '
        'por ordem de chegada. Podes reabrir a equipa enquanto a vaga não estiver confirmada.';
    if (!await _confirm('Fechar a equipa', text, 'Fechar equipa')) {
      return;
    }
    final ok = await _run(() => _repo.close(l.id, _mode), success: 'Equipa fechada.');
    if (ok && mounted) {
      // O líder vê as regras do torneio antes de a equipa avançar para o pagamento.
      await _showRules(l.rules);
    }
  }

  /// Painel com as regras exigidas pelo torneio (decididas pelo gestor).
  Future<void> _showRules(String rules) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: GhColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Regras do torneio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'Estas são as regras exigidas pelo torneio. Quando a equipa pagar, a vossa participação fica sujeita a elas.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(rules.isEmpty ? 'Sem regras específicas.' : rules, style: const TextStyle(height: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
              GhButton(label: 'Percebi', onPressed: () => Navigator.of(sheet).pop()),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reopenTeam(TeamLobby l) async {
    final confirmed = await _confirm(
      'Reabrir a equipa',
      'A vaga é libertada (passa à próxima equipa da fila) e os pagamentos reservados são libertados '
          'sem custos. Voltam a poder entrar e sair jogadores.',
      'Reabrir',
    );
    if (confirmed) {
      await _run(() => _repo.reopen(l.id), success: 'Equipa reaberta.');
    }
  }

  Future<void> _disbandTeam(TeamLobby l) async {
    final confirmed = await _confirm(
      'Eliminar a equipa',
      'A equipa deixa de existir e todos os jogadores saem. Esta ação não se pode desfazer.',
      'Eliminar',
    );
    if (!confirmed || !mounted) {
      return;
    }
    final ok = await _run(() => _repo.disband(l.id));
    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _lobby;
    return GhPage(
      title: 'Equipa',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          icon: const Icon(Icons.refresh),
          onPressed: _busy ? null : _load,
        ),
      ],
      children: [
        if (_error != null) GhBanner.error(_error!),
        if (_info != null) GhBanner.success(_info!),
        if (l == null && _error == null)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
        if (l == null && _error != null) GhButton(label: 'Tentar novamente', onPressed: _load),
        if (l != null) ..._content(l),
      ],
    );
  }

  List<Widget> _content(TeamLobby l) {
    return [
      Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: l.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(l.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(l.tournamentName, style: const TextStyle(color: Colors.white60)),
      if (l.isPrivate && l.isForming) ...[
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            avatar: Icon(Icons.lock_outline, size: 16),
            label: Text('Equipa privada: só por convite', style: TextStyle(fontSize: 12)),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
      const SizedBox(height: 16),
      if (l.isMember && l.isPenalized) _penaltyBanner(l),
      _stateBox(l),
      if (l.isMember && l.isForming && l.registrationOpen) _readyBox(l),
      _Box(
        title: 'Jogadores ${l.membersCount}/${l.maxPlayers}',
        children: [
          Text(
            'Mínimo ${l.minPlayers} jogadores (titulares e suplentes). '
            'Equipas abaixo do mínimo são removidas quando as inscrições fecham.',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          if (l.isMember && l.belowMinimum) ...[
            const SizedBox(height: 8),
            Text(
              'Faltam ${l.minPlayers - l.membersCount} jogador(es) para o mínimo.',
              style: const TextStyle(color: GhColors.error, fontSize: 13),
            ),
          ],
          if (l.isMember && l.missingPositions > 0) ...[
            const SizedBox(height: 8),
            Text(
              l.missingPositions == 1
                  ? '1 jogador ainda não escolheu a posição (obrigatório antes do pagamento).'
                  : '${l.missingPositions} jogadores ainda não escolheram a posição (obrigatório antes do pagamento).',
              style: const TextStyle(color: Colors.amber, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          for (final m in l.members) _memberRow(l, m),
        ],
      ),
      if (l.lineup.formations.isNotEmpty) ...[
        GhButton(
          label: l.isHost ? 'Formação da equipa' : 'Ver formação',
          secondary: true,
          onPressed: _busy
              ? null
              : () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => LineupScreen(lobby: l)),
                  );
                  if (mounted) {
                    await _load();
                  }
                },
        ),
        const SizedBox(height: 12),
      ],
      if (l.isMember) ...[
        GhButton(
          label: l.me?.position == null ? 'Escolher a minha posição' : 'Mudar a minha posição',
          secondary: true,
          onPressed: _busy ? null : () => _pickPosition(l),
        ),
        const SizedBox(height: 12),
      ],
      if (l.isHost && l.canClose) _closeBox(l),
      if (l.isHost && l.isForming && !l.canClose && l.closeBlockedMessage != null) _closeBlockedBox(l),
      if (l.isMember && l.isReserved) _paymentBox(l),
      if (l.isHost && l.isForming) _settingsBox(l),
      if (l.inviteCode != null && l.isForming) _codeBox(l, l.inviteCode!),
      if (l.isHost && l.isForming) ..._hostSections(l),
      if (l.canInvite && !l.isHost) _inviteBox(l),
      if (!l.isMember) ..._visitorActions(l),
      if (l.isHost && (l.canReopen || l.canDisband)) ..._hostWithdrawActions(l),
      if (l.isMember && l.registrationOpen && l.isForming) ...[
        const SizedBox(height: 4),
        GhButton(
          label: 'Sair da equipa',
          danger: true,
          onPressed: _busy ? null : () => _leave(l),
        ),
        if (l.isHost && l.membersCount > 1)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Como líder, tens de passar a liderança a outro jogador antes de sair.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
      ],
      if (l.isMember && l.isClosed && !l.confirmed)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'A equipa está fechada: ninguém entra nem sai. O líder pode reabri-la enquanto a vaga não estiver confirmada.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
    ];
  }

  // ---------- Estado, preparado, fecho e pagamento ----------

  Widget _penaltyBanner(TeamLobby l) {
    final until = l.penaltyUntil!.toLocal();
    final hh = until.hour.toString().padLeft(2, '0');
    final mm = until.minute.toString().padLeft(2, '0');
    return GhBanner.error(
      'Estás penalizado até às $hh:$mm por não teres pago a tempo: enquanto durar, '
      'a tua equipa não pode fechar para reservar vaga.',
    );
  }

  Widget _stateBox(TeamLobby l) {
    if (l.confirmed) {
      return const GhBanner.success(
        'Vaga confirmada: todos os jogadores pagaram. A equipa está fechada e já não pode desistir do torneio.',
      );
    }
    if (!l.registrationOpen && !l.isReserved && !l.isQueued) {
      return const SizedBox.shrink();
    }
    if (l.isQueued) {
      final pos = l.reservation.queuePosition;
      return _Callout(
        color: Colors.lightBlueAccent,
        title: pos == null ? 'Equipa fechada: na fila de espera' : 'Equipa fechada: posição $pos na fila',
        children: [
          const Text(
            'Neste momento não há vagas livres. Assim que uma ficar livre, é reservada automaticamente '
            'para esta equipa, por ordem de chegada (quem fechou primeiro). Vais ser avisado e terão tempo para pagar.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          if (l.isHost) ...[
            const SizedBox(height: 6),
            const Text('Podes reabrir a equipa a qualquer momento.',
                style: TextStyle(fontSize: 12, color: Colors.white60)),
          ],
        ],
      );
    }
    if (l.isReserved) {
      final left = l.secondsLeft;
      return _Callout(
        color: Colors.greenAccent,
        title: left > 0 ? '${TeamState.label(TeamState.reserved)}: ${formatCountdown(left)} para pagar' : '${TeamState.label(TeamState.reserved)}: tempo esgotado',
        children: [
          Text(
            left > 0
                ? 'Todos têm de pagar dentro de ${l.reservation.reservationMinutes} minutos para a vaga ficar confirmada. '
                    'Quem não pagar a tempo fica ${l.reservation.penaltyMinutes} minutos penalizado e a equipa volta à formação.'
                : 'A reserva terminou: a equipa vai voltar à formação em instantes.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      );
    }

    // Em formação.
    final missing = <String>[];
    if (l.belowMinimum) {
      final n = l.minPlayers - l.membersCount;
      missing.add(n == 1 ? '1 jogador' : '$n jogadores');
    }
    final slots = l.reservation.maxTeams > 0
        ? ' (vagas ocupadas: ${l.reservation.slotsTaken}/${l.reservation.maxTeams})'
        : '';
    return _Callout(
      color: Colors.amber,
      title: 'Equipa ${TeamState.label(TeamState.forming).toLowerCase()}',
      children: [
        Text(
          'Quando houver pelo menos ${l.minPlayers} jogadores e todos estiverem preparados, o líder fecha a equipa '
          'e reserva uma vaga para pagar$slots. Só equipas com vaga confirmada (todos pagos) ficam no torneio.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        if (l.isMember && missing.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Falta: ${missing.join(' e ')}.',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }

  Widget _readyBox(TeamLobby l) {
    if (l.isHost) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Text(
          'Como líder, ao fechares a equipa já estás preparado.',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
      );
    }
    return _Box(
      title: 'Estou preparado',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.iAmReady ? 'Preparado para pagar' : 'Ainda não estou preparado'),
          subtitle: const Text(
            'Avisa o líder de que podes pagar a tua parte. Só podes mudar enquanto a equipa não estiver fechada.',
            style: TextStyle(fontSize: 12),
          ),
          value: l.iAmReady,
          onChanged: _busy
              ? null
              : (v) => _run(
                    () => _repo.setReady(l.id, v),
                    success: v ? 'Marcado como preparado.' : 'Deixaste de estar preparado.',
                  ),
        ),
      ],
    );
  }

  Widget _closeBlockedBox(TeamLobby l) {
    return _Box(
      title: 'Fechar equipa e reservar vaga',
      children: [
        Text(l.closeBlockedMessage!, style: const TextStyle(color: Colors.amber, fontSize: 13)),
        const SizedBox(height: 6),
        const Text(
          'Quando houver o mínimo de jogadores e todos estiverem preparados, podes fechar a equipa.',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }

  /// Escolha do modo de pagamento (sem RadioListTile, que está deprecado nas versões novas do Flutter).
  Widget _modeTile({required String value, required String title, required String subtitle}) {
    final selected = _mode == value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? GhColors.success : Colors.white54),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onTap: _busy ? null : () => setState(() => _mode = value),
    );
  }

  Widget _closeBox(TeamLobby l) {
    final p = l.payment;
    final split = _mode == 'split';
    return _Box(
      title: 'Fechar equipa e reservar vaga',
      children: [
        const Text(
          'Todos estão preparados. Ao fechar, ninguém entra nem sai e é reservada uma vaga para pagarem.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        _modeTile(
          value: 'split',
          title: 'Pagamento dividido: ${_eur(p.shareCents)} cada',
          subtitle: 'O preço (${_eur(p.feeCents)}) é dividido pelos ${l.membersCount} jogadores.',
        ),
        _modeTile(
          value: 'total',
          title: 'Pagamento total: pagas ${_eur(p.feeCents)}',
          subtitle: 'Pagas tu por toda a equipa.',
        ),
        if (split && p.roundedUp)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Text(
              'Atenção: ${_eur(p.feeCents)} não se divide certo por ${l.membersCount} jogadores. '
              'O valor é arredondado para cima e a equipa paga ${_eur(p.collectedCents)} no total '
              '(+${_eur(p.extraCents)}).',
              style: const TextStyle(color: Colors.amber, fontSize: 12, height: 1.4),
            ),
          ),
        const SizedBox(height: 8),
        GhButton(
          label: 'Fechar equipa',
          loading: _busy,
          onPressed: _busy ? null : () => _closeTeam(l),
        ),
      ],
    );
  }

  Widget _paymentBox(TeamLobby l) {
    final p = l.payment;
    final String line;
    if (p.isTotal) {
      line = l.isHost
          ? 'Pagas ${_eur(p.shareCents)} por toda a equipa.'
          : 'O líder paga ${_eur(p.shareCents)} por toda a equipa. Não tens nada a pagar.';
    } else {
      line = 'A tua parte: ${_eur(p.shareCents)}.';
    }
    return _Box(
      title: 'Pagamento (simulado)',
      children: [
        Text(line, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          p.isTotal
              ? (p.iPaid ? 'Pago.' : 'Por pagar.')
              : 'Pagaram ${p.paidCount} de ${l.membersCount} jogadores.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ainda não é cobrado nenhum valor. Mais tarde o saldo fica reservado na tua conta e só é '
          'debitado quando todos tiverem pago; se a vaga não for confirmada, é libertado sem custos.',
          style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 10),
        if (p.canPay)
          GhButton(
            label: 'Pagar ${_eur(p.shareCents)} (simulado)',
            loading: _busy,
            onPressed: _busy ? null : () => _run(() => _repo.pay(l.id), success: 'Pagamento registado.'),
          )
        else if (p.iPaid)
          const GhBanner.success('Já pagaste. À espera dos restantes.')
        else if (p.cannotPayReason == 'reservation_expired')
          GhBanner.error('O tempo para pagar terminou.'),
      ],
    );
  }

  List<Widget> _hostWithdrawActions(TeamLobby l) {
    return [
      const SizedBox(height: 4),
      if (l.isClosed) ...[
        GhButton(label: 'Ver regras do torneio', secondary: true, onPressed: () => _showRules(l.rules)),
        const SizedBox(height: 8),
      ],
      if (l.canReopen) ...[
        GhButton(
          label: 'Reabrir equipa',
          secondary: true,
          onPressed: _busy ? null : () => _reopenTeam(l),
        ),
        const SizedBox(height: 8),
      ],
      if (l.canDisband)
        GhButton(
          label: 'Eliminar equipa',
          danger: true,
          onPressed: _busy ? null : () => _disbandTeam(l),
        ),
      const SizedBox(height: 8),
    ];
  }

  Widget _memberRow(TeamLobby l, TeamMember m) {
    final canManage = l.isHost && !m.isMe && l.registrationOpen && !l.confirmed;
    // Em formação mostra-se quem está preparado; depois de fechada, quem já pagou.
    final penalized = m.penalized == true;
    final showReady = !penalized && l.isMember && l.isForming && m.ready != null;
    final showPaid = !penalized && l.isMember && l.isClosed && m.paid != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          m.position == null ? const _PositionChip('?') : _PositionChip(m.position!),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: m.isMe ? '${m.displayName} (tu)' : m.displayName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    children: [
                      if (m.username.isNotEmpty)
                        TextSpan(
                          text: '  @${m.username}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white60),
                        ),
                    ],
                  ),
                ),
                Text(
                  m.position == null ? 'Sem posição' : TeamLabels.position(m.position!),
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          // Penalizado por não ter pago a tempo: bolinha vermelha em vez do sinal de preparado/ampulheta.
          if (penalized)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Tooltip(
                message: 'Penalizado: não pagou a tempo',
                child: Icon(Icons.circle, size: 14, color: GhColors.error),
              ),
            ),
          if (showReady)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: m.ready! ? 'Preparado' : 'Ainda não preparado',
                child: Icon(
                  m.ready! ? Icons.check_circle : Icons.hourglass_empty,
                  size: 18,
                  color: m.ready! ? GhColors.success : Colors.white38,
                ),
              ),
            ),
          if (showPaid)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: m.paid! ? 'Pago' : 'Por pagar',
                child: Icon(
                  m.paid! ? Icons.check_circle : Icons.schedule,
                  size: 18,
                  color: m.paid! ? GhColors.success : Colors.white38,
                ),
              ),
            ),
          if (m.isHost)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Chip(
                label: Text('Líder', style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (canManage)
            PopupMenuButton<String>(
              tooltip: 'Ações',
              enabled: !_busy,
              onSelected: (v) => v == 'transfer' ? _transfer(l, m) : _remove(l, m),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'transfer', child: Text('Passar a liderança')),
                if (l.isForming) const PopupMenuItem(value: 'remove', child: Text('Remover da equipa')),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _hostSections(TeamLobby l) {
    return [
      _Box(
        title: 'Pedidos para entrar (${l.requests.length})',
        children: [
          if (l.requests.isEmpty)
            const Text('Não há pedidos pendentes.', style: TextStyle(color: Colors.white70)),
          for (final r in l.requests)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text(r.label)),
                  IconButton(
                    tooltip: 'Recusar',
                    icon: const Icon(Icons.close, color: GhColors.error),
                    onPressed: _busy ? null : () => _run(() => _repo.rejectRequest(r.id)),
                  ),
                  IconButton(
                    tooltip: 'Aceitar',
                    icon: const Icon(Icons.check, color: GhColors.success),
                    onPressed: _busy ? null : () => _run(() => _repo.acceptRequest(r.id)),
                  ),
                ],
              ),
            ),
        ],
      ),
      if (l.canInvite) _inviteBox(l),
    ];
  }

  Widget _inviteBox(TeamLobby l) {
    return _Box(
      title: 'Convidar jogador',
      children: [
        GhTextField(
          controller: _inviteEmail,
          label: 'Email ou username#tag',
          helperText: 'Ex.: hugo#482 ou nome@email.pt',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _sendInvite(l),
        ),
        GhButton(
          label: 'Enviar convite',
          secondary: true,
          onPressed: _busy ? null : () => _sendInvite(l),
        ),
        if (_inviteError != null || _inviteInfo != null) const SizedBox(height: 14),
        if (_inviteError != null) GhBanner.error(_inviteError!),
        if (_inviteInfo != null) GhBanner.success(_inviteInfo!),
        if (l.invites.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Convites pendentes', style: TextStyle(color: Colors.white60, fontSize: 12)),
          for (final i in l.invites)
            Row(
              children: [
                Expanded(child: Text(i.label)),
                TextButton(
                  onPressed: _busy ? null : () => _run(() => _repo.cancelInvite(i.id)),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
        ],
      ],
    );
  }

  Widget _settingsBox(TeamLobby l) {
    return _Box(
      title: 'Definições do lobby',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Equipa privada'),
          subtitle: const Text(
            'Ninguém de fora pode pedir para entrar: só entra quem for convidado.',
            style: TextStyle(fontSize: 12),
          ),
          value: l.isPrivate,
          onChanged: _busy
              ? null
              : (v) => _run(
                    () => _repo.updateSettings(l.id, isPrivate: v),
                    success: v
                        ? 'Equipa privada: deixa de aceitar pedidos de entrada.'
                        : 'Equipa aberta: voltam a ser aceites pedidos de entrada.',
                  ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Os membros também podem convidar'),
          subtitle: const Text(
            'Se estiver desligado, só tu podes enviar convites.',
            style: TextStyle(fontSize: 12),
          ),
          value: l.membersCanInvite,
          onChanged: _busy
              ? null
              : (v) => _run(
                    () => _repo.updateSettings(l.id, membersCanInvite: v),
                    success: v
                        ? 'Agora os membros também podem convidar.'
                        : 'Agora só tu podes convidar.',
                  ),
        ),
        const Text(
          'Podes mudar isto em qualquer momento. Pedidos que já estão pendentes mantêm-se para decidires.',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }

  /// Código GH-XXXX: o líder liga/desliga, escolhe entrada direta e se os membros o veem; os membros só o copiam.
  Widget _codeBox(TeamLobby l, TeamCode c) {
    final code = c.code;
    return _Box(
      title: 'Código da equipa',
      children: [
        if (l.isHost)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ativar código'),
            subtitle: const Text(
              'Quem tiver o código pode entrar na equipa sem o líder convidar cada pessoa.',
              style: TextStyle(fontSize: 12),
            ),
            value: c.enabled,
            onChanged: _busy
                ? null
                : (v) => _run(
                      () => _repo.updateSettings(l.id, inviteCodeEnabled: v),
                      success: v ? 'Código ativado.' : 'Código desativado: deixou de funcionar.',
                    ),
          ),
        if (c.enabled && code != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  code,
                  key: const Key('invite-code'),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 2),
                ),
              ),
              IconButton(
                tooltip: 'Copiar código',
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (mounted) {
                    setState(() => _info = 'Código copiado.');
                  }
                },
              ),
            ],
          ),
          Text(
            c.directEntry
                ? 'Quem usar o código entra logo na equipa.'
                : 'Quem usar o código envia um pedido: o líder decide.',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
        if (l.isHost && c.enabled) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Entrada direta'),
            subtitle: const Text(
              'Ligado: o código dá entrada imediata. Desligado: o código só envia um pedido.',
              style: TextStyle(fontSize: 12),
            ),
            value: c.directEntry,
            onChanged: _busy
                ? null
                : (v) => _run(() => _repo.updateSettings(l.id, codeDirectEntry: v),
                    success: v ? 'O código dá entrada direta.' : 'O código passa a enviar pedidos.'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Os membros veem o código'),
            subtitle: const Text('Por defeito só tu vês o código.', style: TextStyle(fontSize: 12)),
            value: c.membersSeeCode,
            onChanged: _busy
                ? null
                : (v) => _run(() => _repo.updateSettings(l.id, membersSeeCode: v),
                    success: v ? 'Os membros já veem o código.' : 'Só tu vês o código.'),
          ),
          const SizedBox(height: 4),
          GhButton(
            label: 'Gerar código novo (${c.regensLeft} esta hora)',
            secondary: true,
            onPressed: _busy || c.regensLeft == 0
                ? null
                : () async {
                    final ok = await _confirm(
                      'Gerar código novo?',
                      'O código atual deixa de funcionar. Podes gerar no máximo 3 por hora.',
                      'Gerar',
                    );
                    if (ok) {
                      await _run(() => _repo.regenerateCode(l.id), success: 'Código novo gerado.');
                    }
                  },
          ),
        ],
      ],
    );
  }

  List<Widget> _visitorActions(TeamLobby l) {
    if (l.pendingInviteId != null) {
      return [
        const GhBanner.success('Recebeste um convite desta equipa.'),
        GhButton(
          label: 'Aceitar convite',
          onPressed: _busy ? null : () => _run(() => _repo.acceptInvite(l.pendingInviteId!)),
        ),
        const SizedBox(height: 8),
        GhButton(
          label: 'Recusar convite',
          secondary: true,
          onPressed: _busy ? null : () => _run(() => _repo.declineInvite(l.pendingInviteId!)),
        ),
      ];
    }
    if (l.pendingRequestId != null) {
      return [
        const GhBanner.success('O teu pedido está a aguardar resposta do líder.'),
        GhButton(
          label: 'Cancelar pedido',
          secondary: true,
          onPressed: _busy ? null : () => _run(() => _repo.cancelRequest(l.pendingRequestId!)),
        ),
      ];
    }
    if (l.canRequestToJoin) {
      return [
        GhButton(
          label: 'Pedir para entrar',
          loading: _busy,
          onPressed: () => _run(() => _repo.requestJoin(l.id),
              success: 'Pedido enviado. O líder vai decidir.'),
        ),
      ];
    }
    return [GhBanner.error(TeamLabels.joinBlocked(l.joinBlockedReason))];
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GhColors.fieldFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GhColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _PositionChip extends StatelessWidget {
  const _PositionChip(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: code == '?' ? GhColors.secondary : GhColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}

/// Caixa de aviso com título colorido (estado da equipa).
class _Callout extends StatelessWidget {
  const _Callout({required this.color, required this.title, required this.children});

  final Color color;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

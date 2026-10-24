import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../core/error_messages.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../widgets/gh_widgets.dart';
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

  // Resultado do último convite: aparece dentro da caixa "Convidar jogador" (vermelho = erro, verde = enviado).
  String? _inviteError;
  String? _inviteInfo;

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
        _inviteInfo =
            'Se esse email tiver conta no GameHall, a pessoa recebe o convite. Por privacidade não dizemos se existe.';
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
      if (l.closedToRequests && !l.confirmed) ...[
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            avatar: Icon(Icons.lock_outline, size: 16),
            label: Text('Lobby fechado: só por convite', style: TextStyle(fontSize: 12)),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
      const SizedBox(height: 16),
      _ConfirmationBox(lobby: l),
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
      if (l.isMember) ...[
        GhButton(
          label: l.me?.position == null ? 'Escolher a minha posição' : 'Mudar a minha posição',
          secondary: true,
          onPressed: _busy ? null : () => _pickPosition(l),
        ),
        const SizedBox(height: 12),
      ],
      if (l.isHost) _settingsBox(l),
      if (l.isHost && !l.confirmed) ..._hostSections(l),
      if (l.canInvite && !l.isHost) _inviteBox(l),
      if (!l.isMember) ..._visitorActions(l),
      if (l.isMember && l.registrationOpen && !l.confirmed) ...[
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
    ];
  }

  Widget _memberRow(TeamLobby l, TeamMember m) {
    final canManage = l.isHost && !m.isMe && l.registrationOpen && !l.confirmed;
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
          if (l.isMember && m.paid != null)
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
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'transfer', child: Text('Passar a liderança')),
                PopupMenuItem(value: 'remove', child: Text('Remover da equipa')),
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
          title: const Text('Lobby fechado'),
          subtitle: const Text(
            'Ninguém de fora pode pedir para entrar: só entra quem for convidado.',
            style: TextStyle(fontSize: 12),
          ),
          value: l.closedToRequests,
          onChanged: _busy
              ? null
              : (v) => _run(
                    () => _repo.updateSettings(l.id, closedToRequests: v),
                    success: v
                        ? 'Lobby fechado: deixa de aceitar pedidos de entrada.'
                        : 'Lobby aberto: voltam a ser aceites pedidos de entrada.',
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

/// Estado da equipa: confirmada (fechada) ou ainda por confirmar, com o que falta.
class _ConfirmationBox extends StatelessWidget {
  const _ConfirmationBox({required this.lobby});

  final TeamLobby lobby;

  @override
  Widget build(BuildContext context) {
    final l = lobby;
    if (l.confirmed) {
      return const GhBanner.success(
        'Equipa confirmada: está completa e todos os jogadores pagaram. A equipa está fechada.',
      );
    }
    if (!l.registrationOpen) {
      return const SizedBox.shrink();
    }

    final missing = <String>[];
    if (l.belowMinimum) {
      final n = l.minPlayers - l.membersCount;
      missing.add(n == 1 ? '1 jogador' : '$n jogadores');
    }
    if (l.isMember && l.unpaidCount > 0) {
      final n = l.unpaidCount;
      missing.add(n == 1 ? '1 pagamento' : '$n pagamentos');
    }
    final slots = l.maxTeams > 0 ? ' (confirmadas: ${l.teamsConfirmed}/${l.maxTeams})' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ainda não confirmada',
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'A equipa fica confirmada quando tiver pelo menos ${l.minPlayers} jogadores e todos tiverem pago. '
            'Só as primeiras ${l.maxTeams > 0 ? l.maxTeams : 'N'} equipas confirmadas ficam no torneio$slots; '
            'as restantes são eliminadas quando as vagas esgotarem.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          if (l.isMember && missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Falta: ${missing.join(' e ')}.',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

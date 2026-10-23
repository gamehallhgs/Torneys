import 'package:flutter/material.dart';

import '../core/error_messages.dart';
import 'gh_widgets.dart';

/// Carrega dados uma vez (com puxar-para-atualizar e "tentar novamente") e desenha-os numa lista.
/// O [load] não deve usar o BuildContext: obtém o que precisa (ex.: a API) antes.
class LoadView<T> extends StatefulWidget {
  const LoadView({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final List<Widget> Function(BuildContext context, T data) builder;

  @override
  State<LoadView<T>> createState() => _LoadViewState<T>();
}

class _LoadViewState<T> extends State<LoadView<T>> with AutomaticKeepAliveClientMixin {
  T? _data;
  String? _error;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await widget.load();
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[GameHall] carregamento falhou: $e\n$st');
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final data = _data;
    final List<Widget> children;
    if (_loading && data == null) {
      children = const [
        Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ];
    } else if (data == null) {
      children = [
        GhBanner.error(_error ?? 'Ocorreu um erro inesperado.'),
        GhButton(label: 'Tentar novamente', onPressed: _fetch),
      ];
    } else {
      children = [
        if (_error != null) GhBanner.error(_error!),
        ...widget.builder(context, data),
      ];
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: children,
      ),
    );
  }
}

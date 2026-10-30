import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/gh_widgets.dart';

class GuideStep {
  const GuideStep(this.icon, this.title, this.text);

  final IconData icon;
  final String title;
  final String text;
}

/// Os 5 ecrãs do mini-guia de boas-vindas.
const guideSteps = <GuideStep>[
  GuideStep(
    Icons.emoji_events_outlined,
    'Encontra torneios',
    'Na lista vês os torneios com inscrições abertas. Filtra por modalidade, datas e local, '
        'e abre um torneio para ver regras, valor de inscrição e equipas.',
  ),
  GuideStep(
    Icons.groups_outlined,
    'Cria ou entra numa equipa',
    'Cria a tua equipa e convida amigos pelo @username, ou entra numa equipa com um pedido, um convite '
        'ou um código GH-XXXX que o líder te dê.',
  ),
  GuideStep(
    Icons.timer_outlined,
    'Fecha e paga a tempo',
    'Quando a equipa está pronta, o líder fecha-a. Com vaga, tens 30 minutos para pagar; '
        'se não pagares a tempo ficas 15 minutos penalizado. Não há reembolsos.',
  ),
  GuideStep(
    Icons.sports_soccer_outlined,
    'Prepara o plantel',
    'Escolhe a tua posição e, se fores o líder, define a formação e os titulares. '
        'Se não definires, os resultados mostram a lista de membros por posição.',
  ),
  GuideStep(
    Icons.notifications_none,
    'Fica a par',
    'O sino mostra convites, pedidos, prazos de pagamento e avisos da tua equipa. '
        'Podes apagar notificações uma a uma ou limpar tudo.',
  ),
];

/// Mini-guia: aparece uma vez depois do primeiro login e pode ser revisto em Perfil → "Ver guia".
class WelcomeGuideScreen extends StatefulWidget {
  const WelcomeGuideScreen({super.key});

  @override
  State<WelcomeGuideScreen> createState() => _WelcomeGuideScreenState();
}

class _WelcomeGuideScreenState extends State<WelcomeGuideScreen> {
  final _controller = PageController();
  var _page = 0;

  bool get _last => _page == guideSteps.length - 1;

  void _close() => Navigator.of(context).pop();

  void _next() {
    if (_last) {
      _close();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GhBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _close,
                  child: Text(_last ? '' : 'Saltar'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: guideSteps.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) {
                    final s = guideSteps[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(s.icon, size: 96, color: GhColors.success),
                          const SizedBox(height: 32),
                          Text(
                            s.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            s.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 15),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < guideSteps.length; i++)
                    Container(
                      margin: const EdgeInsets.all(4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page ? GhColors.success : Colors.white24,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: SizedBox(
                    width: double.infinity,
                    child: GhButton(label: _last ? 'Começar' : 'Seguinte', onPressed: _next),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

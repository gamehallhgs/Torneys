import 'package:flutter/widgets.dart';

import 'auth_controller.dart';

/// Dá acesso ao [AuthController] em qualquer ecrã: `AuthScope.of(context)`.
class AuthScope extends InheritedWidget {
  const AuthScope({super.key, required this.controller, required super.child});

  final AuthController controller;

  static AuthController of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope não encontrado');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(AuthScope oldWidget) => controller != oldWidget.controller;
}

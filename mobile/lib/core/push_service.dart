/// Fonte do token de push do telemóvel. Por defeito não há nenhuma ([NoPushService]): a app funciona na
/// mesma, só não recebe push. Quando o projeto Firebase estiver pronto, implementa-se esta classe com o
/// `firebase_messaging` (passo a passo em docs/NOTIFICACOES.md) e passa-se ao `AuthController(push: ...)`.
abstract class PushService {
  /// "android", "ios" ou "web".
  String get platform;

  /// Pede permissão (se for preciso) e devolve o token deste telemóvel; null se não houver / for recusado.
  Future<String?> token();

  /// Chamado quando o token muda (o Firebase renova-o de vez em quando).
  void onTokenRefresh(void Function(String token) listener);
}

class NoPushService implements PushService {
  const NoPushService();

  @override
  String get platform => 'android';

  @override
  Future<String?> token() async => null;

  @override
  void onTokenRefresh(void Function(String token) listener) {}
}

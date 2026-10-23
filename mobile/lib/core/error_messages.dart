import 'api_client.dart';

/// Converte os códigos estáveis da API em mensagens em português.
String friendlyError(Object error) {
  if (error is! ApiException) {
    return 'Ocorreu um erro inesperado. Tenta novamente.';
  }
  switch (error.code) {
    case 'network_error':
      return error.message;
    case 'invalid_credentials':
      return 'Email ou palavra-passe incorretos.';
    case 'email_not_verified':
      return 'Ainda não verificaste o teu email.';
    case 'invalid_code':
      return 'Código inválido ou expirado.';
    case 'age_too_young':
      // A mensagem do servidor já distingue "criar conta" de "entrar no torneio".
      return error.message;
    case 'age_too_old':
      return 'Ultrapassas a idade máxima deste torneio.';
    case 'legal_not_accepted':
      return 'Tens de aceitar os Termos e a Política de Privacidade.';
    case 'legal_version_outdated':
      return 'Os documentos legais foram atualizados. Lê-os novamente e confirma.';
    case 'invalid_refresh_token':
      return 'A tua sessão expirou. Inicia sessão novamente.';
    case 'team_not_found':
      return 'Equipa não encontrada.';
    case 'request_not_found':
      return 'Pedido não encontrado.';
    case 'invite_not_found':
      return 'Convite não encontrado.';
    case 'not_team_host':
      return 'Só o líder da equipa pode fazer isto.';
    case 'not_team_member':
      return 'Tens de ser membro da equipa.';
    case 'already_in_team':
      return 'Já estás numa equipa deste torneio.';
    case 'team_full':
      return 'A equipa já está completa.';
    case 'team_not_joinable':
      return 'Esta equipa já não aceita pedidos.';
    case 'registration_closed':
      return 'As inscrições deste torneio não estão abertas.';
    case 'not_pending':
      return 'Este pedido já foi tratado.';
    case 'team_name_taken':
      return 'Já existe uma equipa com esse nome neste torneio.';
    case 'team_color_taken':
      return 'Essa cor já está a ser usada por outra equipa. Escolhe outra.';
    case 'host_must_transfer':
      return 'Passa a liderança a outro jogador antes de sair.';
    case 'too_many_invites':
      return 'Há demasiados convites pendentes. Cancela alguns primeiro.';
    case 'tournament_full':
      return 'O torneio já tem todas as equipas confirmadas.';
    case 'team_confirmed':
      return 'A equipa já está confirmada e fechada: não aceita nem perde jogadores.';
    case 'invalid_position':
      return 'Posição inválida.';
    case 'game_not_found':
      return 'Jogo não encontrado.';
    case 'tournament_not_found':
      return 'Torneio não encontrado.';
    case 'rate_limited':
      return 'Demasiados pedidos. Tenta novamente daqui a pouco.';
    case 'account_locked':
      return 'Conta temporariamente bloqueada por tentativas falhadas. Tenta mais tarde.';
    case 'validation_error':
      return error.fieldErrors.isNotEmpty ? error.fullMessage : error.message;
    default:
      if (error.status >= 500) {
        return 'Erro no servidor. Tenta novamente mais tarde.';
      }
      return error.fullMessage;
  }
}

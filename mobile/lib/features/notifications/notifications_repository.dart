import '../../core/api_client.dart';
import 'notification_models.dart';

/// Chamadas à API da central de notificações.
class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<NotificationList> list() async {
    final res = (await _api.get('/api/v1/notifications', auth: true)).ensureOk();
    return NotificationList.fromJson(res.json);
  }

  Future<int> unreadCount() async {
    final res = (await _api.get('/api/v1/notifications/unread-count', auth: true)).ensureOk();
    return (res.json['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markAllRead() async {
    (await _api.post('/api/v1/notifications/read-all', auth: true)).ensureOk();
  }
}

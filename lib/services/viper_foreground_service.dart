import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startViperServiceCallback() {
  FlutterForegroundTask.setTaskHandler(ViperTaskHandler());
}

class ViperForegroundService {
  ViperForegroundService._();

  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'viper_foreground_service',
        channelName: 'Viper Ride',
        channelDescription: 'Viper Ride está ativo',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> start() async {
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Viper Ride',
      notificationText: 'Viper Ride está ativo',
      callback: startViperServiceCallback,
    );
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }
}

class ViperTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

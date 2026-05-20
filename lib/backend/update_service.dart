import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

enum UpdateCheckStatus {
  updateAvailable,
  started,
  upToDate,
  unsupportedPlatform,
  unavailable,
  failed,
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.status,
    required this.message,
    this.details,
  });

  final UpdateCheckStatus status;
  final String message;
  final String? details;
}

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  AppUpdateInfo? _updateInfo;

  Future<UpdateCheckResult> checkForUpdate() async {
    if (kIsWeb) {
      return const UpdateCheckResult(
        status: UpdateCheckStatus.unsupportedPlatform,
        message: 'Web surumunde otomatik guncelleme denetimi desteklenmiyor.',
      );
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      return const UpdateCheckResult(
        status: UpdateCheckStatus.unsupportedPlatform,
        message:
            'Bu cihazda uygulama ici guncelleme denetimi desteklenmiyor. Lutfen magazadan kontrol edin.',
      );
    }

    try {
      _updateInfo = await InAppUpdate.checkForUpdate();

      if (_updateInfo?.updateAvailability ==
          UpdateAvailability.updateAvailable) {
        return const UpdateCheckResult(
          status: UpdateCheckStatus.updateAvailable,
          message: 'Yeni bir guncelleme mevcut.',
        );
      }
    } catch (e) {
      debugPrint('InAppUpdate Error: $e');
      return UpdateCheckResult(
        status: UpdateCheckStatus.failed,
        message: 'Guncelleme denetimi yapilamadi.',
        details: e.toString(),
      );
    }
    return const UpdateCheckResult(
      status: UpdateCheckStatus.upToDate,
      message: 'Yeni bir guncelleme bulunmadi.',
    );
  }

  Future<UpdateCheckResult> startUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const UpdateCheckResult(
        status: UpdateCheckStatus.unsupportedPlatform,
        message:
            'Bu cihazda uygulama ici guncelleme denetimi desteklenmiyor. Lutfen magazadan kontrol edin.',
      );
    }

    final info = _updateInfo;
    if (info == null ||
        info.updateAvailability != UpdateAvailability.updateAvailable) {
      return const UpdateCheckResult(
        status: UpdateCheckStatus.unavailable,
        message: 'Baslatilabilecek bir guncelleme bulunmadi.',
      );
    }

    try {
      if ((info.updatePriority) >= 4) {
        final started = await performImmediateUpdate();
        if (!started) {
          return const UpdateCheckResult(
            status: UpdateCheckStatus.unavailable,
            message:
                'Guncelleme bulundu ama bu cihazda hemen baslatilamadi. Google Play uzerinden deneyin.',
          );
        }
      } else {
        final started = await performFlexibleUpdate();
        if (!started) {
          return const UpdateCheckResult(
            status: UpdateCheckStatus.unavailable,
            message:
                'Guncelleme bulundu ama indirme baslatilamadi. Google Play uzerinden deneyin.',
          );
        }
      }

      return const UpdateCheckResult(
        status: UpdateCheckStatus.started,
        message: 'Guncelleme islemi baslatildi.',
      );
    } catch (e) {
      debugPrint('Start Update Error: $e');
      return UpdateCheckResult(
        status: UpdateCheckStatus.failed,
        message: 'Guncelleme baslatilamadi.',
        details: e.toString(),
      );
    }
  }

  Future<bool> performImmediateUpdate() async {
    try {
      if (_updateInfo?.immediateUpdateAllowed ?? false) {
        await InAppUpdate.performImmediateUpdate();
        return true;
      }
    } catch (e) {
      debugPrint('Immediate Update Error: $e');
    }
    return false;
  }

  Future<bool> performFlexibleUpdate() async {
    try {
      if (_updateInfo?.flexibleUpdateAllowed ?? false) {
        await InAppUpdate.startFlexibleUpdate();

        // In a real app, you'd listen for the download to complete.
        // The in_app_update package doesn't provide a continuous stream for free,
        // but it does provide the current status in AppUpdateInfo.
        // For this implementation, we'll inform the user (via the OS-level UI provided by Play Store)
        // and then they can finish it.
        // Note: The Play Store handles the download notification.
        // Once downloaded, we call completeFlexibleUpdate to restart.

        // We can show a snackbar or message here if we had access to context,
        // but for now we'll just attempt completion if possible or let the user
        // restart the app themselves which also triggers the install often.

        // Better yet, we can check again after some time.
        Future.delayed(const Duration(minutes: 5), () async {
          final info = await InAppUpdate.checkForUpdate();
          if (info.installStatus == InstallStatus.downloaded) {
            await InAppUpdate.completeFlexibleUpdate();
          }
        });
        return true;
      }
    } catch (e) {
      debugPrint('Flexible Update Error: $e');
    }
    return false;
  }
}

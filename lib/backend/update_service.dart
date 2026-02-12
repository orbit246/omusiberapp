import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  AppUpdateInfo? _updateInfo;

  /// Checks for update availability.
  /// Returns true if an update flow was started, false otherwise.
  Future<bool> checkForUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      // In-App Update API is currently only supported on Android by Google.
      return false;
    }

    try {
      _updateInfo = await InAppUpdate.checkForUpdate();

      if (_updateInfo?.updateAvailability ==
          UpdateAvailability.updateAvailable) {
        // Decide whether to show immediate or flexible update.
        // Priority 4 or 5 is usually considered critical/immediate.
        if ((_updateInfo?.updatePriority ?? 0) >= 4) {
          await performImmediateUpdate();
        } else {
          await performFlexibleUpdate();
        }
        return true;
      }
    } catch (e) {
      debugPrint('InAppUpdate Error: $e');
    }
    return false;
  }

  /// Triggers an immediate update flow.
  /// Shows a full-screen UI and prevents user from using the app until updated.
  Future<void> performImmediateUpdate() async {
    try {
      if (_updateInfo?.immediateUpdateAllowed ?? false) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      debugPrint('Immediate Update Error: $e');
    }
  }

  /// Triggers a flexible update flow.
  /// Downloads the update in the background.
  Future<void> performFlexibleUpdate() async {
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
      }
    } catch (e) {
      debugPrint('Flexible Update Error: $e');
    }
  }
}

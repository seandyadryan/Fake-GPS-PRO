import '../l10n/generated/app_localizations.dart';

/// Stable message codes keep application state independent of the selected language.
enum LocationMessage {
  permissionBlocked,
  permissionRequired,
  stopBeforeLocate,
  locationRequired,
  staleMockLocation,
  locationUnavailable,
  operationBusy,
  invalidCoordinates,
  androidOnly,
  developerRequired,
  mockAppRequired,
  startFailed,
  mockStarted,
  stopFailed,
  mockStopped,
  routeNeedsMock,
  routeNeedsPoints,
  routeUpdateFailed,
  historySaveFailed,
  nativeError,
  notRunning,
  operationTimeout,
  mockPermissionChanged,
  cleanupFailed,
  searchNotFound,
  searchFailed;

  String localize(AppLocalizations l10n) => switch (this) {
    LocationMessage.permissionBlocked => l10n.permissionBlocked,
    LocationMessage.permissionRequired => l10n.permissionRequired,
    LocationMessage.stopBeforeLocate => l10n.stopBeforeLocate,
    LocationMessage.locationRequired => l10n.locationRequired,
    LocationMessage.staleMockLocation => l10n.staleMockLocation,
    LocationMessage.locationUnavailable => l10n.locationUnavailable,
    LocationMessage.operationBusy => l10n.operationBusy,
    LocationMessage.invalidCoordinates => l10n.invalidCoordinates,
    LocationMessage.androidOnly => l10n.androidOnly,
    LocationMessage.developerRequired => l10n.developerRequired,
    LocationMessage.mockAppRequired => l10n.mockAppRequired,
    LocationMessage.startFailed => l10n.startFailed,
    LocationMessage.mockStarted => l10n.mockStarted,
    LocationMessage.stopFailed => l10n.stopFailed,
    LocationMessage.mockStopped => l10n.mockStopped,
    LocationMessage.routeNeedsMock => l10n.routeNeedsMock,
    LocationMessage.routeNeedsPoints => l10n.routeNeedsPoints,
    LocationMessage.routeUpdateFailed => l10n.routeUpdateFailed,
    LocationMessage.historySaveFailed => l10n.historySaveFailed,
    LocationMessage.nativeError => l10n.nativeError,
    LocationMessage.notRunning => l10n.notRunning,
    LocationMessage.operationTimeout => l10n.operationTimeout,
    LocationMessage.mockPermissionChanged => l10n.mockPermissionChanged,
    LocationMessage.cleanupFailed => l10n.cleanupFailed,
    LocationMessage.searchNotFound => l10n.searchNotFound,
    LocationMessage.searchFailed => l10n.searchFailed,
  };

  static LocationMessage fromCode(String? code) {
    for (final message in values) {
      if (message.name == code) return message;
    }
    return switch (code) {
      'INVALID_COORDINATES' => invalidCoordinates,
      'NOT_RUNNING' => notRunning,
      'TIMEOUT' => operationTimeout,
      'START_FAILED' => startFailed,
      'STOP_FAILED' => stopFailed,
      'UPDATE_FAILED' => routeUpdateFailed,
      _ => nativeError,
    };
  }
}

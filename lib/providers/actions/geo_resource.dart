part of '../action.dart';

@Riverpod(keepAlive: true)
class GeoResourceAction extends _$GeoResourceAction {
  @override
  void build() {}

  Future<void> updateGeoResource(GeoResource geoResource) async {
    await coreController.updateGeoData(geoResource.name);
  }

  Future<void> updateGeoResourceUrl(
    GeoResource geoResource,
    String newUrl,
  ) async {
    if (!newUrl.isUrl) {
      throw 'Invalid url';
    }
    ref.read(patchClashConfigProvider.notifier).update((state) {
      return state.copyWith(geoXUrl: {...state.geoXUrl, geoResource: newUrl});
    });
    await ref.read(setupActionProvider.notifier).applyProfile(silence: true);
  }

  @protected
  void showNotifier(String text) {
    globalState.showNotifier(text);
  }

  void handleGeoUpdateStatus(
    String geoType,
    bool updating,
    bool skipped,
    String? error,
  ) {
    final geoResource = GeoResource.fromJson(geoType.toLowerCase());
    if (!ref.read(appSettingProvider).geoSilentUpdate) {
      final l10n = currentAppLocalizations;
      if (updating) {
        showNotifier(l10n.geoUpdating(geoResource.name));
      } else if (skipped) {
        showNotifier(l10n.geoSkipped(geoResource.name));
      } else if (error == null || error.isEmpty) {
        showNotifier(l10n.geoUpdated(geoResource.name));
      }
    }
    ref.read(isUpdatingProvider(geoResource.updatingKey).notifier).value =
        updating;
    if (!updating && error != null && error.isNotEmpty) {
      showNotifier(error);
    }
  }
}

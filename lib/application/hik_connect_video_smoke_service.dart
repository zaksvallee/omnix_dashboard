import 'hik_connect_video_session.dart';

class HikConnectVideoSmokeResult {
  final HikConnectLiveAddressResponse? liveAddress;
  final HikConnectRecordElementSearchResult? playbackCatalog;
  final HikConnectVideoDownloadResult? downloadResult;

  const HikConnectVideoSmokeResult({
    this.liveAddress,
    this.playbackCatalog,
    this.downloadResult,
  });

  bool get hasAnyData =>
      liveAddress != null || playbackCatalog != null || downloadResult != null;
}

class HikConnectVideoSmokeService {
  const HikConnectVideoSmokeService();

  HikConnectVideoSmokeResult evaluate({
    Map<String, Object?>? liveAddressResponse,
    Map<String, Object?>? playbackSearchResponse,
    Map<String, Object?>? videoDownloadResponse,
  }) {
    return HikConnectVideoSmokeResult(
      liveAddress: _hasData(liveAddressResponse)
          ? HikConnectLiveAddressResponse.fromApiResponse(
              liveAddressResponse!,
            )
          : null,
      playbackCatalog: _hasData(playbackSearchResponse)
          ? HikConnectRecordElementSearchResult.fromApiResponse(
              playbackSearchResponse!,
            )
          : null,
      downloadResult: _hasData(videoDownloadResponse)
          ? HikConnectVideoDownloadResult.fromApiResponse(
              videoDownloadResponse!,
            )
          : null,
    );
  }

  bool _hasData(Map<String, Object?>? value) =>
      value != null && value.isNotEmpty;
}

import 'dart:async';
import 'dart:typed_data';

import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/device/xiaomi/components/mass_system.dart';
import 'package:zerobox/src/device/xiaomi/system/xiaomi_system.dart';
import 'package:zerobox/src/protocols/common/device_protocol.dart';
import 'package:zerobox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_common.pbenum.dart'
    as pb_common;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_media.pb.dart'
    as pb_media;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_media.pbenum.dart'
    as pb_media_enum;
import 'package:zerobox/src/protocols/xiaomi/packet/l2_packet.dart';
import 'package:zerobox/src/protocols/xiaomi/packet/mass_packet.dart';

class MediaUploadResult {
  MediaUploadResult({required this.song, required this.duplicated});
  final pb_media.Song song;
  final bool duplicated;
}

class MediaFileDescriptor {
  MediaFileDescriptor({
    this.identifier,
    required this.name,
    this.size,
    this.durationSecs,
    this.createdAtMs,
    this.mediaType,
  });

  final pb_media.MediaFile_Identifier? identifier;
  final String name;
  final int? size;
  final int? durationSecs;
  final int? createdAtMs;
  final pb_media_enum.MediaFile_Type? mediaType;

  String get stableKey =>
      identifier?.id.isNotEmpty == true ? identifier!.id : name;
}

class MediaUploadProgress {
  MediaUploadProgress({required this.bytesSent, required this.bytesTotal});
  final int bytesSent;
  final int bytesTotal;
}

class XiaomiMediaSystem extends XiaomiSystem {
  static final _log = getLogger('XiaomiMediaSystem');

  final _songSummaryWaiters = <Completer<pb_media.SongSummary>>[];
  final _mediaFileSummaryWaiters = <Completer<pb_media.MediaFile_Summary>>[];
  final _mediaFileListWaiters = <Completer<List<MediaFileDescriptor>>>[];
  final _songPageWaiters = <Completer<pb_media.Song_GetResponse>>[];
  final _songlistWaiters = <Completer<pb_media.Songlist_Response>>[];
  final _songRemoveWaiters = <Completer<pb_media.Song_RemoveResponse>>[];
  final _songAddWaiters = <Completer<pb_media.Song_AddResponse>>[];
  final _songReportWaiters = <Completer<pb_media.Song_ReportResult>>[];

  XiaomiMassSystem get _massSystem => entity.system<XiaomiMassSystem>()!;

  Future<pb_media.SongSummary> requestSongSummary() async {
    _log.info('[${entity.id}] request song summary');
    final completer = Completer<pb_media.SongSummary>();
    _songSummaryWaiters.add(completer);
    await component.sendPbPacket(
      _buildMediaPacket(pb_media_enum.Media_MediaID.GET_SONG_SUMMARY),
    );
    return completer.future.timeout(const Duration(seconds: 10));
  }

  Future<pb_media.MediaFile_Summary> requestMediaFileSummary() async {
    _log.info('[${entity.id}] request media file summary');
    final completer = Completer<pb_media.MediaFile_Summary>();
    _mediaFileSummaryWaiters.add(completer);
    await component.sendPbPacket(
      _buildMediaPacket(pb_media_enum.Media_MediaID.GET_MEDIA_FILE_SUMMARY),
    );
    return completer.future.timeout(const Duration(seconds: 10));
  }

  Future<List<MediaFileDescriptor>> requestMediaFileList() async {
    _log.info('[${entity.id}] request media file list');
    final completer = Completer<List<MediaFileDescriptor>>();
    _mediaFileListWaiters.add(completer);
    await component.sendPbPacket(
      _buildMediaPacket(pb_media_enum.Media_MediaID.SYNC_MEDIA_FILE_LIST),
    );
    return completer.future.timeout(const Duration(seconds: 30));
  }

  Future<List<MediaFileDescriptor>> requestMediaFileListCompat() async {
    _log.info('[${entity.id}] request media file list compat');
    final completer = Completer<List<MediaFileDescriptor>>();
    _mediaFileListWaiters.add(completer);
    await component.sendPbPacket(
      _buildMediaPacket(
        pb_media_enum.Media_MediaID.SYNC_MEDIA_FILE_LIST,
        mediaFileList: pb_media.MediaFile_List(),
      ),
    );
    return completer.future.timeout(const Duration(seconds: 30));
  }

  Future<void> requestMediaFile(
    pb_media.MediaFile_Identifier identifier,
  ) async {
    await component.sendPbPacket(
      _buildMediaPacket(
        pb_media_enum.Media_MediaID.REQUEST_MEDIA_FILE,
        mediaFileIdentifier: identifier,
      ),
    );
  }

  Future<void> requestMediaFiles(
    List<pb_media.MediaFile_Identifier> identifiers,
  ) async {
    await component.sendPbPacket(
      _buildMediaPacket(
        pb_media_enum.Media_MediaID.REQUEST_MEDIA_FILE_LIST,
        mediaFileIdentifiers: pb_media.MediaFile_Identifier_List(
          list: identifiers,
        ),
      ),
    );
  }

  Future<void> confirmMediaFile(
    pb_media.MediaFile_Identifier identifier,
  ) async {
    await component.sendPbPacket(
      _buildMediaPacket(
        pb_media_enum.Media_MediaID.CONFIRM_MEDIA_FILE,
        mediaFileIdentifier: identifier,
      ),
    );
  }

  Future<pb_media.Song_GetResponse> requestSongPage(int index) async {
    _log.info('[${entity.id}] request song page $index');
    final completer = Completer<pb_media.Song_GetResponse>();
    _songPageWaiters.add(completer);
    await component.sendPbPacket(
      _buildMediaPacket(
        pb_media_enum.Media_MediaID.GET_SONG,
        songGetRequest: pb_media.Song_GetRequest(index: index),
      ),
    );
    return completer.future.timeout(const Duration(seconds: 10));
  }

  Future<pb_media.Songlist_Response> requestSonglistOperation(
    pb_media.Songlist_Request request,
    pb_media_enum.Media_MediaID mediaId,
  ) async {
    _log.info('[${entity.id}] request songlist operation $mediaId');
    final completer = Completer<pb_media.Songlist_Response>();
    _songlistWaiters.add(completer);
    await component.sendPbPacket(
      _buildMediaPacket(mediaId, songlistRequest: request),
    );
    return completer.future.timeout(const Duration(seconds: 10));
  }

  Future<pb_media.Song_RemoveResponse> requestRemoveSong(
    Uint8List songId,
  ) async {
    _log.info('[${entity.id}] request remove song');
    final completer = Completer<pb_media.Song_RemoveResponse>();
    _songRemoveWaiters.add(completer);
    await component.sendPbPacket(
      _buildMediaPacket(
        pb_media_enum.Media_MediaID.REMOVE_SONG,
        songRemoveRequest: pb_media.Song_RemoveRequest(id: songId),
      ),
    );
    return completer.future.timeout(const Duration(seconds: 10));
  }

  Future<MediaUploadResult> uploadSongWithProgress(
    pb_media.Song song,
    Uint8List fileData, {
    void Function(MediaUploadProgress)? onProgress,
  }) async {
    _log.info(
      '[${entity.id}] upload song ${song.id}, ${fileData.length} bytes',
    );

    final addRx = _prepareSingleWaiter(_songAddWaiters, 'song add request');
    await component.sendPbPacket(
      _buildMediaPacket(
        pb_media_enum.Media_MediaID.ADD_SONG,
        songAddRequest: pb_media.Song_AddRequest(song: song),
      ),
    );

    final addResp = await addRx.timeout(const Duration(seconds: 15));

    final status = addResp.prepareStatus;
    switch (status) {
      case pb_common.PrepareStatus.READY:
        break;
      case pb_common.PrepareStatus.DUPLICATED:
        return MediaUploadResult(song: song, duplicated: true);
      case pb_common.PrepareStatus.LOW_STORAGE:
        throw ProtocolException('device reported low storage');
      default:
        throw ProtocolException('music upload prepare failed: $status');
    }

    final reportRx = _prepareSingleWaiter(
      _songReportWaiters,
      'song report wait',
    );
    final expectedSliceLength = addResp.hasExpectedSliceLength()
        ? addResp.expectedSliceLength
        : 0;

    if (expectedSliceLength == 0) {
      _log.warning(
        '[${entity.id}] music upload add response returned slice length 0, falling back to MASS prepare',
      );
      await _massSystem.sendFile(
        fileData: fileData,
        dataType: MassDataType.music,
      );
    } else {
      await _massSystem.sendFile(
        fileData: fileData,
        dataType: MassDataType.music,
        expectedSliceLength: expectedSliceLength,
        onProgress: (data) => onProgress?.call(
          MediaUploadProgress(
            bytesSent: (data.progress * fileData.length).toInt(),
            bytesTotal: fileData.length,
          ),
        ),
      );
    }

    final report = await reportRx.timeout(const Duration(seconds: 90));
    if (report.code != pb_media_enum.Song_ReportResult_Code.SUCCESS) {
      throw ProtocolException('music upload failed: ${report.code}');
    }
    if (report.id.isNotEmpty && report.id != song.id) {
      throw ProtocolException('music upload result id does not match');
    }

    return MediaUploadResult(song: song, duplicated: false);
  }

  @override
  void onLayer2Packet(L2Channel channel, L2OpCode opcode, Uint8List payload) {
    if (channel != L2Channel.pb) return;

    final packetId = _extractVarintField(payload, 2);
    if (packetId == pb_media_enum.Media_MediaID.REPORT_MEDIA_FILE_LIST.value) {
      final mediaBytes = _extractLengthDelimitedField(payload, 20);
      if (mediaBytes != null) {
        final listPayload = _extractLengthDelimitedField(mediaBytes, 14);
        if (listPayload != null) {
          _handleMediaFileListPayload(listPayload);
          return;
        }
      }
      _log.warning(
        '[${entity.id}] media file list report did not contain payload',
      );
      return;
    }

    pb.WearPacket packet;
    try {
      packet = pb.WearPacket.fromBuffer(payload);
    } catch (e) {
      _log.warning('[${entity.id}] failed to decode media PB payload', e);
      return;
    }
    _handlePbPacket(packet);
  }

  void _handlePbPacket(pb.WearPacket packet) {
    if (packet.whichPayload() != pb.WearPacket_Payload.media) return;
    final media = packet.media;

    switch (media.whichPayload()) {
      case pb_media.Media_Payload.songSummary:
        _fulfillAll(_songSummaryWaiters, media.songSummary);
      case pb_media.Media_Payload.mediaFileSummary:
        _fulfillAll(_mediaFileSummaryWaiters, media.mediaFileSummary);
      case pb_media.Media_Payload.songGetResponse:
        _fulfillSingle(_songPageWaiters, media.songGetResponse);
      case pb_media.Media_Payload.songlistResponse:
        _fulfillSingle(_songlistWaiters, media.songlistResponse);
      case pb_media.Media_Payload.songAddResponse:
        _fulfillSingle(_songAddWaiters, media.songAddResponse);
      case pb_media.Media_Payload.songRemoveResponse:
        _fulfillSingle(_songRemoveWaiters, media.songRemoveResponse);
      case pb_media.Media_Payload.songReportResult:
        _fulfillSingle(_songReportWaiters, media.songReportResult);
      default:
        break;
    }
  }

  void _handleMediaFileListPayload(Uint8List payload) {
    try {
      final list = _decodeMediaFileList(payload);
      _fulfillAll(_mediaFileListWaiters, list);
    } catch (e, st) {
      _log.warning('[${entity.id}] failed to decode media file list', e, st);
      _failAll(_mediaFileListWaiters, e);
    }
  }

  Future<T> _prepareSingleWaiter<T>(List<Completer<T>> slot, String context) {
    if (slot.isNotEmpty) {
      throw StateError('$context already in progress');
    }
    final completer = Completer<T>();
    slot.add(completer);
    return completer.future;
  }

  void _fulfillAll<T>(List<Completer<T>> waiters, T value) {
    for (final completer in waiters) {
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    }
    waiters.clear();
  }

  void _failAll<T>(List<Completer<T>> waiters, Object error) {
    for (final completer in waiters) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    waiters.clear();
  }

  void _fulfillSingle<T>(List<Completer<T>> slot, T value) {
    if (slot.isEmpty) return;
    final completer = slot.removeAt(0);
    if (!completer.isCompleted) {
      completer.complete(value);
    }
  }
}

pb.WearPacket _buildMediaPacket(
  pb_media_enum.Media_MediaID id, {
  pb_media.MediaFile_List? mediaFileList,
  pb_media.MediaFile_Identifier? mediaFileIdentifier,
  pb_media.MediaFile_Identifier_List? mediaFileIdentifiers,
  pb_media.Song_GetRequest? songGetRequest,
  pb_media.Songlist_Request? songlistRequest,
  pb_media.Song_AddRequest? songAddRequest,
  pb_media.Song_RemoveRequest? songRemoveRequest,
}) {
  return pb.WearPacket(
    type: pb.WearPacket_Type.MEDIA,
    id: id.value,
    media: pb_media.Media(
      mediaFileList: mediaFileList,
      mediaFileIdentifier: mediaFileIdentifier,
      mediaFileIdentifiers: mediaFileIdentifiers,
      songGetRequest: songGetRequest,
      songlistRequest: songlistRequest,
      songAddRequest: songAddRequest,
      songRemoveRequest: songRemoveRequest,
    ),
  );
}

List<MediaFileDescriptor> _decodeMediaFileList(Uint8List payload) {
  final fields = _extractRepeatedLengthDelimitedFields(payload, 1);
  return fields.map(_decodeMediaFileDescriptor).toList();
}

MediaFileDescriptor _decodeMediaFileDescriptor(Uint8List raw) {
  final stringFields = <(int, String)>[];
  final varintFields = <(int, int)>[];
  pb_media.MediaFile_Identifier? identifier;
  pb_media_enum.MediaFile_Type? mediaType;
  int? size;
  int? createdAtMs;
  int? durationSecs;

  var buf = raw;
  while (buf.isNotEmpty) {
    final key = _decodeProtobufKey(buf);
    if (key == null) break;
    final (tag, wireType, consumed) = key;
    buf = Uint8List.sublistView(buf, consumed);

    switch (wireType) {
      case 0: // Varint
        final value = _decodeProtobufVarint(buf);
        if (value == null) break;
        buf = Uint8List.sublistView(buf, value.$2);
        final v = value.$1;
        varintFields.add((tag, v));
        if (tag == 2 && v <= 0x7FFFFFFF) {
          mediaType = pb_media_enum.MediaFile_Type.valueOf(v);
        }
        if (tag == 3) size = v;
        if (tag == 4) createdAtMs = _normalizeTimestamp(v);
        if (tag == 5) durationSecs = _normalizeDuration(v);
      case 2: // Length-delimited
        final len = _decodeProtobufVarint(buf);
        if (len == null) break;
        buf = Uint8List.sublistView(buf, len.$2);
        final fieldLen = len.$1;
        if (buf.length < fieldLen) break;
        final field = Uint8List.sublistView(buf, 0, fieldLen);
        buf = Uint8List.sublistView(buf, fieldLen);
        if (tag == 1 && identifier == null) {
          try {
            final candidate = pb_media.MediaFile_Identifier.fromBuffer(field);
            if (candidate.id.isNotEmpty) identifier = candidate;
          } catch (_) {}
        }
        final text = String.fromCharCodes(field);
        final trimmed = text.trim();
        if (trimmed.isNotEmpty) {
          stringFields.add((tag, trimmed));
        }
      default:
        // Skip unknown wire types conservatively
        break;
    }
  }

  final identifierId = identifier?.id;
  final name = _inferMediaFileName(stringFields, identifierId);
  mediaType ??= _inferMediaFileType(varintFields);
  createdAtMs ??= _inferTimestamp(varintFields);
  size ??= _inferSize(varintFields, createdAtMs);
  durationSecs ??= _inferDuration(varintFields, createdAtMs, size);

  return MediaFileDescriptor(
    identifier: identifier,
    name: name,
    size: size,
    durationSecs: durationSecs,
    createdAtMs: createdAtMs,
    mediaType: mediaType,
  );
}

String _inferMediaFileName(List<(int, String)> fields, String? identifierId) {
  final id = identifierId ?? '';
  final preferred = fields
      .map((e) => e.$2)
      .firstWhere(
        (value) => value != id && _looksLikeMediaName(value),
        orElse: () => '',
      );
  if (preferred.isNotEmpty) return preferred;

  final any = fields
      .map((e) => e.$2)
      .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
  if (any.isNotEmpty) return any;

  if (id.isEmpty) return 'record';
  final idx = id.lastIndexOf('/');
  if (idx >= 0) return id.substring(idx + 1);
  return id;
}

pb_media_enum.MediaFile_Type? _inferMediaFileType(List<(int, int)> fields) {
  for (final (_, value) in fields) {
    if (value <= 0x7FFFFFFF) {
      final type = pb_media_enum.MediaFile_Type.valueOf(value);
      if (type != null) return type;
    }
  }
  return null;
}

int? _inferTimestamp(List<(int, int)> fields) {
  for (final (_, value) in fields) {
    if (value >= 1_000_000_000_000) return value;
  }
  for (final (_, value) in fields) {
    if (value >= 946_684_800 && value <= 4_102_444_800) {
      return value * 1000;
    }
  }
  return null;
}

int? _inferSize(List<(int, int)> fields, int? timestampMs) {
  int? best;
  for (final (_, value) in fields) {
    if (value == timestampMs) continue;
    if (value >= 1024 && (best == null || value > best)) {
      best = value;
    }
  }
  return best;
}

int? _inferDuration(List<(int, int)> fields, int? timestampMs, int? size) {
  int? best;
  for (final (_, value) in fields) {
    if (value == timestampMs || value == size) continue;
    int? secs;
    if (value <= 86_400) {
      secs = value;
    } else if (value % 1000 == 0 && value ~/ 1000 <= 86_400) {
      secs = value ~/ 1000;
    }
    if (secs != null && secs > 0) {
      best = best == null ? secs : (secs < best ? secs : best);
    }
  }
  return best;
}

int? _normalizeTimestamp(int value) {
  if (value >= 1_000_000_000_000) return value;
  if (value >= 946_684_800 && value <= 4_102_444_800) return value * 1000;
  return null;
}

int? _normalizeDuration(int value) {
  if (value == 0) return null;
  if (value <= 86_400) return value;
  if (value % 1000 == 0 && value ~/ 1000 <= 86_400) return value ~/ 1000;
  return null;
}

bool _looksLikeMediaName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.contains('.') || trimmed.contains(' ')) return true;
  final ascii = trimmed.runes.every(
    (r) =>
        (r >= 48 && r <= 57) ||
        (r >= 65 && r <= 70) ||
        (r >= 97 && r <= 102) ||
        r == 45,
  );
  return !ascii;
}

int? _extractVarintField(Uint8List raw, int targetTag) {
  var buf = raw;
  while (buf.isNotEmpty) {
    final key = _decodeProtobufKey(buf);
    if (key == null) return null;
    final (tag, wireType, consumed) = key;
    buf = Uint8List.sublistView(buf, consumed);
    if (wireType == 0 && tag == targetTag) {
      final value = _decodeProtobufVarint(buf);
      return value?.$1;
    }
    final skipped = _skipProtobufField(buf, wireType);
    if (skipped == null) return null;
    buf = Uint8List.sublistView(buf, skipped);
  }
  return null;
}

Uint8List? _extractLengthDelimitedField(Uint8List raw, int targetTag) {
  var buf = raw;
  Uint8List? last;
  while (buf.isNotEmpty) {
    final key = _decodeProtobufKey(buf);
    if (key == null) return last;
    final (tag, wireType, consumed) = key;
    buf = Uint8List.sublistView(buf, consumed);
    if (wireType == 2) {
      final len = _decodeProtobufVarint(buf);
      if (len == null) return last;
      buf = Uint8List.sublistView(buf, len.$2);
      final fieldLen = len.$1;
      if (buf.length < fieldLen) return last;
      final field = Uint8List.sublistView(buf, 0, fieldLen);
      buf = Uint8List.sublistView(buf, fieldLen);
      if (tag == targetTag) last = field;
    } else {
      final skipped = _skipProtobufField(buf, wireType);
      if (skipped == null) return last;
      buf = Uint8List.sublistView(buf, skipped);
    }
  }
  return last;
}

List<Uint8List> _extractRepeatedLengthDelimitedFields(
  Uint8List raw,
  int targetTag,
) {
  final result = <Uint8List>[];
  var buf = raw;
  while (buf.isNotEmpty) {
    final key = _decodeProtobufKey(buf);
    if (key == null) break;
    final (tag, wireType, consumed) = key;
    buf = Uint8List.sublistView(buf, consumed);
    if (wireType == 2) {
      final len = _decodeProtobufVarint(buf);
      if (len == null) break;
      buf = Uint8List.sublistView(buf, len.$2);
      final fieldLen = len.$1;
      if (buf.length < fieldLen) break;
      final field = Uint8List.sublistView(buf, 0, fieldLen);
      buf = Uint8List.sublistView(buf, fieldLen);
      if (tag == targetTag) result.add(field);
    } else {
      final skipped = _skipProtobufField(buf, wireType);
      if (skipped == null) break;
      buf = Uint8List.sublistView(buf, skipped);
    }
  }
  return result;
}

(int, int, int)? _decodeProtobufKey(Uint8List buf) {
  if (buf.isEmpty) return null;
  final value = _decodeProtobufVarint(buf);
  if (value == null) return null;
  final key = value.$1;
  final consumed = value.$2;
  final tag = key >> 3;
  final wireType = key & 0x7;
  return (tag, wireType, consumed);
}

(int, int)? _decodeProtobufVarint(Uint8List buf) {
  var result = 0;
  var shift = 0;
  var i = 0;
  while (i < buf.length) {
    final byte = buf[i];
    result |= (byte & 0x7F) << shift;
    i++;
    if ((byte & 0x80) == 0) return (result, i);
    shift += 7;
    if (shift > 63) return null;
  }
  return null;
}

int? _skipProtobufField(Uint8List buf, int wireType) {
  switch (wireType) {
    case 0:
      final v = _decodeProtobufVarint(buf);
      return v?.$2;
    case 1:
      return 8;
    case 2:
      final len = _decodeProtobufVarint(buf);
      if (len == null) return null;
      return len.$2 + len.$1;
    case 5:
      return 4;
    default:
      return null;
  }
}

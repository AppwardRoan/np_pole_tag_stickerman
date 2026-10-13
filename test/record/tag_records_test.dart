import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:np_pole_tag_stickerman/services/api_services.dart';

/// Reading back what the office holds against one pole.
///
/// The app has always written records and never read one. What it gets back is
/// not the map it sent: the four choices come back as ids, the decimals come
/// back as numbers that may or may not carry a fraction, and the timestamps
/// come back without a zone - which is eight hours of skew in this country if
/// it is parsed as written.

const _oneRecord = '''
[
  {
    "record_id": 912,
    "tag_id": 4821,
    "tag_code": "M31M0",
    "is_current": true,
    "latitude": 10.657912,
    "longitude": 122.948103,
    "gps_accuracy": 4.5,
    "pole_type_id": 2,
    "pole_condition_id": 1,
    "telco_option_id": 3,
    "streetlight_option_id": 1,
    "height_ft": 35,
    "height_m": 10.67,
    "remarks": null,
    "submitted_by": 2,
    "org_id": 1,
    "created_at": "2026-09-15T01:12:44",
    "photos": [
      {"photo_id": 3301, "record_id": 912, "photo_type": "tag_closeup",
       "view_url": "https://x/1.jpg", "taken_at": "2026-09-15T01:11:58"},
      {"photo_id": 3302, "record_id": 912, "photo_type": "full_pole",
       "view_url": "https://x/2.jpg", "taken_at": null},
      {"photo_id": 3303, "record_id": 912, "photo_type": "surroundings",
       "view_url": "https://x/3.jpg", "taken_at": null},
      {"photo_id": 3304, "record_id": 912, "photo_type": "extra",
       "view_url": "https://x/4.jpg", "taken_at": null},
      {"photo_id": 3305, "record_id": 912, "photo_type": "extra",
       "view_url": "https://x/5.jpg", "taken_at": null}
    ]
  }
]
''';

const _refiled = '''
[
  {"record_id": 940, "tag_id": 4821, "tag_code": "M31M0", "is_current": true,
   "org_id": 1, "created_at": "2026-09-15T01:12:44", "photos": []},
  {"record_id": 912, "tag_id": 4821, "tag_code": "M31M0", "is_current": false,
   "org_id": 1, "created_at": "2026-09-12T06:03:00", "photos": []}
]
''';

ApiService _api(String body, {int status = 200, void Function(http.Request)? saw}) {
  return ApiService(
    client: MockClient((request) async {
      saw?.call(request);
      return http.Response(body, status);
    }),
  )..setToken('token-abc');
}

void main() {
  test('asks for the records of one tag, with the token', () async {
    http.Request? seen;
    await _api(_oneRecord, saw: (r) => seen = r).getTagRecords(4821);

    expect(seen!.method, 'GET');
    expect(seen!.url.path, endsWith('/pole-records/tag/4821'));
    expect(seen!.headers['Authorization'], 'Bearer token-abc');
  });

  test('reads the record back', () async {
    final records = await _api(_oneRecord).getTagRecords(4821);
    final record = records.single;

    expect(record.recordId, 912);
    expect(record.tagCode, 'M31M0');
    expect(record.isCurrent, isTrue);
    expect(record.poleTypeId, 2);
    expect(record.latitude, closeTo(10.657912, 0.000001));
    expect(record.heightM, closeTo(10.67, 0.001));
  });

  test('a whole number of feet is not an int the parser chokes on', () async {
    // `height_ft` is Numeric on the server, so 35.00 arrives as `35` while
    // 10.67 arrives as a double. Casting straight to double threw on the first
    // pole somebody measured at exactly 35 feet.
    final records = await _api(_oneRecord).getTagRecords(4821);

    expect(records.single.heightFt, 35.0);
  });

  test('the filing time is read as UTC, not as local', () async {
    // The server sends a naive UTC timestamp. Parsed as written it reads as
    // 1:12am local, which would have him filing poles before sunrise.
    final records = await _api(_oneRecord).getTagRecords(4821);
    final at = records.single.createdAt!;

    expect(at.isUtc, isFalse);
    expect(at.toUtc().hour, 1);
  });

  test('every photograph comes through, extras included', () async {
    final photos = (await _api(_oneRecord).getTagRecords(4821)).single.photos;

    expect(photos.length, 5);
    expect(photos.first.label, 'TAG');
    expect(photos.map((p) => p.label).where((l) => l == 'EXTRA').length, 2);
  });

  test('a re-filed pole comes back current first', () async {
    final records = await _api(_refiled).getTagRecords(4821);

    expect(records.length, 2);
    expect(records.first.isCurrent, isTrue);
    expect(records.last.isCurrent, isFalse);
  });

  test('a pole with nothing filed against it is an empty list, not a throw',
      () async {
    expect(await _api('[]').getTagRecords(4821), isEmpty);
  });

  test('no signal is an error the sheet can show', () async {
    expect(
      () => _api('{"detail": "nope"}', status: 500).getTagRecords(4821),
      throwsA(isA<Exception>()),
    );
  });
}

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:np_pole_tag_stickerman/models/my_tags.dart';
import 'package:np_pole_tag_stickerman/models/tag.dart';
import 'package:np_pole_tag_stickerman/models/tag_search.dart';
import 'package:np_pole_tag_stickerman/providers/api_providers.dart';
import 'package:np_pole_tag_stickerman/providers/search_providers.dart';
import 'package:np_pole_tag_stickerman/providers/tag_providers.dart';
import 'package:np_pole_tag_stickerman/services/api_services.dart';

/// The search box: the phone's own list first, the server only behind it.
///
/// What these are really guarding is the sentence he reads when nothing is
/// found. Three different nothings arrive at the same empty screen - the pole
/// is not his, the server capped it away, the phone could not ask - and only
/// one of them means what "no match" says.

Tag _tag(String code, {String status = 'Dispatched', String? batch}) {
  return Tag(
    tagId: code.hashCode,
    duId: 1,
    batchId: 5,
    batchCode: batch ?? 'BT-M-2026-0027',
    tagCode: code,
    status: status,
  );
}

/// A container whose tag list is already filled, the way the home screen has
/// it by the time he types.
ProviderContainer _containerWith(List<Tag> onPhone, {ApiService? api}) {
  final container = ProviderContainer(overrides: [
    if (api != null) apiProvider.overrideWithValue(api),
  ]);

  addTearDown(container.dispose);

  container.read(tagProvider.notifier).state = TagState(
    tags: MyTags(received: onPhone),
  );

  return container;
}

ApiService _serverReturning(String body, {int status = 200}) {
  return ApiService(
    client: MockClient((_) async => http.Response(body, status)),
  );
}

void main() {
  group('TagSearch', () {
    test('reads the rows and the total', () {
      final parsed = TagSearch.fromJson(jsonDecode(jsonEncode({
        'tags': [
          {'tag_id': 1, 'du_id': 1, 'tag_code': 'M006R', 'status': 'Installed'}
        ],
        'total': 2800,
      })) as Map<String, dynamic>);

      expect(parsed.tags.single.tagCode, 'M006R');
      expect(parsed.total, 2800);
      expect(parsed.wasCut, isTrue);
    });

    // A reply that cannot say how many there were must not claim there were
    // none: "0 of 1" reads as a bug, "1 of 1" as the truth as far as anyone
    // knows.
    test('a missing total falls back to the row count', () {
      final parsed = TagSearch.fromJson({
        'tags': [
          {'tag_id': 1, 'du_id': 1, 'tag_code': 'M006R', 'status': 'Installed'}
        ],
      });

      expect(parsed.total, 1);
      expect(parsed.wasCut, isFalse);
    });
  });

  group('the phone answers first', () {
    test('a code on the phone is found without asking the server', () async {
      var asked = false;

      final api = ApiService(client: MockClient((_) async {
        asked = true;
        return http.Response('{}', 200);
      }));

      final container = _containerWith([_tag('M006R'), _tag('M112A')], api: api);

      container.read(searchProvider.notifier).search('M006');
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final state = container.read(searchProvider);

      expect(state.results.single.tagCode, 'M006R');
      expect(state.outcome, SearchOutcome.onPhone);
      expect(asked, isFalse, reason: 'the local list already answered');
    });

    test('a batch code matches anywhere inside it', () async {
      final container = _containerWith([_tag('M006R', batch: 'BT-M-2026-0027')]);

      container.read(searchProvider.notifier).search('0027');
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(container.read(searchProvider).results, hasLength(1));
    });

    test('a tag code matches by its start, not anywhere', () async {
      // The server is mocked to an empty answer rather than left out: a local
      // miss goes on to ask it, and this is asserting the local rule alone.
      final api = _serverReturning(jsonEncode({'tags': [], 'total': 0}));
      final container = _containerWith([_tag('M006R', batch: 'X')], api: api);

      container.read(searchProvider.notifier).search('006R');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(container.read(searchProvider).results, isEmpty);
    });

    test('clearing the box puts the tabs back', () {
      final container = _containerWith([_tag('M006R')]);

      container.read(searchProvider.notifier).search('M006');
      expect(container.read(searchProvider).isActive, isTrue);

      container.read(searchProvider.notifier).clear();
      expect(container.read(searchProvider).isActive, isFalse);
    });
  });

  group('the server answers behind it', () {
    test('a miss on the phone is asked of the server', () async {
      final api = _serverReturning(jsonEncode({
        'tags': [
          {'tag_id': 9, 'du_id': 1, 'tag_code': 'M006R', 'status': 'Installed'}
        ],
        'total': 1,
      }));

      final container = _containerWith([_tag('M112A')], api: api);

      container.read(searchProvider.notifier).search('M006R');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final state = container.read(searchProvider);

      expect(state.results.single.tagCode, 'M006R');
      expect(state.outcome, SearchOutcome.fromServer);
    });

    test('a capped reply keeps the total, so the screen can say so', () async {
      final api = _serverReturning(jsonEncode({
        'tags': [
          {'tag_id': 9, 'du_id': 1, 'tag_code': 'M006R', 'status': 'Installed'}
        ],
        'total': 2800,
      }));

      final container = _containerWith([], api: api);

      container.read(searchProvider.notifier).search('M00');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(container.read(searchProvider).wasCut, isTrue);
      expect(container.read(searchProvider).total, 2800);
    });

    // Two characters against a year of work match most of it, and the answer
    // is always "type more" - which costs nothing to say here.
    test('one or two characters never leave the phone', () async {
      var asked = false;

      final api = ApiService(client: MockClient((_) async {
        asked = true;
        return http.Response('{}', 200);
      }));

      final container = _containerWith([], api: api);

      container.read(searchProvider.notifier).search('M0');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(asked, isFalse);
      expect(container.read(searchProvider).outcome, SearchOutcome.missed);
    });

    test('no signal is told apart from no such tag', () async {
      final api = ApiService(
        client: MockClient((_) async => throw const SocketishFailure()),
      );

      final container = _containerWith([], api: api);

      container.read(searchProvider.notifier).search('M006R');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(
        container.read(searchProvider).outcome,
        SearchOutcome.unreachable,
      );
    });

    test('an empty server reply is a plain miss', () async {
      final api = _serverReturning(jsonEncode({'tags': [], 'total': 0}));
      final container = _containerWith([], api: api);

      container.read(searchProvider.notifier).search('M006R');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(container.read(searchProvider).outcome, SearchOutcome.missed);
    });

    // He keeps typing while a request is in the air, and replies do not have
    // to come back in the order they went out.
    test('a stale reply does not overwrite a newer search', () async {
      var call = 0;

      final api = ApiService(client: MockClient((request) async {
        call++;
        final slow = call == 1;
        if (slow) await Future<void>.delayed(const Duration(milliseconds: 400));

        return http.Response(
          jsonEncode({
            'tags': [
              {
                'tag_id': call,
                'du_id': 1,
                'tag_code': slow ? 'STALE' : 'FRESH',
                'status': 'Installed',
              }
            ],
            'total': 1,
          }),
          200,
        );
      }));

      final container = _containerWith([], api: api);
      final notifier = container.read(searchProvider.notifier);

      notifier.search('M00A');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      notifier.search('M00AB');
      await Future<void>.delayed(const Duration(milliseconds: 900));

      expect(container.read(searchProvider).results.single.tagCode, 'FRESH');
    });
  });
}

/// Anything `_send` does not recognise becomes its status-0 "never reached
/// the server", which is the case being tested.
class SocketishFailure implements Exception {
  const SocketishFailure();
}

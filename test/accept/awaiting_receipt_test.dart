import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:np_pole_tag_stickerman/providers/api_providers.dart';
import 'package:np_pole_tag_stickerman/providers/awaiting_receipt_providers.dart';
import 'package:np_pole_tag_stickerman/services/api_services.dart';
import 'package:np_pole_tag_stickerman/services/awaiting_cache.dart';

/// The accept screen's half of the hand-over.
///
/// What these guard is the moment either side of the tap. Before it, the man
/// is holding paper the office has no record of him holding; after it, the
/// tags it covers are the only ones he can file a pole against. Getting the
/// list wrong strands him at a pole; leaving the tags unrefreshed strands him
/// on a home screen that still says he has nothing.

const _oneBatch = '''
[
  {
    "batch_id": 88,
    "batch_code": "BT-NP-2026-0004",
    "work_order_name": "JOB 14 / TALISAY",
    "my_tags": 30,
    "dispatched_at": "2026-09-15T07:40:12"
  }
]
''';

const _twoBatches = '''
[
  {
    "batch_id": 88,
    "batch_code": "BT-NP-2026-0004",
    "work_order_name": "JOB 14 / TALISAY",
    "my_tags": 30,
    "dispatched_at": "2026-09-14T07:40:12"
  },
  {
    "batch_id": 91,
    "batch_code": "BT-NP-2026-0005",
    "work_order_name": "JOB 15 / BACOLOD",
    "my_tags": 12,
    "dispatched_at": "2026-09-15T09:05:44"
  }
]
''';

/// The tags reply, so the reload that follows a tap has something to land on.
const _noTags = '{"received": [], "completed": []}';

const _stats = '''
{"assigned": 0, "completed": 0, "completed_today": 0,
 "awaiting_batches": 0, "batches_total": 0, "batches_done": 0}
''';

/// A server that answers each path in its own way, and counts what was asked.
///
/// Routed by path rather than by returning one body to everything, because the
/// tap fires three requests - the accept, then the tag list and the figures
/// behind it - and a single body would have the tag list parsing a batch.
class _Server {
  _Server({this.acceptStatus = 200, this.list = '[]'});

  /// Mutable, so one test can load with signal and then lose it - which is the
  /// only way to check that a failed refresh leaves the rows alone.
  int acceptStatus;
  String list;
  int listStatus = 200;

  int accepts = 0;
  int tagLoads = 0;
  String? acceptedPath;

  ApiService get api => ApiService(
    client: MockClient((request) async {
      final path = request.url.path;

      if (path.endsWith('/receive')) {
        accepts++;
        acceptedPath = path;
        return http.Response(
          acceptStatus == 200
              ? '{"batch_id": 88}'
              : '{"detail": "You have no tags waiting to be received in '
                    'BT-NP-2026-0004."}',
          acceptStatus,
        );
      }

      if (path.endsWith('/awaiting-receipt')) {
        return http.Response(list, listStatus);
      }

      if (path.endsWith('/tags/my')) {
        tagLoads++;
        return http.Response(_noTags, 200);
      }

      return http.Response(_stats, 200);
    }),
  );
}

ProviderContainer _containerFor(_Server server) {
  final container = ProviderContainer(
    overrides: [apiProvider.overrideWithValue(server.api)],
  );

  addTearDown(container.dispose);
  return container;
}

void main() {
  // The tap reloads his tags, and that read goes through the phone's own copy
  // before it goes to the server - so Hive has to have somewhere to be.
  late Directory home;

  setUp(() {
    home = Directory.systemTemp.createTempSync('awaiting_receipt_hive');
    Hive.init(home.path);
  });

  tearDown(() async {
    await Hive.close();
    if (home.existsSync()) home.deleteSync(recursive: true);
  });

  group('the list', () {
    test('reads what the office has sent out', () async {
      final container = _containerFor(_Server(list: _oneBatch));

      await container.read(awaitingReceiptProvider.notifier).load();

      final state = container.read(awaitingReceiptProvider);
      expect(state.batches, hasLength(1));
      expect(state.batches.first.batchCode, 'BT-NP-2026-0004');
      expect(state.batches.first.workOrderName, 'JOB 14 / TALISAY');
      expect(state.batches.first.myTags, 30);
      expect(state.error, isNull);
    });

    test('keeps the order the server sent, longest wait first', () async {
      final container = _containerFor(_Server(list: _twoBatches));

      await container.read(awaitingReceiptProvider.notifier).load();

      expect(
        container
            .read(awaitingReceiptProvider)
            .batches
            .map((b) => b.batchCode)
            .toList(),
        ['BT-NP-2026-0004', 'BT-NP-2026-0005'],
      );
    });

    test('nothing waiting is an empty screen, not an error', () async {
      final container = _containerFor(_Server(list: '[]'));

      await container.read(awaitingReceiptProvider.notifier).load();

      final state = container.read(awaitingReceiptProvider);
      expect(state.isEmpty, isTrue);
      expect(state.error, isNull);
    });

    test('a failed refresh keeps the rows already on screen', () async {
      // Loaded with signal, then pulled without it. The paper is still out
      // with him either way, so a refresh that could not reach the office must
      // not blank the screen he was reading - it has not made anything untrue.
      final server = _Server(list: _oneBatch);
      final container = _containerFor(server);
      await container.read(awaitingReceiptProvider.notifier).load();

      server.listStatus = 503;
      server.list = '{"detail": "Service unavailable"}';
      await container.read(awaitingReceiptProvider.notifier).refresh();

      final state = container.read(awaitingReceiptProvider);
      expect(state.batches, hasLength(1));
      expect(state.error, isNotNull);
    });
  });

  group('the tap', () {
    test('sends the batch id and nothing else', () async {
      final server = _Server(list: _oneBatch);
      final container = _containerFor(server);
      await container.read(awaitingReceiptProvider.notifier).load();

      final accepted = await container
          .read(awaitingReceiptProvider.notifier)
          .accept(88);

      expect(accepted, isTrue);
      expect(server.accepts, 1);
      expect(server.acceptedPath, endsWith('/batches/88/receive'));
    });

    test('the accepted batch leaves the list', () async {
      final server = _Server(list: _twoBatches);
      final container = _containerFor(server);
      await container.read(awaitingReceiptProvider.notifier).load();

      await container.read(awaitingReceiptProvider.notifier).accept(88);

      expect(
        container
            .read(awaitingReceiptProvider)
            .batches
            .map((b) => b.batchId)
            .toList(),
        [91],
      );
    });

    test('his tags are reloaded, or he comes back to an empty list', () async {
      // The whole point of the tap: those tags were locked a moment ago and
      // are his to work now. Without this the home screen still shows the
      // nothing he left it showing.
      final server = _Server(list: _oneBatch);
      final container = _containerFor(server);
      await container.read(awaitingReceiptProvider.notifier).load();

      final before = server.tagLoads;
      await container.read(awaitingReceiptProvider.notifier).accept(88);

      expect(server.tagLoads, before + 1);
    });

    test('a refusal keeps the batch and carries the server sentence', () async {
      // The message names the batch, so it is worth showing instead of a
      // fallback: "no tags waiting in BT-NP-2026-0004" tells him he has
      // already accepted it.
      final server = _Server(list: _oneBatch, acceptStatus: 400);
      final container = _containerFor(server);
      await container.read(awaitingReceiptProvider.notifier).load();

      final accepted = await container
          .read(awaitingReceiptProvider.notifier)
          .accept(88);

      final state = container.read(awaitingReceiptProvider);
      expect(accepted, isFalse);
      expect(state.batches, hasLength(1));
      expect(state.error, contains('BT-NP-2026-0004'));
      // And the screen is usable again - a failed tap must not leave every
      // button greyed out.
      expect(state.accepting, isNull);
    });

    test('a second tap while one is in flight is ignored', () async {
      // Two claims for one envelope, from one thumb on a slow connection.
      final server = _Server(list: _twoBatches);
      final container = _containerFor(server);
      await container.read(awaitingReceiptProvider.notifier).load();

      final notifier = container.read(awaitingReceiptProvider.notifier);
      final first = notifier.accept(88);
      final second = notifier.accept(91);

      expect(await second, isFalse);
      expect(await first, isTrue);
      expect(server.accepts, 1);
    });
  });

  group('the saved copy', () {
    test('the list survives an app that reopens with no signal', () async {
      // The strip that sends him here counts from cached figures, so it draws
      // offline. Without this the promise it makes lands on an error screen.
      final server = _Server(list: _oneBatch);
      await _containerFor(server).read(awaitingReceiptProvider.notifier).load();

      final offline = _Server(list: '{"detail": "no signal"}')
        ..listStatus = 0;
      final second = _containerFor(offline);
      await second.read(awaitingReceiptProvider.notifier).load();

      final state = second.read(awaitingReceiptProvider);
      expect(state.batches, hasLength(1));
      expect(state.batches.first.batchCode, 'BT-NP-2026-0004');
      // And the buttons say why they cannot be pressed.
      expect(state.isOffline, isTrue);
    });

    test('an envelope he accepted is not offered again on a cold open',
        () async {
      final server = _Server(list: _oneBatch);
      final container = _containerFor(server);
      await container.read(awaitingReceiptProvider.notifier).load();
      await container.read(awaitingReceiptProvider.notifier).accept(88);

      final offline = _Server(list: '{"detail": "no signal"}')
        ..listStatus = 0;
      final second = _containerFor(offline);
      await second.read(awaitingReceiptProvider.notifier).load();

      expect(second.read(awaitingReceiptProvider).isEmpty, isTrue);
    });

    test('signing out takes the envelopes with him', () async {
      // They are one man's paper. The next man on this handset must not find
      // an Accept button on it - on screen or on a cold open afterwards.
      final container = _containerFor(_Server(list: _oneBatch));
      await container.read(awaitingReceiptProvider.notifier).load();

      await container.read(awaitingReceiptProvider.notifier).clear();

      expect(container.read(awaitingReceiptProvider).isEmpty, isTrue);
      expect(await const AwaitingCache().read(), isEmpty);
    });
  });

}

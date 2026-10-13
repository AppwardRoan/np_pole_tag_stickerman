import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:np_pole_tag_stickerman/config/api_config.dart';
import 'package:np_pole_tag_stickerman/models/auth.dart';
import 'package:np_pole_tag_stickerman/models/form_options.dart';
import 'package:np_pole_tag_stickerman/models/my_stats.dart';
import 'package:np_pole_tag_stickerman/models/my_tags.dart';
import 'package:np_pole_tag_stickerman/models/pole_record.dart';
import 'package:np_pole_tag_stickerman/models/tag_search.dart';
import 'package:np_pole_tag_stickerman/models/user.dart';
import 'package:np_pole_tag_stickerman/models/tag.dart';
import 'package:np_pole_tag_stickerman/models/my_batch.dart';
import 'package:np_pole_tag_stickerman/models/batch_awaiting_receipt.dart';
import 'package:np_pole_tag_stickerman/services/api_exception.dart';
import 'package:np_pole_tag_stickerman/services/pole_upload_api.dart';

// ApiService — the only thing that talks to the server.
//
// - Screens never call the server themselves. They go through the provider,
//   which goes through here.
// - This class knows HOW to talk to the server. It remembers nothing except
//   the token.
class ApiService implements PoleUploadApi {
  /// The client is injectable for one reason: a test can hand in a fake and
  /// assert on what went out. Every caller in the app uses the default.
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // Part 1 — the setup
  //
  // - baseUrl — the server's address. Comes from api_config.dart.
  // - timeout — how long to wait before giving up. Just a number; _send is
  //   what actually enforces it.
  static final String baseUrl = ApiConfig.baseUrl;

  static const Duration timeout = Duration(seconds: 30);

  // Part 2 — the token
  //
  // - The server gives you a token when you log in.
  // - Every later request has to carry it.
  // - This class holds it, so screens never have to pass it around.
  // - setToken is the only way in. Two callers:
  //   a. Login worked  → setToken('eyJhbGci...')
  //   b. Logout        → setToken(null), and the token is forgotten
  // - Lives in memory only. Saving it to the phone is the provider's job.
  String? _token;

  void setToken(String? token) {
    _token = (token != null && token.isEmpty) ? null : token;
  }

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  // The same headers plus the token, for every endpoint behind `get_current_user`.
  //
  // The header is left off entirely when there is no token, rather than sent
  // empty: `Authorization: Bearer ` makes the server answer 401 with a parsing
  // complaint, which reads as "your login is broken" instead of the plain "you
  // are not signed in" that a missing header produces.
  Map<String, String> get _authHeaders => {
    ..._jsonHeaders,
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // Part 3 — _send: the safety net around every request
  //
  // - Wraps every call so two failures are always handled:
  //   a. Timeout — the server was reached but didn't answer in 30 seconds.
  //   b. catch (_) — the server was never reached at all. No signal, wifi off,
  //      server not running.
  // - Without it: the app hangs forever, or Juan sees a raw crash message.
  // - With it: both come out as one readable sentence.
  // - Note a 500 is NEITHER of these. A 500 means the server DID answer, so
  //   _send hands it back normally and login() deals with it.
  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(timeout);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        0,
        'The server took too long to respond. Please try again.',
      );
    } catch (_) {
      throw ApiException(
        0,
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  // Part 4 — login
  //
  // - In order:
  //   a. Build the JSON body from LoginRequest
  //   b. POST it to /auth/login, wrapped in _send
  //   c. Got 200 → parse into LoginResponse (token + full user with roles)
  //   d. Anything else → throw, carrying the server's own message
  // - The username field accepts a username OR an email. The backend matches
  //   both, so one field on the login screen is enough.
  // - The roles arrive with the token, so nobody needs a second request to
  //   find out whether this is a Sticker man.
  Future<LoginResponse> login(String username, String password) async {
    final response = await _send(
      () => _client.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _jsonHeaders,
        body: jsonEncode(
          LoginRequest(username: username, password: password).toJson(),
        ),
      ),
    );

    if (response.statusCode == 200) {
      final login = LoginResponse.fromJson(jsonDecode(response.body));

      // A 200 carrying no token is not a login. LoginResponse defaults a
      // missing `access_token` to '', which setToken then turns back into
      // null - so without this the app would look signed in while every later
      // request went out unauthenticated.
      if (login.accessToken.isEmpty) {
        throw ApiException(
          response.statusCode,
          'The server signed you in without a token. Please try again.',
        );
      }

      return login;
    }

    throw ApiException.fromResponse(
      response.statusCode,
      response.body,
      fallback: 'Login failed: ${response.statusCode}',
    );
  }

  // Part 5 — getMe
  //
  // - Asks the server who the current token belongs to: GET /me.
  // - Two things at once:
  //   a. Is this token still valid? A 401 means expired or tampered with; a
  //      403 means the account was deactivated since it was issued.
  //   b. Who is it, exactly? The reply is the same full user (roles included)
  //      that login returns, so a cached copy on the phone can be refreshed
  //      from it.
  // - Note what a thrown ApiException with statusCode 0 means here: the server
  //   was never reached. That is NOT a dead token — the caller has to tell the
  //   two apart before deciding to sign anyone out.
  Future<User> getMe() async {
    final response = await _send(
      () => _client.get(Uri.parse('$baseUrl/me'), headers: _authHeaders),
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }

    throw ApiException.fromResponse(
      response.statusCode,
      response.body,
      fallback: 'Could not confirm your session: ${response.statusCode}',
    );
  }

  // Part 6 — getMyTags
  //
  // - GET /tags/my. The token says who is asking, so there is no user id to
  //   pass and no way to ask for someone else's tags.
  // - Two lists, not one: `received` and `completed`, each already in the
  //   order its tab shows. A tag he has not accepted is in neither and is not
  //   sent - it cannot be scanned, and accepting is a batch action with a
  //   screen of its own. Withdrawn codes — Lost Printed, Do Not Use — are
  //   absent for a different reason: they are the office taking a code back,
  //   which is nothing he can act on at a pole.
  // - No query parameters. The endpoint answers the whole screen, so there is
  //   nothing left to ask it for.
  // - Not paged. Both lists arrive in one response, which is what makes them
  //   usable once the signal goes.
  Future<MyTags> getMyTags() async {
    final uri = Uri.parse('$baseUrl/tags/my');

    final response = await _send(() => _client.get(uri, headers: _authHeaders));

    if (response.statusCode == 200) {
      return MyTags.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException.fromResponse(
      response.statusCode,
      response.body,
      fallback: 'Could not load your tags: ${response.statusCode}',
    );
  }

  // Part 6b — searchMyTags
  //
  // - GET /tags/my/search?q=. The fallback behind the search box, asked only
  //   when the list already on the phone has nothing to show.
  // - Searches the same set as getMyTags — his own tags, Dispatched or
  //   Used — so a hit here is always a pole he can act on.
  // - The reply is capped at 25 rows and carries the total it was cut from.
  //   See TagSearch for why the number has to travel with them.
  // - 422 is an empty search. The box does not send one, so it would take a
  //   bug here to see it, and it comes back as the exception it is rather
  //   than as an empty result that would read as "no such pole".
  Future<TagSearch> searchMyTags(String query) async {
    final uri = Uri.parse('$baseUrl/tags/my/search')
        .replace(queryParameters: {'q': query});

    final response = await _send(() => _client.get(uri, headers: _authHeaders));

    if (response.statusCode == 200) {
      return TagSearch.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException.fromResponse(
      response.statusCode,
      response.body,
      fallback: 'Could not search your tags: ${response.statusCode}',
    );
  }

  // Part 6c — getMyStats
  //
  // - GET /stats/stickerman. The three tiles across the top of the home
  //   screen, counted by the server.
  // - Separate from getMyTags on purpose. The lists that call returns are
  //   capped, so totalling them reported the cap once he passed it — the man
  //   who had done the most work read his own day short. These are counted
  //   against every row he has, not against what fitted in a reply.
  // - No parameters. The token says who is asking, and the figures are his
  //   own; there is nothing to pass and no way to ask for a colleague's.
  // - 403 means the Crew role is not on his account. That is the office's to
  //   fix, not something to retry, and it is the one failure here a caller
  //   may want to tell apart from a dead signal.
  Future<MyStats> getMyStats() async {
    final uri = Uri.parse('$baseUrl/stats/stickerman');

    final response = await _send(() => _client.get(uri, headers: _authHeaders));

    if (response.statusCode == 200) {
      return MyStats.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException.fromResponse(
      response.statusCode,
      response.body,
      fallback: 'Could not load your totals: ${response.statusCode}',
    );
  }

  // Part 6d — getMyCompletedBatches
  //
  // - GET /batches/my-completed. The My work screen: his finished poles
  //   gathered into the batches they came out of.
  // - Paged rather than capped, which is the opposite of getMyTags and
  //   deliberate. That one is read at a pole with no signal, where a page 2
  //   never arrives; this one is a review he opens where there is a
  //   connection, and his history outgrows any cap worth sending.
  // - Nothing here is cached. The home list has to survive a dead spot; this
  //   screen showing "no signal" is an honest answer to opening it in one.
  // - Only batches he has finished something in. A batch he has not started is
  //   work, and work is the home screen's business.
  Future<MyBatchesPage> getMyCompletedBatches({
    int skip = 0,
    int limit = 10,
  }) async {
    final uri = Uri.parse('$baseUrl/batches/my-completed')
        .replace(queryParameters: {'skip': '$skip', 'limit': '$limit'});

    final response = await _send(() => _client.get(uri, headers: _authHeaders));

    if (response.statusCode == 200) {
      return MyBatchesPage.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException.fromResponse(
      response.statusCode,
      response.body,
      fallback: 'Could not load your batches: ${response.statusCode}',
    );
  }

  // Part 6d2 — getBatchesAwaitingReceipt
  //
  // - GET /batches/awaiting-receipt. The accept screen: envelopes the office
  //   has sent out that he has not yet said he is holding.
  // - Batches, not tags. Accepting is one tap on a whole share, so the card is
  //   the batch and the count sits on it - and `getMyTags` deliberately does
  //   not send unaccepted tags at all, so there is nothing on the phone to
  //   group into this list.
  // - Not paged and not capped. It is bounded by what a dispatcher physically
  //   handed him, which is one envelope, occasionally two.
  // - Nothing here is cached. Accepting needs signal anyway, so a list read in
  //   a dead spot would only offer a button that cannot be pressed.
  // - An empty list is the ordinary answer, not an error. Most days he has
  //   nothing waiting.
  Future<List<BatchAwaitingReceipt>> getBatchesAwaitingReceipt() async {
    final uri = Uri.parse('$baseUrl/batches/awaiting-receipt');

    final response = await _send(() => _client.get(uri, headers: _authHeaders));

    if (response.statusCode == 200) {
      final rows = jsonDecode(response.body);
      if (rows is! List) return const [];

      return rows
          .whereType<Map>()
          .map(
            (row) =>
                BatchAwaitingReceipt.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();
    }

    throw ApiException.fromResponse(
      response.statusCode,
      response.body,
      fallback: 'Could not load what is waiting for you: '
          '${response.statusCode}',
    );
  }

  // Part 6d3 — receiveBatch
  //
  // - PATCH /batches/{id}/receive. His own word that he has his share of this
  //   envelope in his hand, and the only thing that unlocks those tags for
  //   pole records.
  // - Sends no body and no user id. The token says who is asking, which is
  //   what stops one man accepting on another's behalf - the whole reason the
  //   step exists.
  // - Moves only his own tags in the batch. Everybody else's are left where
  //   they were, so nobody waits for anybody.
  // - There is no undo. Once it returns, the paper is his as far as the office
  //   is concerned.
  // - A 400 is the ordinary refusal: nothing of his left to accept, or the
  //   batch is not out with a crew. The server's own sentence is worth showing
  //   - it names the batch.
  Future<void> receiveBatch(int batchId) async {
    final uri = Uri.parse('$baseUrl/batches/$batchId/receive');

    final response = await _send(
      () => _client.patch(uri, headers: _authHeaders),
    );

    if (response.statusCode == 200) return;

    throw ApiException.fromResponse(
      response.statusCode,
      response.body,
      fallback: 'Could not accept this batch: ${response.statusCode}',
    );
  }

  // Part 6e — getMyTagsInBatch
  //
  // - GET /batches/{id}/tags?mine=true. What one batch holds of his work,
  //   fetched when he taps a row open on the My work screen.
  // - `mine=true` is the whole reason this differs from what the office calls:
  //   a run is split across a crew, and without it he would read two hundred
  //   rows looking for his fifty.
  // - Fetched on the tap rather than with the batch list. Ten batches would be
  //   five hundred tags pulled down to show whichever one he opens, and most
  //   of them he never will.
  // - Not cached. The Completed tab on the home screen already holds his
  //   finished tags offline; this is the batch breakdown, read where there is
  //   signal.
  Future<List<Tag>> getMyTagsInBatch(int batchId) async {
    final uri = Uri.parse('$baseUrl/batches/$batchId/tags')
        .replace(queryParameters: {'mine': 'true'});

    final response = await _send(() => _client.get(uri, headers: _authHeaders));

    if (response.statusCode == 200) {
      final rows = jsonDecode(response.body);
      if (rows is! List) return const [];

      return rows
          .whereType<Map>()
          .map((row) => Tag.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    }

    throw ApiException.fromResponse(
      response.statusCode,
      response.body,
      fallback: 'Could not load this batch: ${response.statusCode}',
    );
  }

  // Part 6f — downloadMyPolesCsv
  //
  // - GET /batches/my-completed/export. His finished poles as a spreadsheet,
  //   for sending on to whoever asked for them.
  // - With a batchId, that batch alone. Without, every batch he has finished
  //   work in - one flat table with a Batch column, so the two shapes are the
  //   same file and the screen has nothing to assemble.
  // - Returns the bytes and the name the server chose, rather than writing the
  //   file here: what to do with it is the caller's business, and this class
  //   talks to the server and nothing else.
  // - The bytes are taken as bytes, not as `response.body`. That getter
  //   decodes using the charset in the content type, and a remark carrying an
  //   n-tilde comes back mangled if the server did not name one.
  Future<({List<int> bytes, String filename})> downloadMyPolesCsv({
    int? batchId,
  }) async {
    final uri = Uri.parse('$baseUrl/batches/my-completed/export').replace(
      queryParameters: batchId == null ? null : {'batch_id': '$batchId'},
    );

    final response = await _send(() => _client.get(uri, headers: _authHeaders));

    if (response.statusCode == 200) {
      return (
        bytes: response.bodyBytes,
        filename: _filenameFrom(response.headers) ?? 'my-poles.csv',
      );
    }

    throw ApiException.fromResponse(
      response.statusCode,
      response.body,
      fallback: 'Could not build the file: ${response.statusCode}',
    );
  }

  /// The name off `Content-Disposition`, or null when the header is missing or
  /// shaped unexpectedly.
  ///
  /// Read from the header rather than built here on purpose: the server already
  /// decided whether this file is one batch or all of them, and a second guess
  /// on the phone is a second thing to keep in step.
  static String? _filenameFrom(Map<String, String> headers) {
    final header = headers['content-disposition'];
    if (header == null) return null;

    final match = RegExp('filename="?([^";]+)"?').firstMatch(header);
    return match?.group(1);
  }

  // Part 7 — getFormOptions
  //
  // - GET /form-options. Every choice the tagging form offers, in one reply.
  // - The token decides the utility, so the ids that come back are his own.
  //   Telco "Yes" is 1 for Negros Power and 3 for BP: the app must send back
  //   the id it was given, never one of its own.
  // - One call rather than four, because the crew has signal in bursts.
  Future<FormOptions> getFormOptions() async {
    final uri = Uri.parse('$baseUrl/form-options');

    final response = await _send(() => _client.get(uri, headers: _authHeaders));

    if (response.statusCode == 200) {
      return FormOptions.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException.fromResponse(
      response.statusCode,
      response.body,
      fallback: 'Could not load the form choices: ${response.statusCode}',
    );
  }

  // Part 8 — createPoleRecord
  //
  // - POST /pole-records. The body is the map the form already built.
  // - 201 is a new record. 200 means one was already filed for this pole —
  //   the server hands back the existing one rather than erroring, which is
  //   what makes retrying an upload whose reply was lost safe.
  // - Returns the record id, because every photo has to be posted under it.
  @override
  Future<int> createPoleRecord(Map<String, dynamic> record) async {
    final response = await _send(
      () => _client.post(
        Uri.parse('$baseUrl/pole-records'),
        headers: _authHeaders,
        body: jsonEncode(record),
      ),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final id = decoded['record_id'];

      if (id is! int) {
        throw ApiException(
          response.statusCode,
          'The server saved the tag but did not say which record it is.',
        );
      }

      return id;
    }

    throw ApiException.fromResponse(
      response.statusCode,
      response.body,
      fallback: 'Could not upload the tag: ${response.statusCode}',
    );
  }

  // Part 9 — uploadPhoto
  //
  // - POST /pole-records/{id}/photos, one photo per call.
  // - Multipart, not JSON: the endpoint takes an UploadFile and two Form
  //   fields. _authHeaders cannot be used whole here — it sets
  //   Content-Type: application/json, and that makes FastAPI reject the form
  //   with a 422. Only the Authorization header carries over.
  // - taken_at is when he pressed the shutter, which with no signal is hours
  //   before this call happens.
  @override
  Future<void> uploadPhoto({
    required int recordId,
    required String path,
    required String photoType,
    required DateTime takenAt,
  }) async {
    final response = await _send(() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/pole-records/$recordId/photos'),
      );

      final token = _token;
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      request.fields['photo_type'] = photoType;
      request.fields['taken_at'] = takenAt.toUtc().toIso8601String();
      request.files.add(await http.MultipartFile.fromPath('file', path));

      return http.Response.fromStream(await _client.send(request));
    });

    if (response.statusCode == 201) return;

    throw ApiException.fromResponse(
      response.statusCode,
      response.body,
      fallback: 'Could not upload a photo: ${response.statusCode}',
    );
  }

  // Part 10 — getTagRecords
  //
  // - GET /pole-records/tag/{id}. Every record the office holds against one
  //   pole, newest first, each with its photographs.
  // - The live one is the row flagged `is_current`; the rest are attempts it
  //   replaced. Nearly every pole returns a list of one.
  // - Not cached, and not offline work. He opens this to check what the office
  //   has, which is a question only the office can answer.
  Future<List<PoleRecord>> getTagRecords(int tagId) async {
    final uri = Uri.parse('$baseUrl/pole-records/tag/$tagId');

    final response = await _send(() => _client.get(uri, headers: _authHeaders));

    if (response.statusCode == 200) {
      final rows = jsonDecode(response.body);
      if (rows is! List) return const [];

      return rows
          .whereType<Map>()
          .map((row) => PoleRecord.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    }

    throw ApiException.fromResponse(
      response.statusCode,
      response.body,
      fallback: 'Could not load this record: ${response.statusCode}',
    );
  }
}

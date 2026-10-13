import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:np_pole_tag_stickerman/models/user.dart';
import 'package:np_pole_tag_stickerman/providers/api_providers.dart';
import 'package:np_pole_tag_stickerman/providers/sign_out.dart';
import 'package:np_pole_tag_stickerman/services/api_exception.dart';
import 'package:np_pole_tag_stickerman/services/api_services.dart';

// What gets written to the phone. Two keys, always written and cleared
// together — a token with no user, or a user with no token, is treated as
// nobody signed in.
const String _tokenKey = 'token';
const String _userKey = 'user';

/// Shown when the password was right but the account has no business here.
/// Worded as something the crew can act on, since only an admin can fix it.
///
/// Names no role on purpose. It used to say "sticker men", which went stale the
/// day the role was renamed to "Crew" - and the whole point of asking the
/// server who is allowed is that this app never has to be rebuilt for a rename.
/// A message carrying the name would have put that back.
const String _notStickerMan =
    'Your account does not have access to this app. Ask your admin.';

/// Stands in for any error that is not the backend talking.
const String _unexpectedError =
    'Something went wrong signing in. Please try again.';

/// Who is signed in, and what the login screen should be showing.
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({User? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._api, this._clearUserData) : super(const AuthState());

  final ApiService _api;

  /// [clearUserData], for the sign-outs below that nobody tapped.
  final Future<void> Function() _clearUserData;

  /// Which sign-in the app is currently on.
  ///
  /// `_verify()` runs unawaited, so a logout - or a second login - can land
  /// while `GET /me` is still in flight. Without this, that reply would write
  /// the old token and user back to the phone and put the app back on Home,
  /// seconds after logout cleared both. Every entry point bumps it; the reply
  /// is dropped if the number moved while it was away.
  int _session = 0;

  Future<bool> login(String username, String password) async {
    _session++;
    state = state.copyWith(isLoading: true);

    try {
      final response = await _api.login(username, password);

      // The password was right, so the server issued a token - but this app is
      // only for the crew that puts tags on poles. Nothing is kept: no token in
      // the service, nothing on the phone, so a Dispatcher cannot end up half
      // signed in.
      if (!response.user.isStickerMan) {
        state = const AuthState(error: _notStickerMan);
        return false;
      }

      _api.setToken(response.accessToken);
      await _save(response.accessToken, response.user);

      state = AuthState(user: response.user);
      return true;
    } on ApiException catch (e) {
      // The backend writes these for the crew to read - "Invalid username or
      // password", "Too many failed login attempts. Try again in 5 minute(s)."
      state = AuthState(error: e.message);
      return false;
    } catch (_) {
      // Anything else is a Dart error: a FormatException on a proxy's HTML
      // page, a TypeError on a field the API changed shape on. Its text means
      // nothing to a man standing under a pole, so it does not go on screen.
      state = const AuthState(error: _unexpectedError);
      return false;
    }
  }

  Future<void> logout() async {
    _session++;
    _api.setToken(null);
    await _clear();

    state = const AuthState();
  }

  /// Signs in from what the last session left on the phone.
  ///
  /// The user is read from the cache rather than fetched, because the crew tags
  /// poles where there is no signal: a startup that needed the server would
  /// strand someone holding a perfectly good token, since logging in again
  /// needs the server too. So the cached copy is trusted first and checked
  /// afterwards.
  Future<void> restore() async {
    final session = ++_session;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);

    // Either half missing means there is nothing usable. A token without a
    // user is what installs from before this cache existed look like; dropping
    // it costs one login and keeps the two keys in step from then on.
    if (token == null || token.isEmpty || userJson == null) {
      if (token != null || userJson != null) await _clear();
      return;
    }

    final User user;
    try {
      user = User.fromJson(jsonDecode(userJson));
    } catch (_) {
      // Truncated or written by an older shape. Unreadable either way.
      await _clear();
      return;
    }

    // Nothing without the role is ever saved, so this only fires if the file
    // was tampered with or written by an older build.
    if (!user.isStickerMan) {
      await _clear();
      return;
    }

    // Reading the phone is asynchronous, so a login could in principle have
    // finished while this was waiting. Last one in wins.
    if (session != _session) return;

    _api.setToken(token);
    state = AuthState(user: user);

    // Deliberately not awaited: the screen is already up, and this only ever
    // corrects it.
    unawaited(_verify(token, session));
  }

  /// Asks the server for this account again, on somebody's say-so rather than
  /// on startup.
  ///
  /// What the crew screen pulls on. Being made a crew leader happens in the
  /// office, hours after he signed in, and nothing tells the handset - so the
  /// only way off that screen is to ask again. Everything the reply changes
  /// (his roles, his crew, who leads it) is written back to the phone, and the
  /// router moves him on the rebuild.
  ///
  /// Silent when there is no token: he is not signed in, and there is nothing
  /// to ask about.
  Future<void> recheck() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) return;

    await _verify(token, _session);
  }

  /// Asks the server whether the restored token is still good, and signs out if
  /// it is not.
  Future<void> _verify(String token, int session) async {
    try {
      final user = await _api.getMe();

      // Signed out, or signed in as someone else, while this was in flight.
      // The answer is about a session that no longer exists.
      if (session != _session) return;

      // The roles in the reply are current, so this is where an admin taking
      // the role away lands - possibly mid-shift, hours after he signed in.
      if (!user.isStickerMan) {
        await _clearUserData();
        await logout();
        if (mounted) state = const AuthState(error: _notStickerMan);
        return;
      }

      await _save(token, user);
      if (session != _session) {
        // Logged out mid-write. The keys this just put back have to go again,
        // or the next launch signs him straight back in.
        await _clear();
        return;
      }
      state = AuthState(user: user);
    } on ApiException catch (e) {
      // statusCode 0 is _send's "could not reach the server", not a verdict on
      // the token. Only an actual refusal signs anyone out.
      if (session == _session && (e.statusCode == 401 || e.statusCode == 403)) {
        await _clearUserData();
        await logout();
      }
    } catch (_) {
      // Same reasoning: a malformed body is not a verdict on the token.
    }
  }

  Future<void> _save(String token, User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> _clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}

/// How any screen reaches the state (`ref.watch`) or the actions (`ref.read(
/// authProvider.notifier)`).
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiProvider), () => clearUserData(ref.read));
});

/// Runs [AuthNotifier.restore] once. `main.dart` waits on it before choosing a
/// screen, so the login screen never flashes over an already-signed-in session.
final authRestoreProvider = FutureProvider<void>((ref) async {
  await ref.read(authProvider.notifier).restore();
});

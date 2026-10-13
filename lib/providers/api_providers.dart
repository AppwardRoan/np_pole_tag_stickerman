import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/services/api_services.dart';

/// One [ApiService] for the whole app, so the token it holds is the same one
/// every caller sends.
final apiProvider = Provider<ApiService>((ref) => ApiService());

import 'package:geolocator/geolocator.dart';

/// Why the phone cannot give a position, in words the crew can act on.
///
/// A plain message rather than an exception: every one of these is something
/// he can fix standing at the pole, and the form shows it as instruction, not
/// as an error.
enum LocationBlock {
  serviceOff(
    'Location is switched off on this phone. Turn it on and try again.',
  ),
  denied('This app was not allowed to use location. Allow it and try again.'),
  deniedForever('Location is blocked for this app. Turn it on in Settings.'),
  unavailable(
    'This phone could not start its GPS. Close the app and open it again.',
  );

  const LocationBlock(this.message);

  final String message;
}

/// Reads where the phone is. Satellites, not the network - it works with no
/// signal, which is the normal state at a pole.
class LocationService {
  const LocationService();

  /// Null when a reading can be taken. Otherwise what is standing in the way.
  ///
  /// Asks for the permission if it has never been asked. Android only prompts
  /// once, so a refusal has to be reported rather than re-prompted.
  Future<LocationBlock?> block() async {
    // Wide on purpose. A build that predates the plugin throws
    // MissingPluginException here, and an unhandled throw showed as a spinner
    // that never stopped - the failure has to reach the screen.
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationBlock.serviceOff;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return switch (permission) {
        LocationPermission.denied => LocationBlock.denied,
        LocationPermission.deniedForever => LocationBlock.deniedForever,
        _ => null,
      };
    } catch (_) {
      return LocationBlock.unavailable;
    }
  }

  /// Readings as they arrive, each one usually tighter than the last.
  ///
  /// A stream rather than a single `getCurrentPosition`: the first fix is rough
  /// - wide enough to cover the pole either side of the one he is at - and the
  /// screen shows it narrowing so he can see when it is worth trusting.
  ///
  /// `distanceFilter: 0` because he is standing still. The updates that matter
  /// are the ones where the accuracy improved, not where he moved.
  Stream<Position> readings() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      ),
    );
  }

  Future<void> openSettings() => Geolocator.openAppSettings();
}

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// The reading as a picture, so he can see the dot is on the right corner
/// rather than trusting six decimal places he cannot check.
///
/// Google, not OpenStreetMap. Google's terms forbid keeping their tiles on the
/// phone, so this map cannot be made to work in a dead spot - it draws grey
/// there. The GPS is untouched by that: the reading, the accuracy and the saved
/// tag all come from the satellites and keep working with no signal. What he
/// loses off-grid is the streets behind the dot, not the location itself.
///
/// Not interactive. He cannot drag the pin: the record has to say where the
/// GPS put him, not where his thumb went. Panning is off too, so the dot is
/// always the thing in the middle.
class MiniMap extends StatefulWidget {
  const MiniMap({required this.latitude, required this.longitude, super.key});

  final double latitude;
  final double longitude;

  @override
  State<MiniMap> createState() => _MiniMapState();
}

class _MiniMapState extends State<MiniMap> {
  GoogleMapController? _controller;

  static const double _zoom = 17;

  LatLng get _here => LatLng(widget.latitude, widget.longitude);

  CameraUpdate get _onHere => CameraUpdate.newLatLngZoom(_here, _zoom);

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;

    // The reading can tighten before the map finishes coming up, and the
    // starting position is read once and never again. Without this the map
    // would open on the rough fix and sit there.
    controller.moveCamera(_onHere);
  }

  @override
  void didUpdateWidget(MiniMap old) {
    super.didUpdateWidget(old);

    // Follows the reading in as it tightens. Without this the map would sit
    // where the first rough fix put it while the dot walked off the edge.
    if (old.latitude != widget.latitude || old.longitude != widget.longitude) {
      _controller?.moveCamera(_onHere);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 190,
        child: ColoredBox(
          // What he sees where Google has nothing to give him - a dead spot, or
          // a key that has not been switched on yet. Better a panel that
          // matches the card than a black hole in the middle of the form.
          color: scheme.surfaceContainerHighest,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: _here,
                  zoom: _zoom,
                ),
                // Every way of moving the map, off. See the class comment.
                zoomGesturesEnabled: false,
                scrollGesturesEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
                compassEnabled: false,
                liteModeEnabled: false,
              ),

              // The dot is a plain widget sitting dead centre rather than a map
              // marker. It can be: the camera is pinned to the reading and he
              // cannot move it, so the centre of the box *is* the pole. Doing
              // it this way keeps the dot looking exactly as it did, which a
              // Google marker - an image file, not a widget - could not.
              IgnorePointer(
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

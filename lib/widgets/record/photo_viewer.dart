import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/models/pole_record.dart';

/// One of the record's shots, full size, swiped between.
///
/// The reason the strip exists at all is that a thumbnail cannot answer the
/// question he opens a record to ask - whether the sticker in the photograph is
/// the one on the pole. So the tap has to reach the whole picture.
Future<void> showPhotoViewer(
  BuildContext context, {
  required List<RecordPhoto> photos,
  int start = 0,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _PhotoViewer(photos: photos, start: start),
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.start});

  final List<RecordPhoto> photos;
  final int start;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pages = PageController(initialPage: widget.start);
  late int _at = widget.start;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_at];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          // "POLE · 2 of 5" — which shot, and how many more there are. The
          // count is what tells him the strip had extras behind it.
          widget.photos.length == 1
              ? photo.label
              : '${photo.label} · ${_at + 1} of ${widget.photos.length}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: .8,
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: widget.photos.length,
        onPageChanged: (index) => setState(() => _at = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            // Pinched into rather than merely shown: the tag code in the photo
            // is four characters on a sticker photographed from the ground.
            maxScale: 5,
            child: Center(
              child: Image.network(
                widget.photos[index].viewUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white54,
                        ),
                      ),
                errorBuilder: (_, _, _) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      'This photograph could not be loaded. It is held on the '
                      'server, so it needs signal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, height: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

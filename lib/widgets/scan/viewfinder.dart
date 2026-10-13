import 'package:flutter/material.dart';

class Viewfinder extends StatelessWidget {
  const Viewfinder({super.key});

  static const _arm = 34.0;
  static const _side = BorderSide(color: Colors.white, width: 5);

  Widget _corner({
    bool top = false,
    bool bottom = false,
    bool left = false,
    bool right = false,
  }) {
    return SizedBox(
      width: _arm,
      height: _arm,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: top ? _side : BorderSide.none,
            bottom: bottom ? _side : BorderSide.none,
            left: left ? _side : BorderSide.none,
            right: right ? _side : BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sized off the camera area, not fixed. A fixed 450 was a third short of
    // where the sticker sits in a photo taken from a sensible distance, so he
    // filled it by stepping in - and the top or bottom letter fell off the
    // edge of the photo. Most of the height, a sticker's narrow width.
    return LayoutBuilder(
      builder: (context, space) {
        final height = space.maxHeight * 0.8;
        final width = (height * 0.32).clamp(130.0, space.maxWidth * 0.6);
        return SizedBox(width: width, height: height, child: _frame());
      },
    );
  }

  Widget _frame() {
    return SizedBox.expand(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _corner(top: true, left: true),
              _corner(top: true, right: true),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _corner(bottom: true, left: true),
              _corner(bottom: true, right: true),
            ],
          ),
        ],
      ),
    );
  }
}

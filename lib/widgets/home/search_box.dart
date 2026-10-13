import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';

/// The field's edge, in whatever colour the state calls for.
OutlineInputBorder _edge(Color colour) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: colour),
  );
}

/// Where he types a code, on the one screen that lists them.
///
/// Uppercased as he types rather than on submit: the codes are printed in
/// capitals, the results are shown in capitals, and a box reading `m006r`
/// under a row reading `M006R` looks like it found something else.
class SearchBox extends StatelessWidget {
  const SearchBox({
    required this.controller,
    required this.onTyped,
    required this.onClear,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onTyped;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        onChanged: (typed) {
          final upper = typed.toUpperCase();

          // Only when it actually changed, or setting the value on every
          // keystroke fights the keyboard's own composing text.
          if (upper != typed) {
            controller.value = controller.value.copyWith(
              text: upper,
              selection: TextSelection.collapsed(offset: upper.length),
            );
          }

          onTyped(upper);
        },
        style: TextStyle(fontSize: 17, color: AppColors.ink),
        decoration: InputDecoration(
          // The magnifier is gone. The box sits under a line that already says
          // "pick from your list", and a field with a hint in it does not need
          // a second icon explaining that it is a field.
          hintText: 'Search tag ID…',
          hintStyle: TextStyle(fontSize: 17, color: AppColors.muted),
          filled: true,
          fillColor: AppColors.card,
          contentPadding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: AppColors.muted,
                  ),
                  onPressed: onClear,
                ),
          border: _edge(AppColors.line),
          enabledBorder: _edge(AppColors.line),
          focusedBorder: _edge(AppColors.midGreen),
        ),
      ),
    );
  }
}

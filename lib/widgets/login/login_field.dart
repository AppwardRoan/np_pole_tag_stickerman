import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';

/// One labelled box on the sign-in screen.
///
/// White on green rather than a dark field on dark green: this screen gets
/// opened in daylight, and the strongest contrast on the phone is the thing
/// that still reads with the sun on it.
///
/// 58 high because he taps it with work gloves on, and what he types is set in
/// the mono face - a username and a password are both strings he has to check
/// character by character when the server says no.
class LoginField extends StatelessWidget {
  const LoginField({
    required this.label,
    required this.controller,
    required this.hint,
    this.enabled = true,
    this.obscure = false,
    this.onToggleObscure,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool enabled;

  /// Null on a field that is not a password, which is what hides the eye.
  final bool obscure;
  final VoidCallback? onToggleObscure;

  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.3,
            color: AppColors.paleGreen,
          ),
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: 58,
          child: TextField(
            controller: controller,
            enabled: enabled,
            obscureText: obscure,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: AppColors.ink,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 20,
                color: Color(0xFF9BA5B1),
              ),
              filled: true,
              fillColor: AppColors.onGreen,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18),
              border: _border,
              enabledBorder: _border,
              focusedBorder: _border.copyWith(
                borderSide: BorderSide(
                  color: AppColors.actionGreen,
                  width: 2,
                ),
              ),
              disabledBorder: _border,
              suffixIcon: onToggleObscure == null
                  ? null
                  : IconButton(
                      onPressed: enabled ? onToggleObscure : null,
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 24,
                        color: AppColors.muted,
                      ),
                      // He is checking a password he cannot see, often with one
                      // hand. A small eye is a missed tap and another wrong
                      // sign-in.
                      tooltip: obscure ? 'Show password' : 'Hide password',
                    ),
            ),
          ),
        ),
      ],
    );
  }

  static final OutlineInputBorder _border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide.none,
  );
}

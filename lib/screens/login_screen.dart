import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/providers/auth_providers.dart';
import 'package:np_pole_tag_stickerman/widgets/login/brand_mark.dart';
import 'package:np_pole_tag_stickerman/widgets/login/login_backdrop.dart';
import 'package:np_pole_tag_stickerman/widgets/login/login_field.dart';

/// The way in. The only screen he sees before the app is his.
///
/// Nothing here navigates: a successful sign-in fills the user in, and the
/// router swaps this screen for the tag list on the next rebuild.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();

  /// Hidden until he asks. He is typing a password into a phone in daylight
  /// with somebody else in the truck.
  bool _hidden = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Trimmed because a phone keyboard picks up trailing spaces constantly.
    // The password is not trimmed - a space in it could be real.
    await ref
        .read(authProvider.notifier)
        .login(_username.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: Stack(
        children: [
          const LoginBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: BrandMark()),
                      const SizedBox(height: 14),
                      Text(
                        'Pole Identification',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onGreen,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'FIELD CREW SIGN-IN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.7,
                          color: AppColors.paleGreen,
                        ),
                      ),

                      const SizedBox(height: 34),

                      LoginField(
                        label: 'Username',
                        controller: _username,
                        hint: 'name or email',
                        enabled: !state.isLoading,
                      ),
                      const SizedBox(height: 14),
                      LoginField(
                        label: 'Password',
                        controller: _password,
                        hint: '',
                        enabled: !state.isLoading,
                        obscure: _hidden,
                        onToggleObscure: () =>
                            setState(() => _hidden = !_hidden),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => state.isLoading ? null : _submit(),
                      ),

                      const SizedBox(height: 22),

                      SizedBox(
                        height: 58,
                        child: ElevatedButton(
                          // Null while loading, which both greys the button out
                          // and makes a second tap impossible.
                          onPressed: state.isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.actionGreen,
                            foregroundColor: AppColors.deepGreen,
                            disabledBackgroundColor: AppColors.greenSurface,
                            disabledForegroundColor: AppColors.mutedGreen,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: state.isLoading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: AppColors.paleGreen,
                                  ),
                                )
                              : const Text(
                                  'SIGN IN',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                        ),
                      ),

                      if (state.error != null) ...[
                        const SizedBox(height: 16),
                        _Refusal(message: state.error!),
                      ],

                      const SizedBox(height: 26),
                      Text(
                        'Sign in once where there is signal. After that the '
                        'app works without it.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: AppColors.mutedGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Why he is not in yet, in the server's own words.
///
/// A panel rather than red text on green: red on dark green is the one pairing
/// that disappears in sunlight, so the message sits on its own pale ground.
class _Refusal extends StatelessWidget {
  const _Refusal({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerWash,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 19, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

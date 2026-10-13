import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/models/form_options.dart';
import 'package:np_pole_tag_stickerman/enums/tag_status.dart';
import 'package:np_pole_tag_stickerman/models/saved_pole.dart';
import 'package:np_pole_tag_stickerman/providers/form_options_providers.dart';
import 'package:np_pole_tag_stickerman/router/app_router.dart';

/// What he sees the moment a pole is filed.
///
/// It replaces a grey snackbar over the tag list, which said "Tag uploaded" for
/// two seconds and left him with no way of checking what had gone. A pole is
/// twenty minutes of work at the top of a ladder; the receipt for it should
/// outlast a snackbar.
///
/// Reads back the record that was saved, not a fresh one off the server. The
/// point is to show him his work in the dead spot where he did it.
///
/// Its two buttons are the two things he actually does next: the next pole, or
/// back to the list. There is no back arrow - the form behind this screen has
/// been submitted and replaced, and returning to it would offer him a second
/// go at a pole already filed.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({required this.pole, super.key});

  final SavedPole pole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(formOptionsProvider).value;

    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.deepGreen,
        foregroundColor: AppColors.onGreen,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'POLE TAGGED',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: AppColors.paleGreen,
              ),
            ),
            Text(
              'Saved',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          _Banner(pole: pole),
          const SizedBox(height: 14),
          _Recorded(pole: pole, options: options),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // Stretched, or each button shrinks to the width of its own label and
          // sits marooned in the middle of the screen.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                // Straight back to the camera, carrying no tag: the next
                // sticker is what names the next pole. This is the button he
                // presses forty times a day, so it is the one under his thumb.
                onPressed: () => context.pushReplacement(Routes.scan),
                icon: const Icon(Icons.crop_free, size: 20),
                label: const Text(
                  'Scan next pole',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () => context.go(Routes.tags),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  backgroundColor: AppColors.card,
                  side: BorderSide(color: AppColors.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back to list',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tick, the tag, and where the record actually is.
class _Banner extends StatelessWidget {
  const _Banner({required this.pole});

  final SavedPole pole;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.chipGreenWash,
        border: Border.all(color: AppColors.chipGreenLine),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.amber,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pole.tagCode,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // Which of the two states he is in, said plainly. "Saved" on
                  // its own let a man walk out of signal believing the office
                  // had a pole that was still sitting in his pocket.
                  pole.queued
                      ? 'Saved on this phone · will upload when there is signal'
                      : 'Saved · the office has it'
                        '${pole.batchCode == null ? '' : ' · ${pole.batchCode}'}',
                  style: TextStyle(fontSize: 15.5, color: AppColors.midGreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Everything that was filed, in the order the form asked for it.
class _Recorded extends StatelessWidget {
  const _Recorded({required this.pole, this.options});

  final SavedPole pole;
  final FormOptions? options;

  String _label(List<FormOption>? list, dynamic id) {
    if (id is! int || list == null) return '—';

    for (final option in list) {
      if (option.id == id) return option.label;
    }
    return '—';
  }

  static String _trim(num value) {
    final text = value.toStringAsFixed(2);
    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String get _where {
    final lat = pole.record['latitude'];
    final lng = pole.record['longitude'];
    if (lat is! num || lng is! num) return '—';

    return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }

  String get _accuracy {
    final accuracy = pole.record['gps_accuracy'];
    return accuracy is num ? '± ${_trim(accuracy)} m' : '—';
  }

  /// "Lattice · 40 ft (12.19 m)" - the type and the height on one line, the
  /// way the pole itself is described out loud.
  String get _pole {
    final type = _label(options?.poleTypes, pole.record['pole_type_id']);
    final ft = pole.record['height_ft'];
    final m = pole.record['height_m'];

    if (ft is! num && m is! num) return type;

    final height = [
      if (ft is num) '${_trim(ft)} ft',
      if (m is num) '(${_trim(m)} m)',
    ].join(' ');

    return type == '—' ? height : '$type · $height';
  }

  @override
  Widget build(BuildContext context) {
    final remarks = (pole.record['remarks'] as String?)?.trim();

    // Which trip this was, and so which rows he was actually asked for. See
    // [SavedPole.sentBackFor].
    final photosOnly = pole.sentBackFor == TagStatus.reCapture;
    final pinOnly = pole.sentBackFor == TagStatus.rePin;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(0, 14, 0, 4),
            child: Text(
              'RECORDED',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.muted,
              ),
            ),
          ),
          // Everything he was asked, and nothing he was not.
          //
          // A partial trip asks for one thing and a note. The rest went up
          // null - the office keeps what the visit this replaces already had -
          // and drawing them anyway printed a column of dashes under the word
          // RECORDED, which reads as a pole filed empty by a man who has just
          // been told his work was saved.
          //
          // A redo is not a partial trip: he answered everything again, so it
          // reports everything, the same as a first capture.
          if (!pinOnly && !photosOnly) ...[
            _Line(
              'DU owned',
              _label(options?.duOwnedOptions, pole.record['du_owned_option_id']),
            ),
            _Line('Telco attachment',
                _label(options?.telcoOptions, pole.record['telco_option_id'])),
            _Line(
              'Streetlight attachment',
              _label(
                options?.streetlightOptions,
                pole.record['streetlight_option_id'],
              ),
            ),
            _Line('Pole', _pole),
            _Line(
              'Asset type',
              describeAssetTypes(
                pole.record['asset_types'],
                options?.assetTypes,
              ),
            ),
            _Line(
              'Condition',
              _label(options?.poleConditions, pole.record['pole_condition_id']),
            ),
          ],
          // The reading is the whole of a re-pin, so it leads on one.
          if (!photosOnly) ...[
            _Line('Location', _where),
            _Line('GPS accuracy', _accuracy),
          ],
          // Not on a re-pin: he pointed no camera, and "0 captured" under a
          // pole photographed weeks ago reads as work he failed to do. The
          // office carries the shots across to the new record.
          if (!pinOnly) _Line('Photos', '${pole.photos} captured'),
          _Line(
            'Remarks',
            remarks == null || remarks.isEmpty ? '—' : remarks,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF1F3F7))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 16.5, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

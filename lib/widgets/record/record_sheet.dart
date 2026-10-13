import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/models/form_options.dart';
import 'package:np_pole_tag_stickerman/models/pole_record.dart';
import 'package:np_pole_tag_stickerman/providers/form_options_providers.dart';
import 'package:np_pole_tag_stickerman/providers/record_providers.dart';
import 'package:np_pole_tag_stickerman/widgets/record/photo_viewer.dart';

/// Opens the record the office holds for one pole.
///
/// A sheet rather than a screen: he is checking a row on a list he means to
/// carry on reading, and a sheet keeps that list behind it. It comes up most of
/// the way and drags to the top, because the record is longer than a glance -
/// eight facts, however many photographs, and whatever it replaced.
Future<void> showRecordSheet(
  BuildContext context, {
  required int tagId,
  required String tagCode,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C080E0A),
    builder: (_) => RecordSheet(tagId: tagId, tagCode: tagCode),
  );
}

class RecordSheet extends ConsumerStatefulWidget {
  const RecordSheet({required this.tagId, required this.tagCode, super.key});

  final int tagId;
  final String tagCode;

  @override
  ConsumerState<RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends ConsumerState<RecordSheet> {
  /// Which record is on show. Null is the live one, which is what it opens on;
  /// tapping an earlier attempt puts that record's id here and the sheet reads
  /// the same way round it.
  ///
  /// Held as an id rather than as the record itself so a refresh cannot leave
  /// the sheet showing a row the server no longer sends.
  int? _showing;

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(tagRecordsProvider(widget.tagId));

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.page,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            children: [
              const _Grab(),
              Expanded(
                child: records.when(
                  loading: () => const _Centred(
                    child: CircularProgressIndicator(strokeWidth: 2.6),
                  ),
                  // Almost always no signal rather than a real failure, so the
                  // message says the thing he can act on. The record is on the
                  // server by definition - it is what the office holds - so
                  // there is nothing on the phone to fall back to.
                  error: (_, _) => _Centred(
                    child: _Message(
                      icon: Icons.cloud_off,
                      title: 'Cannot reach the office',
                      detail:
                          'This record is held on the server. Move to where '
                          'there is signal and open it again.',
                      onRetry: () =>
                          ref.invalidate(tagRecordsProvider(widget.tagId)),
                    ),
                  ),
                  data: (rows) => _loaded(rows, scroll),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _loaded(List<PoleRecord> rows, ScrollController scroll) {
    if (rows.isEmpty) {
      // The tag says filed and the server holds nothing against it. Rare, and
      // worth saying plainly rather than showing an empty form.
      return const _Centred(
        child: _Message(
          icon: Icons.description_outlined,
          title: 'No record filed',
          detail: 'The office is holding nothing against this pole.',
        ),
      );
    }

    // The one on show: the earlier attempt he tapped, or the live record. The
    // fallback covers a refresh that dropped the row he was reading.
    final shown = rows.firstWhere(
      (r) => _showing == null ? r.isCurrent : r.recordId == _showing,
      orElse: () => rows.first,
    );

    final options = ref.watch(formOptionsProvider).value;

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        _Header(
          code: shown.tagCode ?? widget.tagCode,
          current: shown.isCurrent,
          // Only shown while an earlier record is open, and it is the way back
          // rather than the way out: closing the sheet from here would make him
          // reopen the pole to see the record that matters.
          onBack: _showing == null ? null : () => setState(() => _showing = null),
        ),
        if (shown.photos.isNotEmpty) _PhotoStrip(photos: shown.photos),
        _Facts(record: shown, options: options),
        // Every visit, including the one on screen, and only on a pole that
        // has had more than one. A single-record pole is nearly every pole,
        // and a list of one under a heading is furniture.
        if (rows.length > 1)
          _Earlier(
            records: rows,
            showing: shown.recordId,
            onOpen: (id) {
              setState(() => _showing = id);

              // Back to the top with it. The list is at the bottom of the
              // sheet and the record it swaps is at the top, so tapping a row
              // changed something he was not looking at - the facts, the
              // photographs and the chip saying REPLACED all sit above the
              // fold. He tapped to read that record; this is what shows it to
              // him.
              if (scroll.hasClients) {
                scroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                );
              }
            },
          ),
      ],
    );
  }
}

class _Grab extends StatelessWidget {
  const _Grab();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.fieldLine,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.code, required this.current, this.onBack});

  final String code;
  final bool current;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(onBack == null ? 16 : 4, 0, 16, 12),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 20),
              color: AppColors.ink,
              tooltip: 'Back to the current record',
            ),
          Text(
            code,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.ink,
            ),
          ),
          const Spacer(),
          // Which of the pole's records this is. Without it an earlier attempt
          // reads exactly like the live one, and he would be checking his work
          // against a record the office replaced.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: current ? AppColors.chipGreenWash : AppColors.line,
              border: Border.all(
                color: current ? AppColors.chipGreenLine : AppColors.fieldLine,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              current ? 'CURRENT' : 'REPLACED',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
                color: current ? AppColors.chipGreenInk : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The shots, in a row he can push sideways.
///
/// Not three fixed boxes: three are required, and any number of extras may sit
/// behind them, so the strip has to grow rather than crop.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photos});

  final List<RecordPhoto> photos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final photo = photos[index];

          return GestureDetector(
            onTap: () => showPhotoViewer(context, photos: photos, start: index),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.network(
                    photo.viewUrl,
                    width: 92,
                    height: 76,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) =>
                        progress == null ? child : const _Thumb(),
                    errorBuilder: (_, _, _) =>
                        const _Thumb(icon: Icons.broken_image_outlined),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  photo.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.icon});

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 76,
      color: AppColors.line,
      alignment: Alignment.center,
      child: icon == null
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 20, color: AppColors.muted),
    );
  }
}

/// What he filed, one line each.
class _Facts extends StatelessWidget {
  const _Facts({required this.record, this.options});

  final PoleRecord record;
  final FormOptions? options;

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// "Sep 15, 2026 · 9:12am". The same shape the batch list writes, so two
  /// screens showing the same moment agree.
  static String when(DateTime at) {
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');
    final ampm = at.hour < 12 ? 'am' : 'pm';

    return '${_months[at.month - 1]} ${at.day}, ${at.year} · $hour:$minute$ampm';
  }

  /// The label for an id, or a plain dash.
  ///
  /// Reads the choices cached for the form. A handset that has never been
  /// online has none, and an id with no list behind it is printed as "—"
  /// rather than as a number: "Pole type 2" tells him nothing.
  String _label(List<FormOption>? list, int? id) {
    if (id == null || list == null) return '—';

    for (final option in list) {
      if (option.id == id) return option.label;
    }
    return '—';
  }

  String get _height {
    final ft = record.heightFt;
    final m = record.heightM;
    if (ft == null && m == null) return '—';

    final parts = <String>[
      if (ft != null) '${_trim(ft)} ft',
      if (m != null) '${_trim(m)} m',
    ];
    return parts.join(' · ');
  }

  /// 35.0 reads as "35", 10.67 stays as it is. The server stores both as
  /// decimals, and a pole is not 35.00 feet tall in anybody's speech.
  static String _trim(double value) {
    final text = value.toStringAsFixed(2);
    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String get _where {
    final lat = record.latitude;
    final lng = record.longitude;
    if (lat == null || lng == null) return '—';

    return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
    final at = record.createdAt;
    final accuracy = record.gpsAccuracy;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _Fact('Pole type', _label(options?.poleTypes, record.poleTypeId)),
          _Fact(
            'Asset type',
            describeAssetTypes(record.assetTypes, options?.assetTypes),
          ),
          _Fact('Height', _height),
          _Fact(
            'Condition',
            _label(options?.poleConditions, record.poleConditionId),
          ),
          _Fact(
            'DU owned',
            _label(options?.duOwnedOptions, record.duOwnedOptionId),
          ),
          _Fact('Telco', _label(options?.telcoOptions, record.telcoOptionId)),
          _Fact(
            'Streetlight',
            _label(options?.streetlightOptions, record.streetlightOptionId),
          ),
          _Fact('Location', _where),
          if (accuracy != null) _Fact('Accuracy', '± ${_trim(accuracy)} m'),
          _Fact('Filed', at == null ? '—' : when(at)),
          _Fact('Remarks', record.remarks?.trim().isNotEmpty == true
              ? record.remarks!.trim()
              : '—', last: true),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF1F3F7))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(fontSize: 17, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 17,
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

/// Every visit this pole has had, newest first.
///
/// Absent on nearly every pole: a record is replaced only when the office sends
/// one back to be done again. Tapping a row reads it above.
///
/// The row on screen stays in the list and is marked rather than removed from
/// it. Leaving it out meant the list changed under his thumb - tap an earlier
/// visit and it vanished, while the live record appeared in its place - so the
/// rows he was choosing between were never the same rows twice. A history that
/// reorders itself as it is read is one nobody can hold in their head.
class _Earlier extends StatelessWidget {
  const _Earlier({
    required this.records,
    required this.showing,
    required this.onOpen,
  });

  final List<PoleRecord> records;

  /// The record drawn above, marked here so he can see where he is.
  final int showing;

  final void Function(int recordId) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(18, 20, 18, 8),
          child: Text(
            'ALL RECORDS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: AppColors.muted,
            ),
          ),
        ),
        for (final record in records)
          Builder(
            builder: (context) {
              final open = record.recordId == showing;

              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 7),
                child: Material(
                  color: open ? AppColors.chipGreenWash : AppColors.card,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(11),
                    onTap: open ? null : () => onOpen(record.recordId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: open
                              ? AppColors.chipGreenLine
                              : AppColors.line,
                        ),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              record.createdAt == null
                                  ? 'Earlier record'
                                  : _Facts.when(record.createdAt!),
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          Text(
                            record.isCurrent ? 'current' : 'replaced',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.muted,
                            ),
                          ),
                          // No arrow on the row already open: it would point
                          // at a place he is standing in. Nothing takes its
                          // place - the tint is what says he is here, and a
                          // second mark saying the same thing is one more
                          // thing to read.
                          if (!open)
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppColors.muted,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _Centred extends StatelessWidget {
  const _Centred({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(24), child: child));
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: AppColors.fieldLine),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            height: 1.45,
            color: AppColors.muted,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 14),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: AppColors.midGreen),
            child: const Text(
              'Try again',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}

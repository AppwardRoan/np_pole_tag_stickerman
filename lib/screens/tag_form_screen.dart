import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/enums/photo_type.dart';
import 'package:np_pole_tag_stickerman/enums/tag_status.dart';
import 'package:np_pole_tag_stickerman/models/draft_tag.dart';
import 'package:np_pole_tag_stickerman/models/form_options.dart';
import 'package:np_pole_tag_stickerman/models/queued_tag.dart';
import 'package:np_pole_tag_stickerman/models/saved_pole.dart';
import 'package:np_pole_tag_stickerman/models/tag.dart';
import 'package:np_pole_tag_stickerman/providers/draft_providers.dart';
import 'package:np_pole_tag_stickerman/providers/form_options_providers.dart';
import 'package:np_pole_tag_stickerman/providers/tag_providers.dart';
import 'package:np_pole_tag_stickerman/providers/auth_providers.dart';
import 'package:np_pole_tag_stickerman/providers/upload_providers.dart';
import 'package:np_pole_tag_stickerman/router/app_router.dart';
import 'package:np_pole_tag_stickerman/screens/shots_screen.dart';
import 'package:np_pole_tag_stickerman/services/location_service.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/condition_card.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/height_card.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/asset_type_card.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/pole_type_card.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/location_card.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/question_card.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/remarks_card.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/scan_banner.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/shots_panel.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/form_complaint.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/form_message.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/step_dots.dart';

/// One step of the record, in the order the mockup walks him through them.
///
/// The mockup's first step, the tag photo, is not here: the scan already
/// confirmed the sticker before this screen opened. Photos joins the list once
/// there is somewhere to keep the files.
enum _Step {
  location('Location'),
  pole('Pole details'),
  photos('Asset photos'),
  remarks('Remarks');

  const _Step(this.title);

  final String title;
}

/// The answers a step will not let him past without.
///
/// Named rather than checked twice: the complaint under the button and the
/// red boxes both read the same list, so neither can ask for something the
/// other does not.
enum _Field {
  location,
  duOwned,
  telco,
  streetlight,
  poleType,
  assetType,
  assetTypeOther,
  height,
  condition,
  photos,
}

class TagFormScreen extends ConsumerStatefulWidget {
  const TagFormScreen({super.key, this.tag});

  /// Null only when the screen is rebuilt after a restart, which cannot carry
  /// the tag across. Nothing can be filled in without knowing the tag, so it
  /// says so rather than showing an empty form.
  final Tag? tag;

  @override
  ConsumerState<TagFormScreen> createState() => _TagFormScreenState();
}

class _TagFormScreenState extends ConsumerState<TagFormScreen> {
  /// What he tapped, held as the option's own id rather than a bool: "Yes" is
  /// 1 for Negros Power and 3 for BP, and the record stores whichever row the
  /// server handed over.
  int? _telcoOptionId;
  int? _streetlightOptionId;
  int? _duOwnedOptionId;
  int? _poleTypeId;
  int? _poleConditionId;

  final _remarks = TextEditingController();

  /// Asset type is "select all that apply", so a set of ids rather than one.
  final Set<int> _assetTypeIds = {};

  /// What he typed after ticking Others. Kept while Others is unticked, so
  /// ticking it back does not make him type it again; only sent while ticked.
  final _assetTypeOther = TextEditingController();

  /// The photos he has taken, in the order he took them.
  ///
  /// Copied somewhere permanent the moment the camera closes, not at submit:
  /// a draft left overnight would otherwise come back with its photos cleared
  /// out of the camera's cache folder.
  List<QueuedPhoto> _photos = const [];

  /// Just their paths, which is all the camera and the photo card need.
  List<String> get _shots => [for (final photo in _photos) photo.path];

  /// Whether the camera has already opened itself on this step. It opens once
  /// on arrival; after that he asks for it. Re-opening every time he steps back
  /// would trap him behind a camera he is trying to leave.
  bool _cameraOffered = false;

  /// Stops a double-tap on the last step queueing the same tag twice while
  /// the photos are still being copied.
  bool _submitting = false;

  int _at = 0;

  /// The complaint from the step he was stopped on, cleared the moment he
  /// moves. Held here rather than inside each card so two lines can never
  /// contradict each other.
  _Step? _errorAt;

  /// Feet and metres are the same fact twice, and the table keeps both columns.
  /// Typing in either box fills the other, so whichever unit he thinks in is
  /// the one he uses.
  final _feet = TextEditingController();
  final _metres = TextEditingController();

  static const double _feetPerMetre = 0.3048;

  static const _location = LocationService();

  /// The tightest reading so far, not the latest. GPS wanders: a later fix can
  /// be worse than an earlier one, and replacing a 3 m reading with an 8 m one
  /// would be a step backwards he can see happening.
  Position? _best;
  LocationBlock? _blocked;
  StreamSubscription<Position>? _readings;

  /// When the draft last reached the phone, and the line under the form that
  /// says so.
  ///
  /// Shown rather than kept quiet because the answer to "can I close this?" was
  /// only ever knowable by trying it. He works under a pole with a handset that
  /// overheats, and a form he is afraid to leave is a form he rushes.
  DateTime? _savedAt;

  /// The save waiting to happen, a moment after he stops.
  ///
  /// Every answer starts one: a choice tapped, a height typed, a photo taken.
  /// The timer is what stops a typed height writing the draft once per letter -
  /// it is one save after he lifts his thumb, not eight while it is down.
  Timer? _pending;

  @override
  void initState() {
    super.initState();

    // Typed rather than tapped, so there is no onPick to hang the save on.
    _remarks.addListener(_touched);
    _assetTypeOther.addListener(_touched);

    // Put back before the first frame, not after it. The tag list is already
    // holding the drafts - it read them to mark this row "Unfinished" - so
    // going to the phone for a second copy only buys a blank step 1 that
    // corrects itself a frame later, which reads as the app lagging.
    _start(restored: _apply(_draftInHand()));
  }

  /// This tag's draft out of the copy the tag list already has.
  ///
  /// Null when the list never loaded, which is a form reached without passing
  /// through it - see [_start] for what happens then.
  DraftTag? _draftInHand() {
    final tag = widget.tag;
    if (tag == null) return null;

    for (final draft in ref.read(draftProvider).drafts) {
      if (draft.tagId == tag.tagId) return draft;
    }

    return null;
  }

  /// The draft first, then the GPS.
  ///
  /// In that order because [_fix] clears the fix it is about to replace, and
  /// doing that after a restore would throw away the reading he took while
  /// standing at the pole.
  Future<void> _start({required bool restored}) async {
    var hasFix = restored;

    // Nothing in hand means the list never loaded, so its copy is empty. Worth
    // one read off the phone: a blank form would cost him the work, and a
    // flash he only sees on a path he rarely takes costs him nothing.
    if (!restored) {
      final tag = widget.tag;

      final draft = tag == null
          ? null
          : await ref.read(draftProvider.notifier).find(tag.tagId);

      if (!mounted) return;
      if (draft != null) setState(() => hasFix = _apply(draft));
    }

    // No reading taken on a re-capture, and that is the point rather than a
    // saving. The pole's pin is not being changed - a fix taken here would be
    // sent with the record and would move it, quietly, to wherever he happened
    // to be standing when the form opened. Left null, the server keeps the one
    // already on file.
    //
    // A re-pin is the opposite: the reading is the whole of what he came for.
    if (_photosOnly) return;

    await _fix(keepCurrent: hasFix);
  }

  /// Puts [draft] back into the form, at the step he left it on.
  ///
  /// Sets the fields straight rather than through `setState`, so it can run
  /// from `initState` before the first frame. The one caller that runs later
  /// wraps it itself.
  ///
  /// Returns whether it put back a fix, so [_start] knows not to clear the one
  /// it has just restored.
  bool _apply(DraftTag? draft) {
    if (draft == null) return false;

    final record = draft.record;
    final latitude = record['latitude'];
    final longitude = record['longitude'];

    _at = draft.step;
    _photos = draft.photos;

    _poleTypeId = record['pole_type_id'] as int?;
    _poleConditionId = record['pole_condition_id'] as int?;
    _telcoOptionId = record['telco_option_id'] as int?;
    _streetlightOptionId = record['streetlight_option_id'] as int?;
    _duOwnedOptionId = record['du_owned_option_id'] as int?;
    // A draft saved before asset type became a list carries `asset_type_id`
    // instead, from a menu that no longer exists. Dropped: he re-ticks it,
    // and the red box says so.
    _assetTypeIds.clear();
    // `Map`, not `Map<String, dynamic>`: Hive hands the draft back keyed
    // loosely, and the stricter cast threw opening any pole with a draft.
    final ticks = record['asset_types'];
    for (final row in ticks is List ? ticks.whereType<Map>() : const <Map>[]) {
      final id = row['asset_type_id'];
      if (id is int) _assetTypeIds.add(id);
      final text = row['other_text'];
      if (text is String) _assetTypeOther.text = text;
    }

    _feet.text = _text(record['height_ft'], 1);
    _metres.text = _text(record['height_m'], 2);
    _remarks.text = (record['remarks'] as String?) ?? '';

    // He has been behind the camera already on this form. Opening it again
    // on arrival would trap him in it rather than show him what he had.
    _cameraOffered = _photos.isNotEmpty;

    // Rebuilt as a Position so everything downstream - the map, the
    // validation, the record - carries on unchanged.
    if (latitude is num && longitude is num) {
      final accuracy = record['gps_accuracy'];

      _best = Position(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
        accuracy: accuracy is num ? accuracy.toDouble() : 0,
        timestamp: draft.savedAt,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    return _best != null;
  }

  /// A height back out of the record and into its box, without the trailing
  /// zeroes a raw `toString` would show him.
  static String _text(dynamic value, int places) {
    return value is num ? value.toDouble().toStringAsFixed(places) : '';
  }

  /// [keepCurrent] is for the fix restored from a draft: it was taken while he
  /// was standing at the pole, so it stays until a tighter live reading beats
  /// it. Re-fixing by hand still clears it, which is the point of that button.
  Future<void> _fix({bool keepCurrent = false}) async {
    await _readings?.cancel();

    if (!mounted) return;
    _readings = null;
    setState(() {
      if (!keepCurrent) _best = null;
      _blocked = null;
    });

    final blocked = await _location.block();

    if (!mounted) return;
    if (blocked != null) {
      setState(() => _blocked = blocked);
      return;
    }

    final subscription = _location.readings().listen(
      (position) {
        final best = _best;
        if (best != null && best.accuracy <= position.accuracy) return;
        setState(() => _best = position);

        // The fix is the one answer he does not type, and the one he would be
        // sorriest to lose - it is only true while he is standing at the pole.
        _touched();
      },
      onError: (_) {
        // Only when nothing has been read yet. Once a fix is on screen a later
        // failure is not worth throwing it away for - he can still record the
        // pole with the reading he has.
        if (_best == null && mounted) {
          setState(() => _blocked = LocationBlock.unavailable);
        }
      },
    );

    if (!mounted) {
      await subscription.cancel();
      return;
    }

    _readings = subscription;
  }

  /// A typed number, reading a comma as the decimal point - Samsung's decimal
  /// pad offers one, and "35," used to be read as no height at all.
  static double? _number(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  /// A height the office will take: above 0, and no more than the server's own
  /// cap of 999. Anything else used to pass Next and be refused hours later.
  static double? _height(String text) {
    final value = _number(text);
    if (value == null || value <= 0 || value > 999) return null;
    return value;
  }

  void _onFeet(String value) {
    final feet = _number(value);
    _metres.text = feet == null
        ? ''
        : (feet * _feetPerMetre).toStringAsFixed(2);
    setState(() {});
    _touched();
  }

  void _onMetres(String value) {
    final metres = _number(value);
    _feet.text = metres == null
        ? ''
        : (metres / _feetPerMetre).toStringAsFixed(1);
    setState(() {});
    _touched();
  }

  void _pickHeight(int feet) {
    _feet.text = feet.toString();
    _metres.text = (feet * _feetPerMetre).toStringAsFixed(2);
    setState(() {});
    _touched();
  }

  /// Which trip this is, or null for an ordinary first capture.
  ///
  /// The office sends a pole back saying what has to be put right, and the
  /// word decides what he is asked for when he gets there. It is the tag's own
  /// status, so nothing on this screen has to be told.
  String? get _sentBackFor {
    final status = widget.tag?.status;
    return TagStatus.rework.contains(status) ? status : null;
  }

  /// Sent back for its photographs and nothing else.
  bool get _photosOnly => _sentBackFor == TagStatus.reCapture;

  /// Sent back for its position and nothing else.
  bool get _pinOnly => _sentBackFor == TagStatus.rePin;

  /// The steps this form actually walks, which is not always all of them.
  ///
  /// A partial trip asks for the one thing that was wrong and a note, and
  /// stops there. Putting the other steps in front of him would be asking him
  /// to copy his own answers back in while standing at a pole he came to do
  /// one thing at — and what he is not asked, he does not send: those fields
  /// go up null and the server fills them from the record this one replaces.
  ///
  /// Deliberately not carried on the phone. A copy taken when the pole was
  /// handed to him would overwrite an office correction made while he was
  /// driving out.
  ///
  /// [_at] indexes this rather than `_Step.values`, so a two-step form counts
  /// "STEP 1 OF 2" and draws two dots. The enum stays the full list — it is
  /// the vocabulary, not the route.
  ///
  /// A redo walks all four. It is a fresh capture; he is asked everything
  /// again because everything is being filed again.
  List<_Step> get _steps {
    if (_photosOnly) return const [_Step.photos, _Step.remarks];
    if (_pinOnly) return const [_Step.location, _Step.remarks];
    return _Step.values;
  }

  _Step get _step => _steps[_at];

  bool get _hasDuOwnedChoices =>
      ref.read(formOptionsProvider).valueOrNull?.duOwnedOptions.isNotEmpty ??
      false;

  bool get _hasAssetTypeChoices =>
      ref.read(formOptionsProvider).valueOrNull?.assetTypes.isNotEmpty ?? false;

  /// The id of this organization's Others, or null if the phone has no menu.
  int? get _otherAssetTypeId {
    final menu = ref.read(formOptionsProvider).valueOrNull?.assetTypes;
    for (final option in menu ?? const <FormOption>[]) {
      if (isOtherAssetType(option)) return option.id;
    }
    return null;
  }

  bool get _otherTicked {
    final other = _otherAssetTypeId;
    return other != null && _assetTypeIds.contains(other);
  }

  bool get _onLastStep => _at == _steps.length - 1;

  /// Everything [step] is still waiting on, in the order the boxes appear.
  ///
  /// Pole condition is in here. The mockup marks it optional; his call was to
  /// demand it, so the office gets a looked-at answer rather than a blank it
  /// cannot tell from a pole nobody inspected.
  List<_Field> _missingIn(_Step step) {
    return switch (step) {
      // The two attachment questions belong to a first capture. A re-pin is
      // the map and the calibration; demanding an answer about a telco cable
      // would stop a man who came to move a pin, over a box he was not shown.
      _Step.location => [
        if (_best == null) _Field.location,
        // A weak fix is warned about on the card, not blocked: under trees or
        // indoors a phone can sit below the line for minutes, and he cannot
        // file a pole he is standing at. His call, 2026-10-02.
        // Only asked when the phone has the choices. A copy saved before this
        // question existed has none, and demanding an answer he cannot give
        // would stop him at the pole until he found signal.
        if (!_pinOnly && _hasDuOwnedChoices && _duOwnedOptionId == null)
          _Field.duOwned,
        if (!_pinOnly && _telcoOptionId == null) _Field.telco,
        if (!_pinOnly && _streetlightOptionId == null) _Field.streetlight,
      ],
      _Step.pole => [
        if (_poleTypeId == null) _Field.poleType,
        // Same rule as DU owned: not asked of a phone without the choices.
        if (_hasAssetTypeChoices && _assetTypeIds.isEmpty) _Field.assetType,
        if (_otherTicked && _assetTypeOther.text.trim().isEmpty)
          _Field.assetTypeOther,
        if (_height(_feet.text) == null) _Field.height,
        if (_poleConditionId == null) _Field.condition,
      ],
      _Step.photos => [if (_shots.length < ShotsScreen.required) _Field.photos],
      _Step.remarks => const [],
    };
  }

  /// What is missing from [step], in the mockup's own words. Null when done.
  ///
  /// Names the first one only. The red boxes show him the rest at a glance;
  /// a stack of complaints under the button would just be a wall to read.
  String? _missingFrom(_Step step) {
    final missing = _missingIn(step);

    if (missing.isEmpty) return null;

    return switch (missing.first) {
      _Field.location => 'Location not captured yet.',
      _Field.duOwned => 'Select Owned or Not owned.',
      _Field.telco => 'Select Yes or No for telco attachment.',
      _Field.streetlight => 'Select Yes or No for streetlight attachment.',
      _Field.poleType => 'Select the pole type.',
      _Field.assetType => 'Select at least one asset type.',
      _Field.assetTypeOther => 'Please specify the asset type for Others.',
      _Field.height => 'Enter the pole height.',
      _Field.condition => 'Select the pole condition.',
      _Field.photos =>
        'Capture the ${ShotsScreen.required} required shots '
            '(${_shots.length} of ${ShotsScreen.required} done).',
    };
  }

  /// Which boxes to draw red: what is missing, but only once he has tried to
  /// leave the step.
  ///
  /// Arriving to a screen already red would read as him having done something
  /// wrong, when he has not done anything yet. It is also live - answering one
  /// clears that box on the next build without him tapping Next again.
  Set<_Field> _flagged(_Step step) =>
      _errorAt == step ? _missingIn(step).toSet() : const {};

  /// The line under the button, worked out fresh on every build.
  ///
  /// Held as a stored string once, which went stale the moment he answered:
  /// the box cleared and the words underneath still named the field he had
  /// just filled in. Only the step it belongs to is remembered now.
  String? get _complaint => _errorAt == _step ? _missingFrom(_step) : null;

  /// Opens the camera over the form and keeps whatever comes back.
  ///
  /// Cancel and Done both return the shots, so a stray back-swipe at a pole
  /// cannot throw away three photos he has already taken.
  /// Drops a spare shot and the copy of it on the phone.
  ///
  /// Guarded as well as hidden: the X only appears on the last two tiles, and
  /// a required shot arriving here anyway would slide the one below it into a
  /// slot the office reads as a different kind of photo.
  Future<void> _removePhoto(int index) async {
    if (index < ShotsScreen.required || index >= _photos.length) return;

    final dropped = _photos[index].path;

    setState(() => _photos = [..._photos]..removeAt(index));

    final store = await ref.read(photoStoreProvider.future);
    await store.discard([dropped]);

    if (mounted) await _saveDraft();
  }

  /// [retake] opens straight onto a shot he already has, so the next press of
  /// the shutter replaces that one instead of adding a sixth.
  Future<void> _openCamera({int? retake}) async {
    final shots = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => ShotsScreen(taken: _shots, replacing: retake),
      ),
    );

    if (!mounted || shots == null) return;

    final store = await ref.read(photoStoreProvider.future);
    final kept = <QueuedPhoto>[];

    for (final (index, path) in shots.indexed) {
      // Ones already copied come back by the same path. Copying again would
      // leave two files on the phone and upload the shot twice.
      final already = _photoAt(path);

      if (already != null) {
        kept.add(already);
        continue;
      }

      // More shots than named slots should be impossible - ShotsScreen stops
      // at five - but a crash at the pole is not the place to find out.
      final type = index < PhotoType.bySlot.length
          ? PhotoType.bySlot[index]
          : PhotoType.extra;

      kept.add(
        QueuedPhoto(
          path: await store.keep(path, type),
          photoType: type,
          takenAt: DateTime.now(),
        ),
      );
    }

    if (!mounted) return;

    // A shot he retook or removed leaves its copy behind. Nothing points at it
    // any more, so without this it sits on the phone until the app is
    // uninstalled - and these are full-size pole photos, not thumbnails.
    final keeping = {for (final photo in kept) photo.path};

    final dropped = [
      for (final photo in _photos)
        if (!keeping.contains(photo.path)) photo.path,
    ];

    // The complaint clears itself now that it is worked out per build - the
    // third shot landing is what makes it stop asking for a third shot.
    setState(() => _photos = kept);

    await store.discard(dropped);
    await _saveDraft();
  }

  QueuedPhoto? _photoAt(String path) {
    for (final photo in _photos) {
      if (photo.path == path) return photo;
    }
    return null;
  }

  /// The body `POST /pole-records` wants, however much of it he has filled in.
  ///
  /// Shared by the draft and the submit so the two can never disagree about
  /// what a pole record is.
  Map<String, dynamic> _record(Tag tag) {
    final remarks = _remarks.text.trim();

    return {
      'tag_id': tag.tagId,
      'latitude': _best?.latitude,
      'longitude': _best?.longitude,
      'gps_accuracy': _best?.accuracy,
      'pole_type_id': _poleTypeId,
      'pole_condition_id': _poleConditionId,
      'telco_option_id': _telcoOptionId,
      'streetlight_option_id': _streetlightOptionId,
      'du_owned_option_id': _duOwnedOptionId,
      'asset_types': [
        for (final id in _assetTypeIds.toList()..sort())
          {
            'asset_type_id': id,
            if (id == _otherAssetTypeId)
              'other_text': _assetTypeOther.text.trim(),
          },
      ],
      'height_ft': _height(_feet.text),
      'height_m': _height(_metres.text),
      'remarks': remarks.isEmpty ? null : remarks,
    };
  }

  /// Throws this form away - the answers, the photos, and the draft on the
  /// phone - and puts him back on the list.
  ///
  /// The way out of a form he did not mean to start: a sticker scanned by
  /// mistake, or a pole somebody else has already done. Without it the only way
  /// to clear the row was to finish a pole he was never sent to, because
  /// leaving keeps the draft on purpose.
  ///
  /// Nothing on the server is touched, because nothing has reached it. A scan
  /// files no record, so discarding here is not an undo - it is the phone
  /// forgetting a form it alone was holding.
  ///
  /// Asked first, and the photos are the reason. The answers he can retap; the
  /// shots mean climbing back to the pole.
  Future<void> _discard() async {
    final tag = widget.tag;
    if (tag == null || _submitting) return;

    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this form?'),
        content: Text(
          _photos.isEmpty
              ? 'The answers for ${tag.tagCode} will be deleted from this '
                    'phone. Nothing has been sent to the office.'
              : 'The answers and ${_photos.length} photo'
                    '${_photos.length == 1 ? '' : 's'} for ${tag.tagCode} will '
                    'be deleted from this phone. Nothing has been sent to the '
                    'office.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (sure != true || !mounted) return;

    // Cancelled before anything else: a save landing after the draft is gone
    // would write it straight back.
    _pending?.cancel();

    await ref.read(draftProvider.notifier).discard(tag.tagId);

    // The files as well as the record of them. These are full-size pole
    // photographs, and nothing points at them once the draft is gone.
    if (_photos.isNotEmpty) {
      final store = await ref.read(photoStoreProvider.future);
      await store.discard(_shots);
    }

    if (!mounted) return;

    // Emptied so `dispose` and any late save have nothing left to write.
    setState(() => _photos = const []);

    Navigator.of(context).pop();
  }

  /// Marks the form dirty and saves it a moment later.
  ///
  /// What every answer calls. The step buttons and the camera still save
  /// outright - those are moments where he may be about to walk away - but
  /// between them the draft now follows him rather than waiting for a tap he
  /// might never make. Before this, a step filled in and left unconfirmed died
  /// with the battery.
  void _touched() {
    _pending?.cancel();
    _pending = Timer(const Duration(milliseconds: 800), _saveDraft);
  }

  /// Keeps what he has so far, so walking away from a pole costs him nothing.
  ///
  /// Called when he answers anything, when he finishes a step, when he backs
  /// out, and when he comes off the camera. Never during a submit - the tag is
  /// on its way to the queue, and a draft written behind it would leave the row
  /// claiming both.
  Future<void> _saveDraft() async {
    // Whatever was waiting has just happened.
    _pending?.cancel();

    final tag = widget.tag;
    if (tag == null || _submitting) return;

    await ref
        .read(draftProvider.notifier)
        .save(
          DraftTag(
            tagId: tag.tagId,
            tagCode: tag.tagCode,
            step: _at,
            record: _record(tag),
            photos: _photos,
            savedAt: DateTime.now(),
          ),
        );

    // The line under the form. Set after the write, not before it, so it can
    // only ever report a save that actually landed.
    if (mounted) setState(() => _savedAt = DateTime.now());
  }

  Future<void> _next() async {
    if (!_onLastStep) {
      final done = _missingIn(_step).isEmpty;

      setState(() {
        _errorAt = done ? null : _step;
        if (done) _at++;
      });

      // Nothing missing means he moved on, and what he answered is now worth
      // keeping. The camera saves again on its way out.
      if (done) await _saveDraft();

      // The mockup puts him behind the camera the moment he reaches the photos,
      // rather than in front of a grid he has to tap first.
      if (done && _step == _Step.photos && !_cameraOffered) {
        _cameraOffered = true;
        _openCamera();
      }
      return;
    }

    // The last step re-checks every step, not only this one: he can reach the
    // end, walk back, clear a field and come forward again.
    //
    // Every step *this form walks*, not every step there is. A re-capture
    // never asks for a height, so checking the pole step would refuse to
    // submit over a box he was never shown.
    for (final step in _steps) {
      if (_missingIn(step).isNotEmpty) {
        setState(() {
          _errorAt = step;
          _at = _steps.indexOf(step);
        });
        return;
      }
    }

    setState(() => _errorAt = null);

    await _submit();
  }

  /// Hands the finished tag to the queue and leaves.
  ///
  /// Deliberately does not wait on the server. The photos are copied somewhere
  /// permanent, the tag is written to the phone, and he is back on the list -
  /// with signal that all happens in about a second, and without it, it
  /// happens anyway.
  Future<void> _submit() async {
    final tag = widget.tag;
    if (tag == null || _submitting) return;

    setState(() => _submitting = true);

    // Built once and handed to both the queue and the receipt, so the screen
    // cannot show him a pole that differs from the one filed.
    final record = _record(tag);

    // The photos were copied somewhere permanent as he took them, so there is
    // nothing left to move here.
    await ref
        .read(uploadProvider.notifier)
        .submit(
          QueuedTag(
            tagId: tag.tagId,
            tagCode: tag.tagCode,
            record: record,
            photos: _photos,
            queuedAt: DateTime.now(),
            userId: ref.read(authProvider).user?.userId,
          ),
        );

    // It is a finished tag now, not an unfinished one. Leaving the draft
    // behind would have the row claiming Draft and greyed-out at once.
    await ref.read(draftProvider.notifier).discard(tag.tagId);

    if (!mounted) return;

    // Whether it actually went up is the queue's answer, not this screen's.
    final stillWaiting = ref
        .read(uploadProvider)
        .queuedTagIds
        .contains(tag.tagId);

    // It reached the server, so the server now calls this tag Used and it
    // belongs under Completed rather than Assigned. Nothing greys it out
    // either - it was never in the queue long enough - so without this it sits
    // among his work looking like a pole he still has to do.
    //
    // Not awaited: he is on his way back to the list, and a refresh that
    // cannot reach the server is no reason to hold him here.
    if (!stillWaiting) {
      unawaited(ref.read(tagProvider.notifier).loadMyTags());
    }

    // The receipt, in place of the snackbar that used to say this. A pole is
    // twenty minutes up a ladder and the proof of it lasted two seconds; this
    // screen holds what was filed until he says he is done with it.
    //
    // pushReplacement, not push: the form behind this has been submitted, and
    // a back gesture landing on it would offer a second go at a finished pole.
    context.pushReplacement(
      Routes.saved,
      extra: SavedPole(
        tagCode: tag.tagCode,
        record: record,
        photos: _photos.length,
        queued: stillWaiting,
        batchCode: tag.batchCode,
        sentBackFor: _sentBackFor,
      ),
    );
  }

  /// Leaving is not abandoning. Whatever he has answered is kept on the way
  /// out, so a foreman calling him over costs him nothing.
  Future<void> _back() async {
    if (_at == 0) {
      await _saveDraft();
      // pop, not maybePop: maybePop asks the PopScope in build, which hands
      // straight back here, round and round.
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _at--;
      _errorAt = null;
    });

    await _saveDraft();
  }

  @override
  void dispose() {
    // Left running, this keeps the GPS awake behind whatever screen he opens
    // next - the same drain the camera had before it was replaced rather than
    // stacked.
    _readings?.cancel();
    // Whatever was waiting to be written is dropped: every path off this screen
    // saves outright on its way out, so the timer has nothing left to add.
    _pending?.cancel();
    _remarks.removeListener(_touched);
    _assetTypeOther.removeListener(_touched);
    _assetTypeOther.dispose();
    _feet.dispose();
    _metres.dispose();
    _remarks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tag = widget.tag;

    if (tag == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pole record')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Start again from your tag list.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final options = ref.watch(formOptionsProvider);
    final complaint = _complaint;

    // The phone's own back does what the chevron does: a step back, saving on
    // the way. With the default it closed the whole form from any step, and
    // dispose dropped the save that was still waiting on its timer - so the
    // last thing he typed was lost from the draft.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _back();
      },
      child: Scaffold(
        appBar: AppBar(
          // The tag and the step, the way the mockup's header reads: he is deep
          // in a form and needs to know which tag and how much is left.
          backgroundColor: AppColors.deepGreen,
          foregroundColor: AppColors.onGreen,
          elevation: 0,
          titleSpacing: 0,
          // A chevron, not Material's arrow with a tail: the mockup's, and the
          // lighter mark reads as "back a step" rather than "leave this screen",
          // which is what it does on every step but the first.
          leading: IconButton(
            onPressed: _back,
            icon: const Icon(Icons.chevron_left, size: 30),
            tooltip: 'Back',
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // One line, two voices. The code is what he checks against the
              // sticker in his hand, so it is set in the same face the code is
              // read in everywhere else; the step behind it is a caption.
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: tag.tagCode,
                      style: const TextStyle(
                        fontFamily: AppFonts.mono,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    TextSpan(
                      text: '  \u00b7  STEP ${_at + 1} OF ${_steps.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                style: TextStyle(fontSize: 14.5, color: AppColors.paleGreen),
              ),
              const SizedBox(height: 1),
              Text(
                _step.title,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onGreen,
                ),
              ),
            ],
          ),
          actions: [
            // Beside the step rather than at the foot of the form: it is the way
            // out, not one of the answers, and a destructive button under Next is
            // a button he hits with his thumb.
            OutlinedButton.icon(
              onPressed: _submitting ? null : _discard,
              icon: const Icon(Icons.delete_outline, size: 17),
              label: const Text(
                'Discard',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(color: AppColors.danger),
                backgroundColor: AppColors.dangerWash,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
                shape: const StadiumBorder(),
              ),
            ),
            const SizedBox(width: 4),
          ],
          bottom: StepDots(at: _at, count: _steps.length),
        ),
        body: options.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => FormMessage(
            text: '$error',
            onRetry: () => ref.invalidate(formOptionsProvider),
          ),
          // Null means this handset has never been online, so there is nothing
          // saved to offer. Saying so beats an empty form he would try to fill.
          data: (choices) => choices == null
              ? const FormMessage(
                  text:
                      'The form choices have not reached this phone yet. '
                      'Open the app once where there is signal.',
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ..._cardsFor(_step, choices),
                    if (complaint != null) ...[
                      const SizedBox(height: 14),
                      FormComplaint(text: complaint),
                    ],
                    const SizedBox(height: 18),
                    _SavedLine(at: _savedAt),
                  ],
                ),
        ),
        bottomNavigationBar: options.value == null
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: FilledButton(
                  onPressed: _submitting ? null : _next,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    // Material 3 makes this a full pill. The mockup draws a
                    // rounded rectangle, and it is the one button on the screen
                    // he hits without looking - a shape that matches the cards
                    // above it reads as part of the form rather than as a chip
                    // floating over it.
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _onLastStep ? 'Save pole tag' : 'Next',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// The cards belonging to one step. Only the step he is on is built, so a
  /// question two steps ahead cannot be answered by a stray tap.
  List<Widget> _cardsFor(_Step step, FormOptions choices) {
    final flagged = _flagged(step);

    return switch (step) {
      _Step.location => [
        // Only here: he has just come off the camera, and this is where a
        // scan of the wrong sticker is still cheap to undo.
        // A re-pin arrives here without a scan - the sticker was read when
        // the pole was first filed, and the office sent it back for a reading
        // rather than an identification.
        ScanBanner(
          tagCode: widget.tag!.tagCode,
          heading: _pinOnly ? 'Sent back · Re-pin' : 'Scan complete',
          scanned: !_pinOnly,
        ),
        const SizedBox(height: 14),
        LocationCard(
          required: true,
          missing: flagged.contains(_Field.location),
          position: _best,
          blocked: _blocked,
          onSettings: _location.openSettings,
          onRefix: _fix,
        ),
        // Not on a re-pin: the map and the calibration are the whole of what
        // he was sent for, and the two answers below are already on file.
        if (!_pinOnly) ...[
          if (choices.duOwnedOptions.isNotEmpty) ...[
            const SizedBox(height: 14),
            QuestionCard(
              required: true,
              missing: flagged.contains(_Field.duOwned),
              title: 'DU owned?',
              options: choices.duOwnedOptions,
              selectedId: _duOwnedOptionId,
              onPick: (id) {
                setState(() => _duOwnedOptionId = id);
                _touched();
              },
            ),
          ],
          const SizedBox(height: 14),
          QuestionCard(
            required: true,
            missing: flagged.contains(_Field.telco),
            title: 'With telco attachment?',
            options: choices.telcoOptions,
            selectedId: _telcoOptionId,
            onPick: (id) {
              setState(() => _telcoOptionId = id);
              _touched();
            },
          ),
          const SizedBox(height: 14),
          QuestionCard(
            required: true,
            missing: flagged.contains(_Field.streetlight),
            title: 'Is there a streetlight attachment?',
            options: choices.streetlightOptions,
            selectedId: _streetlightOptionId,
            onPick: (id) {
              setState(() => _streetlightOptionId = id);
              _touched();
            },
          ),
        ],
      ],
      _Step.pole => [
        PoleTypeCard(
          missing: flagged.contains(_Field.poleType),
          options: choices.poleTypes,
          selectedId: _poleTypeId,
          onPick: (id) {
            setState(() => _poleTypeId = id);
            _touched();
          },
        ),
        if (choices.assetTypes.isNotEmpty) ...[
          const SizedBox(height: 14),
          AssetTypeCard(
            missing:
                flagged.contains(_Field.assetType) ||
                flagged.contains(_Field.assetTypeOther),
            options: choices.assetTypes,
            selectedIds: _assetTypeIds,
            otherText: _assetTypeOther,
            onToggle: (id) {
              setState(() {
                if (!_assetTypeIds.remove(id)) _assetTypeIds.add(id);
              });
              _touched();
            },
          ),
        ],
        const SizedBox(height: 14),
        HeightCard(
          missing: flagged.contains(_Field.height),
          feet: _feet,
          metres: _metres,
          onFeet: _onFeet,
          onMetres: _onMetres,
          onPreset: _pickHeight,
        ),
        const SizedBox(height: 14),
        ConditionCard(
          missing: flagged.contains(_Field.condition),
          options: choices.poleConditions,
          selectedId: _poleConditionId,
          // Tapping the chosen one again clears it. Now that it is required
          // clearing only blocks him again - but a mistap he cannot undo is
          // worse, and the step will not let him leave it empty.
          onPick: (id) {
            setState(
              () => _poleConditionId = _poleConditionId == id ? null : id,
            );
            _touched();
          },
        ),
      ],
      _Step.photos => [
        ShotsPanel(
          missing: flagged.contains(_Field.photos),
          shots: _shots,
          onOpenCamera: _openCamera,
          onRetake: (index) => _openCamera(retake: index),
          onRemove: _removePhoto,
        ),
      ],
      _Step.remarks => [RemarksCard(controller: _remarks)],
    };
  }
}

/// "Draft saved 6:19pm - safe to close."
///
/// The whole point of the drafts, said out loud. They have always worked and he
/// has never been told, so the only way to find out whether it was safe to shut
/// the app was to shut it - which is not an experiment a man runs with an hour
/// of work in front of him.
///
/// Says nothing at all until the first save. An empty form has nothing to keep,
/// and a line promising otherwise would be the one lie on the screen.
class _SavedLine extends StatelessWidget {
  const _SavedLine({this.at});

  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final saved = at;
    if (saved == null) return const SizedBox.shrink();

    final hour = saved.hour % 12 == 0 ? 12 : saved.hour % 12;
    final minute = saved.minute.toString().padLeft(2, '0');
    final ampm = saved.hour < 12 ? 'am' : 'pm';

    return Text(
      'Draft saved $hour:$minute$ampm — safe to close',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14.5, color: AppColors.muted),
    );
  }
}

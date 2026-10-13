/// One choice on the tagging form, as `GET /form-options` sends it.
///
/// The kind of choice is not on the option itself - it is the list the option
/// arrived in. See [FormOptions].
class FormOption {
  final int id;
  final String label;

  const FormOption({required this.id, required this.label});

  factory FormOption.fromJson(Map<String, dynamic> json) {
    return FormOption(id: json['id'], label: json['label'] ?? '');
  }

  Map<String, dynamic> toJson() => {'id': id, 'label': label};
}

/// Every choice the five-step form offers, for this crew's utility.
///
/// The ids differ per utility - telco "Yes" is 1 for NP and 3 for BP - so the
/// app must never write an id of its own. It sends back whichever [FormOption]
/// he tapped.
class FormOptions {
  final List<FormOption> poleTypes;
  final List<FormOption> poleConditions;
  final List<FormOption> telcoOptions;
  final List<FormOption> streetlightOptions;

  // Empty by default: a copy cached before these lists existed has none, and
  // reads as empty until the next refresh with signal.
  final List<FormOption> duOwnedOptions;
  final List<FormOption> assetTypes;

  const FormOptions({
    required this.poleTypes,
    required this.poleConditions,
    required this.telcoOptions,
    required this.streetlightOptions,
    this.duOwnedOptions = const [],
    this.assetTypes = const [],
  });

  factory FormOptions.fromJson(Map<String, dynamic> json) {
    return FormOptions(
      poleTypes: _list(json['pole_types']),
      poleConditions: _list(json['pole_conditions']),
      telcoOptions: _list(json['telco_options']),
      streetlightOptions: _list(json['streetlight_options']),
      duOwnedOptions: _list(json['du_owned_options']),
      assetTypes: _list(json['asset_types']),
    );
  }

  Map<String, dynamic> toJson() => {
    'pole_types': poleTypes.map((o) => o.toJson()).toList(),
    'pole_conditions': poleConditions.map((o) => o.toJson()).toList(),
    'telco_options': telcoOptions.map((o) => o.toJson()).toList(),
    'streetlight_options': streetlightOptions.map((o) => o.toJson()).toList(),
    'du_owned_options': duOwnedOptions.map((o) => o.toJson()).toList(),
    'asset_types': assetTypes.map((o) => o.toJson()).toList(),
  };

  /// Rebuilt with `Map.from` rather than a cast because this runs on two
  /// different shapes: the server's JSON, already keyed by String, and the copy
  /// Hive hands back, which is keyed loosely. Casting the second one threw.
  static List<FormOption> _list(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((option) => FormOption.fromJson(Map<String, dynamic>.from(option)))
        .toList();
  }
}

/// A pole's ticked asset types as one line - "13.2 kb, fuse box".
///
/// [ticks] is the list as the API spells it, from the server or from the
/// phone's own copy of what it sent: maps of `asset_type_id`, maybe a `label`,
/// and `other_text` on the Others tick. The typed text stands in for a bare
/// "Others", which says nothing about the pole. A dash when nothing was ticked.
String describeAssetTypes(dynamic ticks, List<FormOption>? menu) {
  if (ticks is! List || ticks.isEmpty) return '—';

  final names = <String>[];
  for (final tick in ticks.whereType<Map>()) {
    final other = tick['other_text'];
    if (other is String && other.trim().isNotEmpty) {
      names.add(other.trim());
      continue;
    }
    final id = tick['asset_type_id'];
    String? name = tick['label'] as String?;
    for (final option in menu ?? const <FormOption>[]) {
      if (option.id == id) name = option.label;
    }
    if (name != null) names.add(name);
  }
  return names.isEmpty ? '—' : names.join(', ');
}

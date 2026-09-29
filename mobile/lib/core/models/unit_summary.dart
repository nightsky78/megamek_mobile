/// Mirrors `megamekmobile.bridge.dto.UnitSummaryDto`, one entry in a
/// `state.unit_catalog` reply. `ref` must be sent back verbatim as
/// `action.add_unit`/`action.add_bot_unit`'s `unitRef`.
class UnitSummary {
  const UnitSummary({
    required this.ref,
    required this.chassis,
    required this.model,
    required this.unitType,
    required this.tons,
    required this.bv,
    required this.year,
    required this.techBase,
    required this.clan,
  });

  final String ref;
  final String chassis;
  final String model;
  final String unitType;
  final double tons;
  final int bv;
  final int year;
  final String techBase;
  final bool clan;

  factory UnitSummary.fromJson(Map<String, dynamic> json) => UnitSummary(
    ref: json['ref'] as String,
    chassis: json['chassis'] as String,
    model: json['model'] as String,
    unitType: json['unitType'] as String,
    tons: (json['tons'] as num).toDouble(),
    bv: json['bv'] as int,
    year: json['year'] as int,
    techBase: json['techBase'] as String,
    clan: json['clan'] as bool,
  );
}

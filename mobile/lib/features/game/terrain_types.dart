/// Mirrors `megamek.common.units.Terrains` constants (vendor commit e601296070c
/// / v0.51.0) relevant to rendering - kept as literals per convention (see
/// docs/protocol-notes.md), matching how [TerrainType] mirrors `MoveStepType`.
/// If the vendor pin is upgraded, diff `Terrains.java` against this file.
enum TerrainCategory {
  /// Flat semi-transparent tint over the whole hex.
  groundCoverTint,

  /// Dot-cluster scatter: woods, jungle.
  vegetation,

  /// Stipple/scatter marks: rough, rubble.
  texture,

  /// Flat opaque recolor, its own pass (paints over texture/tint).
  pavement,

  /// Edge-to-center spokes using the exits bitmask: road, bridge.
  linear,

  /// Distinct footprint shape: building.
  structure,

  /// Never independently drawn - read by the [structure]/[linear] passes to
  /// parametrize them (building class/floors, bridge CF/elevation).
  structureMetadata,

  /// Full-hex translucent wash drawn last, on top of everything: fire, smoke.
  overlay,
}

enum TerrainType {
  woods(1, TerrainCategory.vegetation),
  water(2, TerrainCategory.groundCoverTint),
  rough(3, TerrainCategory.texture),
  rubble(4, TerrainCategory.texture),
  jungle(5, TerrainCategory.vegetation),
  sand(6, TerrainCategory.groundCoverTint),
  tundra(7, TerrainCategory.groundCoverTint),
  magma(8, TerrainCategory.groundCoverTint),
  fields(9, TerrainCategory.groundCoverTint),
  industrial(10, TerrainCategory.groundCoverTint),
  pavement(12, TerrainCategory.pavement),
  road(13, TerrainCategory.linear),
  swamp(14, TerrainCategory.groundCoverTint),
  mud(15, TerrainCategory.groundCoverTint),
  // Drawn as a texture on top of the water tint within the same pass, not
  // independently - see HexMapPainter.
  rapids(16, TerrainCategory.groundCoverTint),
  ice(17, TerrainCategory.groundCoverTint),
  snow(18, TerrainCategory.groundCoverTint),
  fire(19, TerrainCategory.overlay),
  smoke(20, TerrainCategory.overlay),
  geyser(21, TerrainCategory.groundCoverTint),
  building(22, TerrainCategory.structure),
  bldgCf(23, TerrainCategory.structureMetadata),
  bldgElev(24, TerrainCategory.structureMetadata),
  bridge(28, TerrainCategory.linear),
  bridgeCf(29, TerrainCategory.structureMetadata),
  bridgeElev(30, TerrainCategory.structureMetadata),
  fortified(37, TerrainCategory.groundCoverTint);

  const TerrainType(this.wireType, this.category);

  final int wireType;
  final TerrainCategory category;

  static final Map<int, TerrainType> _byWireType = {
    for (final t in TerrainType.values) t.wireType: t,
  };

  /// Null for a terrain int this app doesn't (yet) know how to render - callers
  /// should skip unknown entries silently rather than crash (forward-compat
  /// with a future bridge allowlist expansion this build predates).
  static TerrainType? fromWireType(int wireType) => _byWireType[wireType];
}

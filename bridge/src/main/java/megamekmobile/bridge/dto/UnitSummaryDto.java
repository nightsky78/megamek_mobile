package megamekmobile.bridge.dto;

/**
 * One entry in a {@code state.unit_catalog} reply. {@code ref} is the exact string
 * {@code megamek.common.loaders.MekSummary.getName()} returns for this unit, and must be sent back
 * verbatim as {@code action.add_unit}/{@code action.add_bot_unit}'s {@code unitRef} - it is the key
 * {@code MekSummaryCache.getMek(String)} looks entries up by.
 */
public record UnitSummaryDto(
      String ref,
      String chassis,
      String model,
      String unitType,
      double tons,
      int bv,
      int year,
      String techBase,
      boolean clan) {
}

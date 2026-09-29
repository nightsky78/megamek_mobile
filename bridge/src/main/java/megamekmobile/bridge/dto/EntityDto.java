package megamekmobile.bridge.dto;

import java.util.List;

/**
 * A single unit (Mek/Vehicle/Infantry) as shown to the mobile client. Deliberately much smaller than
 * MegaMek's own {@code Entity}: only what the touch UI needs to render a marker, a detail sheet and an
 * attack dialog.
 */
public record EntityDto(
      int id,
      int ownerId,
      String chassis,
      String model,
      String displayName,
      int boardId,
      int x,
      int y,
      int facing,
      int armor,
      int totalArmor,
      int internal,
      int totalInternal,
      boolean destroyed,
      String pilotName,
      int gunnery,
      int pilotHits,
      List<WeaponDto> weapons,
      double tons,
      int bv,
      String unitType,
      int piloting,
      int heat,
      int heatCapacity,
      int walkMp,
      int runMp,
      int jumpMp,
      boolean prone,
      boolean shutDown,
      boolean immobile,
      boolean deployed,
      List<LocationDto> locations,
      List<AmmoDto> ammo,
      List<String> damagedEquipment) {
}

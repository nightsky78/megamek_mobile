package megamekmobile.bridge.mapping;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

import megamek.common.loaders.MekSummary;

import megamekmobile.bridge.dto.ActionMessage;
import megamekmobile.bridge.dto.UnitCatalogMessage;

/**
 * Verifies unit-catalog filtering/truncation using real {@link MekSummary} instances (not mocks), same
 * approach as {@link GameStateMapperTest}.
 */
class UnitCatalogMapperTest {

    private static MekSummary unit(String chassis, String model, double tons, boolean clan) {
        MekSummary summary = new MekSummary();
        summary.setChassis(chassis);
        summary.setModel(model);
        summary.setName(chassis + " " + model);
        summary.setUnitType("Mek");
        summary.setTons(tons);
        summary.setBV(1000);
        summary.setYear(3050);
        summary.setTechBase(clan ? "Clan" : "Inner Sphere");
        summary.setClan(clan);
        summary.setSource("");
        return summary;
    }

    private static ActionMessage query(String text, String unitType, Boolean clanOnly, Double minTons,
          Double maxTons, Integer limit) {
        return new ActionMessage(ActionMessage.UNIT_CATALOG_SEARCH, null, null, null, null, null, text, null,
              null, null, unitType, clanOnly, minTons, maxTons, limit, null, null, null, null, null, null, null,
              null, null, null, null, null, null, null);
    }

    @Test
    void filtersByTextSubstringAcrossChassisAndModel() {
        MekSummary[] all = {
              unit("Atlas", "AS7-D", 100, false),
              unit("Warhammer", "WHM-6R", 70, false)
        };

        UnitCatalogMessage result = UnitCatalogMapper.search(all, query("atlas", null, null, null, null, null));

        assertEquals(1, result.totalMatches());
        assertEquals("Atlas AS7-D", result.units().get(0).ref());
    }

    @Test
    void filtersByClanNameAsWellAsChassis() {
        MekSummary madCat = unit("Mad Cat", "Prime", 75, true);
        madCat.setClanChassisName("Timber Wolf");
        MekSummary[] all = { madCat, unit("Atlas", "AS7-D", 100, false) };

        UnitCatalogMessage result = UnitCatalogMapper.search(all, query("timber wolf", null, null, null, null, null));

        assertEquals(1, result.totalMatches());
        assertEquals("Mad Cat Prime", result.units().get(0).ref());
    }

    @Test
    void filtersByClanOnly() {
        MekSummary[] all = {
              unit("Atlas", "AS7-D", 100, false),
              unit("Timber Wolf", "Prime", 75, true)
        };

        UnitCatalogMessage result = UnitCatalogMapper.search(all, query(null, null, true, null, null, null));

        assertEquals(1, result.totalMatches());
        assertEquals("Timber Wolf Prime", result.units().get(0).ref());
    }

    @Test
    void filtersByTonnageRange() {
        MekSummary[] all = {
              unit("Locust", "LCT-1V", 20, false),
              unit("Atlas", "AS7-D", 100, false)
        };

        UnitCatalogMessage result = UnitCatalogMapper.search(all, query(null, null, null, 50.0, 100.0, null));

        assertEquals(1, result.totalMatches());
        assertEquals("Atlas AS7-D", result.units().get(0).ref());
    }

    @Test
    void reportsTotalMatchesBeforeTruncationAndCapsResults() {
        MekSummary[] all = new MekSummary[5];
        for (int i = 0; i < all.length; i++) {
            all[i] = unit("Chassis" + i, "Model" + i, 50, false);
        }

        UnitCatalogMessage result = UnitCatalogMapper.search(all, query(null, null, null, null, null, 2));

        assertEquals(5, result.totalMatches());
        assertEquals(2, result.units().size());
    }

    @Test
    void defaultsToDefaultLimitWhenNoneRequested() {
        MekSummary[] all = new MekSummary[UnitCatalogMapper.DEFAULT_LIMIT + 10];
        for (int i = 0; i < all.length; i++) {
            all[i] = unit("Chassis" + i, "Model" + i, 50, false);
        }

        UnitCatalogMessage result = UnitCatalogMapper.search(all, query(null, null, null, null, null, null));

        assertEquals(all.length, result.totalMatches());
        assertEquals(UnitCatalogMapper.DEFAULT_LIMIT, result.units().size());
    }

    @Test
    void clampsLimitToMaxLimit() {
        MekSummary[] all = new MekSummary[UnitCatalogMapper.MAX_LIMIT + 10];
        for (int i = 0; i < all.length; i++) {
            all[i] = unit("Chassis" + i, "Model" + i, 50, false);
        }

        UnitCatalogMessage result = UnitCatalogMapper.search(all,
              query(null, null, null, null, null, UnitCatalogMapper.MAX_LIMIT + 1000));

        assertTrue(result.units().size() <= UnitCatalogMapper.MAX_LIMIT);
    }
}

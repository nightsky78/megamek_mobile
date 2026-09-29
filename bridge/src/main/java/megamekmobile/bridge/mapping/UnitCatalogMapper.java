package megamekmobile.bridge.mapping;

import java.util.List;
import java.util.Locale;

import megamek.common.loaders.MekSummary;

import megamekmobile.bridge.dto.ActionMessage;
import megamekmobile.bridge.dto.UnitCatalogMessage;
import megamekmobile.bridge.dto.UnitSummaryDto;

/**
 * Answers {@code action.unit_catalog_search} against MegaMek's {@code MekSummaryCache}. Kept free of
 * any {@code Client}/{@code Game}/networking so it's trivially unit-testable, same as
 * {@link GameStateMapper}. Filtered and capped rather than dumping the whole cache: it commonly holds
 * several thousand units, and even a trimmed DTO per entry would make for an oversized single message.
 */
public final class UnitCatalogMapper {

    public static final int DEFAULT_LIMIT = 50;
    public static final int MAX_LIMIT = 200;

    private UnitCatalogMapper() {
    }

    public static UnitSummaryDto toDto(MekSummary summary) {
        return new UnitSummaryDto(
              summary.getName(),
              summary.getChassis(),
              summary.getModel(),
              summary.getUnitType(),
              summary.getTons(),
              summary.getBV(),
              summary.getYear(),
              summary.getTechBase(),
              summary.isClan());
    }

    public static UnitCatalogMessage search(MekSummary[] all, ActionMessage query) {
        String text = query.text() == null ? null : query.text().trim().toLowerCase(Locale.ROOT);
        int limit = clampLimit(query.limit());

        List<MekSummary> matches = new java.util.ArrayList<>();
        int totalMatches = 0;
        for (MekSummary summary : all) {
            if (!matchesFilters(summary, query, text)) {
                continue;
            }
            totalMatches++;
            if (matches.size() < limit) {
                matches.add(summary);
            }
        }

        List<UnitSummaryDto> dtos = matches.stream().map(UnitCatalogMapper::toDto).toList();
        return new UnitCatalogMessage(dtos, totalMatches);
    }

    private static boolean matchesFilters(MekSummary summary, ActionMessage query, String lowerCaseText) {
        if (lowerCaseText != null && !lowerCaseText.isEmpty()) {
            // getFullChassis() includes the clan name in parens for rebadged Clan designs (e.g.
            // "Mad Cat (Timber Wolf)") - without it, searching the commonly-known "Timber Wolf"
            // name finds nothing, since that name isn't in getChassis()/getModel() at all.
            String haystack = (summary.getFullChassis() + " " + summary.getModel() + " " + summary.getSource())
                  .toLowerCase(Locale.ROOT);
            if (!haystack.contains(lowerCaseText)) {
                return false;
            }
        }
        if (query.unitType() != null && !query.unitType().equalsIgnoreCase(summary.getUnitType())) {
            return false;
        }
        if (Boolean.TRUE.equals(query.clanOnly()) && !summary.isClan()) {
            return false;
        }
        if (query.minTons() != null && summary.getTons() < query.minTons()) {
            return false;
        }
        if (query.maxTons() != null && summary.getTons() > query.maxTons()) {
            return false;
        }
        return true;
    }

    private static int clampLimit(Integer requested) {
        if (requested == null) {
            return DEFAULT_LIMIT;
        }
        return Math.max(1, Math.min(requested, MAX_LIMIT));
    }
}

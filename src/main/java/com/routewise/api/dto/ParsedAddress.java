package com.routewise.api.dto;

import java.util.StringJoiner;

/**
 * A structured address produced by OCR or manual intake.
 *
 * <p>Heuristic parsing is deliberately best-effort: OCR can garble text, so a
 * parcel is still accepted even when only part of the address could be read.
 * {@link #complete()} indicates whether enough pieces were found (street/area
 * plus city plus pincode) to attempt geocoding without human verification.
 */
public record ParsedAddress(
        String street,
        String area,
        String city,
        String pincode,
        String displayText,
        boolean complete) {

    public static final ParsedAddress EMPTY =
            new ParsedAddress(null, null, null, null, null, false);

    /** Builds a {@link ParsedAddress} from manually typed components. */
    public static ParsedAddress fromComponents(
            String street, String area, String city, String pincode) {
        return new ParsedAddress(
                street, area, city, pincode,
                joinNonBlank(street, area, city, pincode),
                street != null && city != null && pincode != null);
    }

    /** Joins the non-blank parts with ", " in the given order. */
    private static String joinNonBlank(String... parts) {
        StringJoiner joiner = new StringJoiner(", ");
        for (String part : parts) {
            if (part != null && !part.isBlank()) {
                joiner.add(part.trim());
            }
        }
        String joined = joiner.toString();
        return joined.isEmpty() ? null : joined;
    }

    public boolean complete() {
        return complete;
    }
}
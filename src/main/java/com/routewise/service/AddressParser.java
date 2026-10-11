package com.routewise.service;

import com.routewise.api.dto.ParsedAddress;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Best-effort parser that turns raw OCR text from a label photo into a
 * structured address (street, area, city, pincode).
 *
 * <p>The rules are intentionally simple heuristics tuned for Indian one-line
 * labels of the shape {@code RECIPIENT / STREET / LOCALITY / CITY / STATE PIN}:
 *
 * <ul>
 *   <li>pincode = the first standalone 6-digit number ({@code \b[1-9]\d{5}\b});</li>
 *   <li>city = a known city name found anywhere in the text, otherwise the
 *       words left in the pincode's own line after stripping state words;</li>
 *   <li>area = the last line containing a locality suffix (Nagar, Colony,
 *       Layout, Road, ...) that precedes the pincode;</li>
 *   <li>street = the first remaining line, preferring one with a house
 *       number (digits).</li>
 * </ul>
 *
 * <p>Nothing here is authoritative — it exists only to save the operator from
 * re-typing the whole label, and a not-complete parse is still accepted with
 * coordinates left {@code NOT_GEOCODED}.
 */
public final class AddressParser {

    private static final Pattern PIN_CODE = Pattern.compile("\\b[1-9][0-9]{5}\\b");

    /** Locality suffixes that typically mark the "area" line. */
    private static final Set<String> AREA_KEYWORDS = Set.of(
            "NAGAR", "COLONY", "LAYOUT", "EXTENSION", "EXTENTION", "ENCLAVE",
            "HOUSING", "SOCIETY", "VIHAR", "KUNJ", "PURAM", "BHAVAN", "PET",
            "BAZAR", "BAZAAR", "MARKET", "MANDI", "ROAD", "MARG", "LANE",
            "STREET", "CROSS", "MAIN", "HILLS", "GARDENS", "QUARTERS",
            "TOWNSHIP", "PHASE", "SECTOR", "CHOWK", "GANJ", "PALACE",
            "COMPLEX", "APARTMENTS", "HEIGHTS", "TOWERS", "NEST", "SQUARE");

    /** Known Indian cities. Longest names first so two-word cities win. */
    private static final List<String> CITIES = List.of(
            "THIRUVANANTHAPURAM", "VISAKHAPATNAM", "SECUNDERABAD",
            "BENGALURU", "BANGALORE", "CHENNAI", "KOLKATA", "AHMEDABAD", "CHANDIGARH",
            "COIMBATORE", "GUWAHATI", "HYDERABAD", "NEW DELHI",
            "TRIVANDRUM", "GURUGRAM", "GURGAON", "AMRITSAR", "KANPUR", "NAGPUR",
            "LUCKNOW", "BHOPAL", "INDORE", "PATNA", "SURAT", "JAIPUR", "NOIDA", "AGRA",
            "DELHI", "MUMBAI", "BOMBAY", "PUNE", "KOCHI", "COCHIN", "VADODARA", "VARANASI",
            "MYSURU", "MYSORE", "RAIPUR", "RANCHI", "VIZAG");

    /** State names / markers that are not part of a city. */
    private static final List<String> STATE_WORDS = List.of(
            "ANDHRA PRADESH", "UTTAR PRADESH", "MADHYA PRADESH", "WEST BENGAL",
            "TAMIL NADU", "HIMACHAL PRADESH", "TELANGANA", "KARNATAKA", "MAHARASHTRA",
            "RAJASTHAN", "CHHATTISGARH", "ODISHA", "HARYANA", "PUNJAB", "UTTARAKHAND",
            "KERALA", "JHARKHAND", "GUJARAT", "BIHAR", "ASSAM", "GOA");

    private AddressParser() {
    }

    /** Parses the given raw OCR text, never failing and never returning null. */
    public static ParsedAddress parse(String input) {
        if (input == null || input.isBlank()) {
            return ParsedAddress.EMPTY;
        }

        List<String> segments = splitSegments(input);
        String fullText = String.join(" ", segments).toUpperCase(Locale.ROOT);

        String pincode = findPincode(fullText);
        int pincodeSegment = segmentContaining(segments, pincode);

        String city = findKnownCity(fullText);
        int citySegment = city != null ? segmentContaining(segments, city) : -1;
        if (city == null) {
            city = fallbackCity(segments, pincode, pincodeSegment);
            if (city != null) {
                citySegment = segmentContaining(segments, city);
            }
        }

        int areaSegment = findAreaSegment(segments, pincodeSegment, citySegment);
        int streetSegment = findStreetSegment(segments, pincodeSegment, citySegment, areaSegment);

        String street = streetSegment >= 0 ? segments.get(streetSegment) : null;
        String area = areaSegment >= 0 ? segments.get(areaSegment) : null;
        String cityLabel = city != null ? titleCase(city) : null;

        String displayText = displayText(segments, streetSegment, areaSegment, citySegment,
                pincodeSegment, pincode);

        boolean complete = (street != null || area != null) && city != null && pincode != null;
        return new ParsedAddress(street, area, cityLabel, pincode, displayText, complete);
    }

    /** Splits on newlines/commas/semicolons and normalizes inner whitespace. */
    private static List<String> splitSegments(String input) {
        List<String> segments = new ArrayList<>();
        for (String raw : input.split("[,\\n;|]")) {
            String trimmed = raw.replaceAll("\\s+", " ").trim();
            if (!trimmed.isEmpty()) {
                segments.add(trimmed);
            }
        }
        return segments;
    }

    private static String findPincode(String fullText) {
        Matcher matcher = PIN_CODE.matcher(fullText);
        return matcher.find() ? matcher.group() : null;
    }

    /** Finds the first segment whose text contains {@code token} (or -1). */
    private static int segmentContaining(List<String> segments, String token) {
        if (token == null || token.isBlank()) {
            return -1;
        }
        String upper = token.toUpperCase(Locale.ROOT);
        for (int i = 0; i < segments.size(); i++) {
            if (segments.get(i).toUpperCase(Locale.ROOT).contains(upper)) {
                return i;
            }
        }
        return -1;
    }

    /** Returns the first known city present in the text (longest name first). */
    private static String findKnownCity(String fullText) {
        for (String city : CITIES) {
            if (Pattern.compile("(^|\\W)" + Pattern.quote(city) + "($|\\W)")
                    .matcher(fullText).find()) {
                return city;
            }
        }
        return null;
    }

    /**
     * City guess when no known name was found: the remaining words on the
     * pincode's own line (e.g. "HYDERABAD 500034" leaves HYDERABAD), else the
     * preceding line, else nothing.
     */
    private static String fallbackCity(List<String> segments, String pincode, int pincodeSegment) {
        if (pincodeSegment < 0) {
            return null;
        }
        String withPin = segments.get(pincodeSegment).toUpperCase(Locale.ROOT);
        String leftOvers = stripStateWords(withPin.replace(pincode, ""));
        if (!leftOvers.isBlank() && wordCount(leftOvers) <= 3) {
            return leftOvers.trim();
        }
        for (int i = pincodeSegment - 1; i >= 0; i--) {
            String candidate = stripStateWords(segments.get(i).toUpperCase(Locale.ROOT));
            if (!candidate.isBlank()) {
                String[] words = candidate.trim().split("\\s+");
                return words[Math.max(0, words.length - 2)] + " "
                        + (words.length > 1 ? words[words.length - 1] : "");
            }
        }
        return null;
    }

    /**
     * Picks the last line (before the pincode, if any) with a locality
     * keyword, skipping lines already claimed by the city. House-numbered
     * lines are treated as street lines and never as area.
     */
    private static int findAreaSegment(List<String> segments, int pincodeSegment, int citySegment) {
        int limit = pincodeSegment >= 0 ? pincodeSegment : segments.size() - 1;
        int areaSegment = -1;
        for (int i = 0; i <= limit; i++) {
            if (i == pincodeSegment || i == citySegment) {
                continue;
            }
            String upper = segments.get(i).toUpperCase(Locale.ROOT);
            if (containsDigit(upper)) {
                continue;
            }
            if (AREA_KEYWORDS.stream().anyMatch(keyword -> containsWord(upper, keyword))) {
                areaSegment = i;
            }
        }
        return areaSegment;
    }

    /**
     * First line that is neither pincode, city nor area; prefers one carrying
     * a house number/digits (which street lines usually have).
     */
    private static int findStreetSegment(
            List<String> segments, int pincodeSegment, int citySegment, int areaSegment) {
        int fallback = -1;
        for (int i = 0; i < segments.size(); i++) {
            if (i == pincodeSegment || i == citySegment || i == areaSegment) {
                continue;
            }
            String segment = segments.get(i);
            if (containsLetter(segment)) {
                if (containsDigit(segment)) {
                    return i;
                }
                if (fallback < 0) {
                    fallback = i;
                }
            }
        }
        return fallback;
    }

    /** The clean address for display: street/area/city lines plus the pincode. */
    private static String displayText(
            List<String> segments, int street, int area, int city, int pincodeSegment, String pincode) {
        StringBuilder builder = new StringBuilder();
        appendSegment(builder, segments, street);
        appendSegment(builder, segments, area);
        appendSegment(builder, segments, city);
        if (pincode != null) {
            if (builder.length() > 0) {
                builder.append(", ");
            }
            builder.append(pincode);
        }
        return builder.length() > 0 ? builder.toString() : null;
    }

    private static void appendSegment(StringBuilder builder, List<String> segments, int index) {
        if (index >= 0 && index < segments.size()) {
            if (builder.length() > 0) {
                builder.append(", ");
            }
            builder.append(segments.get(index));
        }
    }

    private static String stripStateWords(String text) {
        String result = text;
        for (String state : STATE_WORDS) {
            result = result.replaceAll("\\b" + Pattern.quote(state) + "\\b", " ");
        }
        return result.replaceAll("\\s+", " ").trim();
    }

    private static boolean containsWord(String text, String word) {
        return Pattern.compile("(^|\\W)" + Pattern.quote(word) + "($|\\W)").matcher(text).find();
    }

    private static boolean containsDigit(String text) {
        return text.chars().anyMatch(Character::isDigit);
    }

    private static boolean containsLetter(String text) {
        return text.chars().anyMatch(Character::isLetter);
    }

    private static int wordCount(String text) {
        return text.isBlank() ? 0 : text.trim().split("\\s+").length;
    }

    /** {@code NEW DELHI} -> {@code New Delhi}. */
    private static String titleCase(String text) {
        String[] words = text.toLowerCase(Locale.ROOT).split("\\s+");
        StringBuilder builder = new StringBuilder();
        for (String word : words) {
            if (!word.isEmpty()) {
                if (builder.length() > 0) {
                    builder.append(' ');
                }
                builder.append(Character.toUpperCase(word.charAt(0))).append(word.substring(1));
            }
        }
        return builder.toString();
    }
}
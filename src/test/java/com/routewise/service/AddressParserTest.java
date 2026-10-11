package com.routewise.service;

import com.routewise.api.dto.ParsedAddress;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Unit tests for the OCR address heuristics.
 */
class AddressParserTest {

    @Test
    void parsesFullIndianLabel() {
        ParsedAddress parsed = AddressParser.parse(
                "JAYANTH REDDY\nPLOT NO 42, SRI NAGAR COLONY\nHYDERABAD\nTELANGANA 500034");

        assertEquals("PLOT NO 42", parsed.street());
        assertEquals("SRI NAGAR COLONY", parsed.area());
        assertEquals("Hyderabad", parsed.city());
        assertEquals("500034", parsed.pincode());
        assertTrue(parsed.complete());
        assertNotNull(parsed.displayText());
    }

    @Test
    void houseNumberInLineTwoWinsOverRecipientLine() {
        ParsedAddress parsed = AddressParser.parse(
                "JAYANTH REDDY\n5-8-9 MARUTHI NAGAR, HYDERABAD, TELANGANA 500034");

        assertEquals("5-8-9 MARUTHI NAGAR", parsed.street());
        assertEquals("Hyderabad", parsed.city());
        assertEquals("500034", parsed.pincode());
    }

    @Test
    void twoWordCityIsMatchedAsAWhole() {
        ParsedAddress parsed = AddressParser.parse("PLOT 12, SECTOR 4, NEW DELHI 110001");

        assertEquals("New Delhi", parsed.city());
        assertEquals("110001", parsed.pincode());
        assertTrue(parsed.complete());
    }

    @Test
    void roadLineIsKeptAsAreaAndStreetStillFound() {
        ParsedAddress parsed = AddressParser.parse(
                "FLAT 302, ROAD NO 3, BANJARA HILLS, HYDERABAD, TELANGANA 500034");

        assertEquals("FLAT 302", parsed.street());
        assertEquals("BANJARA HILLS", parsed.area());
        assertEquals("Hyderabad", parsed.city());
        assertEquals("500034", parsed.pincode());
    }

    @Test
    void cityOnlyWithPincodeIsIncompleteButCapturesCity() {
        ParsedAddress parsed = AddressParser.parse("HYDERABAD 500034");

        assertNull(parsed.street());
        assertNull(parsed.area());
        assertEquals("Hyderabad", parsed.city());
        assertEquals("500034", parsed.pincode());
        assertFalse(parsed.complete());
    }

    @Test
    void unknownCityFallsBackToPincodeLineLeftovers() {
        ParsedAddress parsed = AddressParser.parse("42 MAIN ROAD, NANDYAL, KARNATAKA 518101");

        assertEquals("518101", parsed.pincode());
        assertEquals("Nandyal", parsed.city());
        assertNotNull(parsed.street());
    }

    @Test
    void missingPincodeIsAcceptedButIncomplete() {
        ParsedAddress parsed = AddressParser.parse("PLOT 9 GREEN PARK DELHI");

        assertEquals("Delhi", parsed.city());
        assertNull(parsed.pincode());
        assertFalse(parsed.complete());
    }

    @Test
    void stateWordsAreNotReturnedAsCity() {
        ParsedAddress parsed = AddressParser.parse("TELANGANA 500034");

        assertNull(parsed.city());
        assertEquals("500034", parsed.pincode());
        assertFalse(parsed.complete());
    }

    @Test
    void blankInputNeverFails() {
        ParsedAddress parsed = AddressParser.parse("   \n  ");

        assertEquals(ParsedAddress.EMPTY, parsed);
        assertNull(parsed.street());
        assertNull(parsed.pincode());
    }

    @Test
    void messyOcrTextStillExtractsThePincode() {
        ParsedAddress parsed = AddressParser.parse("p|ot 42 sri-nagar col0ny, hyderabad 500034.");

        assertEquals("500034", parsed.pincode());
        assertEquals("Hyderabad", parsed.city());
    }
}
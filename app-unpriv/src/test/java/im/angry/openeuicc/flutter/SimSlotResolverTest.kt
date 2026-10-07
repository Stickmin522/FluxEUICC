package im.angry.openeuicc.flutter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SimSlotResolverTest {
    @Test
    fun followsPhysicalSlotMappingInsteadOfReaderOrder() {
        val slots = listOf(SystemSimSlot(0, 1), SystemSimSlot(1, 0))
        assertEquals(1, SimSlotResolver.resolve("SIM1", slots, "", null))
        assertEquals(0, SimSlotResolver.resolve("SIM2", slots.reversed(), "", null))
    }

    @Test
    fun keepsSecondReaderWhenSubscriptionsAreUnavailable() {
        assertEquals(1, SimSlotResolver.resolve("SIM2", emptyList(), "", null))
        assertEquals(0, SimSlotResolver.resolve("SIM", emptyList(), "", null))
    }

    @Test
    fun matchesEidEvenWhenAllProfilesAreDisabled() {
        val slots = listOf(SystemSimSlot(1, null, "card-eid"))
        assertEquals(1, SimSlotResolver.resolve("SIM1", slots, "card-eid", null))
    }

    @Test
    fun matchesVisibleProfileIdentifierWhenEidIsRedacted() {
        val slots = listOf(SystemSimSlot(1, null, iccid = "12345F"))
        assertEquals(1, SimSlotResolver.resolve("SIM1", slots, "", "12345"))
    }

    @Test
    fun doesNotInferASlotFromUnrelatedOrRedactedCards() {
        val slots = listOf(SystemSimSlot(1, null, "", ""))
        assertNull(SimSlotResolver.resolve("eSE1", slots, "", ""))
        assertNull(SimSlotResolver.readerSlot("SIM0"))
        assertNull(SimSlotResolver.readerSlot("SIM2147483648"))
    }
}

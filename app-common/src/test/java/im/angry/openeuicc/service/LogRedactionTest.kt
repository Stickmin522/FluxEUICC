package im.angry.openeuicc.service

import im.angry.openeuicc.util.redactLog
import org.junit.Assert.*
import org.junit.Test

class LogRedactionTest {
    @Test
    fun masksActivationCodesAndCardIdentifiers() {
        val log = "LPA:1\$smdp.example.com\$test-code ICCID=89012345678901234567 status=200"
        val redacted = redactLog(log)
        assertFalse(redacted.contains("test-code"))
        assertFalse(redacted.contains("89012345678901234567"))
        assertTrue(redacted.contains("status=200"))
    }

    @Test
    fun masksPayloadsFromOlderVersions() {
        val log = "HTTP tx = {\"matchingId\":\"private-value\"}\nOMAPI APDU response: AABBCCDD9000"
        val redacted = redactLog(log)
        assertFalse(redacted.contains("private-value"))
        assertFalse(redacted.contains("AABBCCDD"))
    }
}

package net.typeblog.lpac_jni

import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Test
import net.typeblog.lpac_jni.impl.LocalProfileAssistantImpl
import java.io.IOException

class NativeBridgeTest {
    @Before fun requireNativeLibrary() {
        assumeTrue(System.getProperty("lpac.native.tests") == "true" || System.getProperty("java.vm.name") == "Dalvik")
    }

    private class Card : ApduInterface {
        override val valid = true
        var connected = 0
        var disconnected = 0
        var closed = 0
        var failOpen = false
        var openFailure: Exception? = null
        var failure: RuntimeException? = null
        var respond: (ByteArray) -> ByteArray = { byteArrayOf(0x6a, 0x80.toByte()) }
        val commands = mutableListOf<ByteArray>()
        override fun connect() { connected++ }
        override fun disconnect() { disconnected++ }
        override fun logicalChannelOpen(aid: ByteArray): Int {
            openFailure?.let { throw it }
            return if (failOpen) -1 else 257
        }
        override fun logicalChannelClose(handle: Int) { assertEquals(257, handle); closed++ }
        override fun transmit(handle: Int, tx: ByteArray): ByteArray {
            assertEquals(257, handle)
            commands += tx
            failure?.let { throw it }
            return respond(tx)
        }
    }

    private class Server : HttpInterface {
        var url = ""
        var request = byteArrayOf()
        var headers = emptyArray<String>()
        var failure: RuntimeException? = null
        override fun usePublicKeyIds(pkids: Array<String>) = Unit
        override fun transmit(url: String, tx: ByteArray, headers: Array<String>): HttpInterface.HttpResponse {
            this.url = url; request = tx; this.headers = headers
            failure?.let { throw it }
            return HttpInterface.HttpResponse(200, byteArrayOf())
        }
    }

    private fun tlv(tag: Int, body: ByteArray): ByteArray {
        val prefix = if (tag > 255) byteArrayOf((tag shr 8).toByte(), tag.toByte()) else byteArrayOf(tag.toByte())
        val size = if (body.size < 128) byteArrayOf(body.size.toByte()) else byteArrayOf(0x81.toByte(), body.size.toByte())
        return prefix + size + body
    }
    private fun status(body: ByteArray) = body + byteArrayOf(0x90.toByte(), 0)
    private fun context(card: Card, server: Server = Server(), test: (Long) -> Unit) {
        val handle = LpacJni.createContext(byteArrayOf(0xa0.toByte(), 0, 1), card, server)
        try { assertEquals(0, LpacJni.euiccInit(handle)); test(handle) }
        finally { LpacJni.destroyContext(handle) }
        assertEquals(1, card.closed)
        assertEquals(1, card.disconnected)
    }

    @Test fun profilesPreserveUtf8NullStringsAndListOwnership() {
        val card = Card()
        val name = "日本語 한국어 العربية 😀"
        val first = tlv(0xe3, tlv(0x5a, byteArrayOf(0x98.toByte(), 0x10)) + tlv(0x92, name.toByteArray()) + tlv(0x9f70, byteArrayOf(1)) + tlv(0x95, byteArrayOf(2)))
        val second = tlv(0xe3, tlv(0x5a, byteArrayOf(0x98.toByte(), 0x32)))
        card.respond = { status(tlv(0xbf2d, tlv(0xa0, first + second))) }
        context(card) { handle ->
            repeat(1000) {
                val head = LpacJni.es10cGetProfilesInfo(handle)
                assertNotEquals(0L, head)
                try {
                    assertEquals("8901", LpacJni.profileGetIccid(head))
                    assertEquals(name, LpacJni.profileGetName(head))
                    assertEquals("", LpacJni.profileGetNickname(head))
                    assertEquals("", LpacJni.profileGetServiceProvider(head))
                    assertEquals("", LpacJni.profileGetIsdpAid(head))
                    assertEquals("", LpacJni.profileGetIcon(head))
                    assertEquals("enabled", LpacJni.profileGetStateString(head))
                    assertEquals("operational", LpacJni.profileGetClassString(head))
                    val next = LpacJni.profilesNext(head)
                    assertEquals("8923", LpacJni.profileGetIccid(next))
                    assertEquals("unknown", LpacJni.profileGetStateString(next))
                    assertEquals(0L, LpacJni.profilesNext(next))
                } finally { assertEquals(0L, LpacJni.profilesFree(head)) }
            }
        }
    }

    @Test fun enableDisableAndRenamePreserveWireParameters() {
        val card = Card()
        card.respond = { status(tlv(((it[5].toInt() and 255) shl 8) or (it[6].toInt() and 255), tlv(0x80, byteArrayOf(0)))) }
        context(card) { handle ->
            val iccid = "89012345678901234567"
            assertEquals(0, LpacJni.es10cEnableProfile(handle, iccid, true))
            assertTrue(card.commands.last().takeLast(3).toByteArray().contentEquals(byteArrayOf(0x81.toByte(), 1, 0xff.toByte())))
            assertEquals(0, LpacJni.es10cDisableProfile(handle, iccid, false))
            assertTrue(card.commands.last().takeLast(3).toByteArray().contentEquals(byteArrayOf(0x81.toByte(), 1, 0)))
            assertEquals(0, LpacJni.es10cDeleteProfile(handle, iccid))
            val nickname = "旅行😀".toByteArray()
            assertEquals(0, LpacJni.es10cSetNickname(handle, iccid, nickname + byteArrayOf(0)))
            assertTrue(card.commands.last().takeLast(nickname.size).toByteArray().contentEquals(nickname))
            assertEquals(0, LpacJni.es10cEuiccMemoryReset(handle))
        }
    }

    @Test fun transportExceptionRetainsIdentityAndContextCanRecover() {
        val card = Card()
        context(card) { handle ->
            val failure = IllegalStateException("APDU failed")
            card.failure = failure
            try { LpacJni.es10cGetEid(handle); fail("exception expected") } catch (error: IllegalStateException) { assertSame(failure, error) }
            card.failure = null
            card.respond = { status(tlv(0xbf3e, tlv(0x5a, byteArrayOf(0x12, 0x34)))) }
            assertEquals("1234", LpacJni.es10cGetEid(handle))
        }
    }

    @Test fun failedInitializationAndRepeatedFiniReleaseOnce() {
        val card = Card().apply { failOpen = true }
        val handle = LpacJni.createContext(byteArrayOf(1), card, Server())
        assertEquals(-1, LpacJni.euiccInit(handle))
        LpacJni.destroyContext(handle)
        assertEquals(1, card.disconnected)
        assertEquals(0, card.closed)
        try { LpacJni.euiccInit(handle); fail("closed context expected") } catch (_: IllegalStateException) { }
        val second = Card()
        context(second) { LpacJni.euiccFini(it); LpacJni.euiccFini(it) }
    }

    @Test fun initializationExceptionsAreProbeFailuresAndReleaseTheSession() {
        for (failure in listOf(NoSuchElementException("No ISD-R"), SecurityException("Access denied"), IOException("Reader unavailable"))) {
            val card = Card().apply { openFailure = failure }
            try {
                LocalProfileAssistantImpl(byteArrayOf(1), card, Server())
                fail("initialization failure expected")
            } catch (error: IllegalArgumentException) {
                assertSame(failure, error.cause)
            }
            assertEquals(1, card.disconnected)
            assertEquals(0, card.closed)
            assertTrue(card.commands.isEmpty())
        }
    }

    @Test fun rejectedSimProbeKeepsTheOtherCardReadable() {
        val supported = Card().apply {
            respond = { tx -> status(when (tx[6].toInt() and 255) {
                0x22 -> tlv(0xbf22, listOf(0x81, 0x82, 0x83, 0x87, 0x04).fold(byteArrayOf()) { body, tag ->
                    body + tlv(tag, byteArrayOf(2, 2, 2))
                })
                0x3e -> tlv(0xbf3e, tlv(0x5a, byteArrayOf(0x12, 0x34)))
                else -> tlv(0xbf2d, tlv(0xa0, tlv(0xe3, tlv(0x5a, byteArrayOf(0x98.toByte(), 0x10)))))
            }) }
        }
        val lpa = LocalProfileAssistantImpl(byteArrayOf(1), supported, Server())
        try {
            val ordinary = Card().apply { openFailure = NoSuchElementException("No ISD-R") }
            try {
                LocalProfileAssistantImpl(byteArrayOf(1), ordinary, Server())
                fail("ordinary SIM must be rejected")
            } catch (_: IllegalArgumentException) { }
            assertEquals(1, ordinary.disconnected)
            assertTrue(lpa.valid)
            assertEquals("1234", lpa.eID)
            assertEquals("8901", lpa.profiles.single().iccid)
        } finally { lpa.close() }
        assertEquals(1, supported.closed)
        assertEquals(1, supported.disconnected)
    }

    @Test fun downloadCancellationAndCallbackExceptionsDoNotContinue() {
        val card = Card()
        context(card) { handle ->
            assertEquals(-255, LpacJni.downloadProfile(handle, "example.invalid", null, null, null) { false })
            assertTrue(card.commands.isEmpty())
            LpacJni.cancelSessions(handle)
            val failure = IllegalStateException("callback failed")
            try { LpacJni.downloadProfile(handle, "example.invalid", null, null, null) { throw failure }; fail("exception expected") }
            catch (error: IllegalStateException) { assertSame(failure, error) }
            assertTrue(card.commands.isEmpty())
            LpacJni.cancelSessions(handle)
        }
    }

    @Test fun httpCallbacksPreserveUrlHeadersAndExceptionIdentity() {
        val card = Card()
        card.respond = { tx -> status(if (tx[6] == 0x2e.toByte()) tlv(0xbf2e, tlv(0x80, ByteArray(16))) else tlv(0xbf20, byteArrayOf())) }
        val server = Server()
        context(card, server) { handle ->
            val phases = mutableListOf<ProfileDownloadState>()
            assertEquals(-255, LpacJni.downloadProfile(handle, "example.invalid", null, null, null) { phases += it; true })
            assertEquals(2, phases.size)
            assertEquals("https://example.invalid/gsma/rsp2/es9plus/initiateAuthentication", server.url)
            assertTrue(String(server.request).contains("euiccChallenge"))
            assertTrue(server.headers.contains("Content-Type: application/json"))
            LpacJni.cancelSessions(handle)
            val failure = IllegalStateException("HTTP failed")
            server.failure = failure
            try { LpacJni.downloadProfile(handle, "example.invalid", null, null, null) { true }; fail("exception expected") }
            catch (error: IllegalStateException) { assertSame(failure, error) }
            LpacJni.cancelSessions(handle)
        }
    }

    @Test fun notificationReadAndSendUseTheSameServerAndKeepDeletionExplicit() {
        val card = Card()
        val metadata = tlv(0xbf2f, tlv(0x80, byteArrayOf(42)) + tlv(0x81, byteArrayOf(0, 0x40)) + tlv(0x0c, "example.invalid".toByteArray()) + tlv(0x5a, byteArrayOf(0x98.toByte(), 0x10)))
        card.respond = { tx -> status(when (tx[6].toInt() and 255) {
            0x28 -> tlv(0xbf28, tlv(0xa0, metadata))
            0x2b -> tlv(0xbf2b, tlv(0xa0, tlv(0x30, metadata)))
            else -> tlv(0xbf30, tlv(0x80, byteArrayOf(0)))
        }) }
        val server = Server()
        context(card, server) { handle ->
            val head = LpacJni.es10bListNotification(handle)
            try {
                assertEquals(42L, LpacJni.notificationGetSeq(head))
                assertEquals("enable", LpacJni.notificationGetOperationString(head))
                assertEquals("example.invalid", LpacJni.notificationGetAddress(head))
                assertEquals("8901", LpacJni.notificationGetIccid(head))
                assertEquals(0L, LpacJni.notificationsNext(head))
            } finally { LpacJni.notificationsFree(head) }
            repeat(1000) { assertEquals(0, LpacJni.handleNotification(handle, 42)) }
            assertTrue(server.url.endsWith("/handleNotification"))
            assertFalse(card.commands.any { it[6] == 0x30.toByte() })
            assertEquals(0, LpacJni.es10bDeleteNotification(handle, 42))
        }
    }

    @Test fun euiccInfoVersionsMemoryAndCertificateArraysRoundTrip() {
        val card = Card()
        val version = tlv(0x81, byteArrayOf(2, 3, 4)) + tlv(0x82, byteArrayOf(2, 2, 2)) + tlv(0x83, byteArrayOf(1, 0, 0)) + tlv(0x87, byteArrayOf(2, 3, 0)) + tlv(0x04, byteArrayOf(1, 0, 1))
        val memory = tlv(0x84, tlv(0x82, byteArrayOf(1, 0)) + tlv(0x83, byteArrayOf(2, 0)))
        val keys = tlv(0xa9, tlv(0x04, byteArrayOf(1, 2)) + tlv(0x04, byteArrayOf(3, 4))) + tlv(0xaa, tlv(0x04, byteArrayOf(5, 6)))
        card.respond = { status(tlv(0xbf22, version + memory + keys + tlv(0x0c, "TEST".toByteArray()))) }
        context(card) { handle ->
            LpacJni.euiccSetMss(handle, 100)
            val info = LpacJni.es10cexGetEuiccInfo2(handle)
            assertNotEquals(0L, info)
            try {
                assertEquals("2.2.2", LpacJni.euiccInfo2GetSGP22Version(info))
                assertEquals("2.3.4", LpacJni.euiccInfo2GetProfileVersion(info))
                assertEquals("1.0.0", LpacJni.euiccInfo2GetEuiccFirmwareVersion(info))
                assertEquals("2.3.0", LpacJni.euiccInfo2GetGlobalPlatformVersion(info))
                assertEquals("1.0.1", LpacJni.euiccInfo2GetPpVersion(info))
                assertEquals("TEST", LpacJni.euiccInfo2GetSasAcreditationNumber(info))
                assertEquals(256L, LpacJni.euiccInfo2GetFreeNonVolatileMemory(info))
                assertEquals(512L, LpacJni.euiccInfo2GetFreeVolatileMemory(info))
                val signing = LpacJni.euiccInfo2GetEuiccCiPKIdListForSigning(info)
                assertEquals("0506", LpacJni.stringDeref(signing))
                assertEquals(0L, LpacJni.stringArrNext(signing))
                val verification = LpacJni.euiccInfo2GetEuiccCiPKIdListForVerification(info)
                assertEquals("0102", LpacJni.stringDeref(verification))
                val next = LpacJni.stringArrNext(verification)
                assertEquals("0304", LpacJni.stringDeref(next))
                assertEquals(0L, LpacJni.stringArrNext(next))
            } finally { LpacJni.euiccInfo2Free(info) }
            assertEquals("ES10B_ERROR_REASON_INSTALL_FAILED_DUE_TO_ICCID_MISMATCH", LpacJni.downloadErrCodeToString(13))
        }
    }
}

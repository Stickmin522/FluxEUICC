package im.angry.openeuicc.service

import kotlinx.coroutines.flow.flowOf
import net.typeblog.lpac_jni.impl.HttpInterfaceImpl
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.URL
import java.net.SocketTimeoutException
import java.security.cert.Certificate
import javax.net.ssl.HttpsURLConnection

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class HttpInterfaceTest {
    private class Connection(private val status: Int = 200, val failRead: Boolean = false) :
        HttpsURLConnection(URL("https://smdp.example.com")) {
        var disconnected = false
        var responseClosed = false
        val request = ByteArrayOutputStream()
        private val response = object : ByteArrayInputStream("response".toByteArray()) {
            override fun close() { responseClosed = true; super.close() }
        }
        override fun getOutputStream() = request
        override fun getResponseCode() = status
        override fun getInputStream(): InputStream {
            if (failRead) throw SocketTimeoutException()
            return response
        }
        override fun getErrorStream() = response
        override fun connect() {}
        override fun disconnect() { disconnected = true }
        override fun usingProxy() = false
        override fun getCipherSuite() = "TLS"
        override fun getLocalCertificates(): Array<Certificate>? = null
        override fun getServerCertificates(): Array<Certificate> = emptyArray()
    }

    private fun client(connection: Connection) =
        HttpInterfaceImpl(flowOf(true), flowOf(true), flowOf("")) { _, _ -> connection }

    @Test
    fun normalRequestsHaveReadTimeoutAndCloseResources() {
        val connection = Connection()
        val response = client(connection).transmit("https://smdp.example.com/download", byteArrayOf(1), emptyArray())
        assertEquals(200, response.rcode)
        assertEquals(30_000, connection.readTimeout)
        assertEquals(10_000, connection.connectTimeout)
        assertTrue(connection.responseClosed)
        assertTrue(connection.disconnected)
    }

    @Test
    fun httpErrorsPreserveStatusAndResponse() {
        val connection = Connection(400)
        val response = client(connection).transmit("https://smdp.example.com/download", byteArrayOf(), emptyArray())
        assertEquals(400, response.rcode)
        assertEquals("response", response.data.decodeToString())
        assertTrue(connection.responseClosed)
        assertTrue(connection.disconnected)
    }

    @Test
    fun readTimeoutClosesConnection() {
        val connection = Connection(failRead = true)
        assertThrows(SocketTimeoutException::class.java) {
            client(connection).transmit("https://smdp.example.com/download", byteArrayOf(), emptyArray())
        }
        assertTrue(connection.disconnected)
    }

    @Test
    fun verboseLoggingDoesNotExposeRequestOrResponseBodies() {
        org.robolectric.shadows.ShadowLog.clear()
        client(Connection()).transmit("https://smdp.example.com/download", "private-activation-code".toByteArray(), emptyArray())
        val messages = org.robolectric.shadows.ShadowLog.getLogs().joinToString { it.msg }
        assertFalse(messages.contains("private-activation-code"))
        assertFalse(messages.contains("HTTP response body"))
    }
}

package net.typeblog.lpac_jni.impl

import android.net.Uri
import android.util.Log
import androidx.core.net.toUri
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import net.typeblog.lpac_jni.HttpInterface
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.URL
import java.net.URLConnection
import java.security.SecureRandom
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLSocketFactory
import javax.net.ssl.TrustManager
import javax.net.ssl.TrustManagerFactory


class HttpInterfaceImpl(
    private val verboseLoggingFlow: Flow<Boolean>,
    private val ignoreTLSCertificateFlow: Flow<Boolean>,
    private val httpProxyFlow: Flow<String>,
    private val connectionFactory: (URL, Uri) -> HttpsURLConnection = { url, proxy ->
        url.openProxiedConnection(proxy) as HttpsURLConnection
    }
) : HttpInterface {
    companion object {
        private const val TAG = "HttpInterfaceImpl"
    }

    private lateinit var trustManagers: Array<TrustManager>

    override fun transmit(
        url: String,
        tx: ByteArray,
        headers: Array<String>
    ): HttpInterface.HttpResponse {
        if (runBlocking { verboseLoggingFlow.first() }) {
            Log.d(TAG, "HTTP POST: ${tx.size} bytes")
        }

        val parsedUrl = URL(url)
        if (parsedUrl.protocol != "https") {
            throw IllegalArgumentException("SM-DP+ servers must use the HTTPS protocol")
        }

        val proxy = runBlocking { httpProxyFlow.first().toUri().normalizeScheme() }
        val conn = connectionFactory(parsedUrl, proxy)
        try {
            conn.connectTimeout = 10_000
            conn.readTimeout = 30_000

            if (url.contains("handleNotification")) {
                conn.connectTimeout = 1000
                conn.readTimeout = 1000
            }

            conn.sslSocketFactory = getSocketFactory()
            conn.requestMethod = "POST"
            conn.doInput = true
            conn.doOutput = true

            for (h in headers) {
                val s = h.split(":", limit = 2)
                conn.setRequestProperty(s[0], s[1])
            }

            conn.outputStream.use { it.write(tx) }
            val status = conn.responseCode
            val response = if (status >= 400) conn.errorStream else conn.inputStream
            val bytes = response?.use { it.readBytes() } ?: byteArrayOf()
            if (runBlocking { verboseLoggingFlow.first() }) {
                Log.d(TAG, "HTTP response: status=$status, bytes=${bytes.size}")
            }
            return HttpInterface.HttpResponse(status, bytes)
        } catch (e: Exception) {
            Log.w(TAG, "HTTP request failed: ${e.javaClass.simpleName}")
            throw e
        } finally {
            conn.disconnect()
        }
    }

    private fun getSocketFactory(): SSLSocketFactory {
        val trustManagers =
            if (runBlocking { ignoreTLSCertificateFlow.first() }) {
                arrayOf(AllowAllTrustManager())
            } else {
                this.trustManagers
            }
        val sslContext = SSLContext.getInstance("TLS")
        sslContext.init(null, trustManagers, SecureRandom())
        return sslContext.socketFactory
    }

    override fun usePublicKeyIds(pkids: Array<String>) {
        val trustManagerFactory = TrustManagerFactory.getInstance("PKIX").apply {
            init(keyIdToKeystore(pkids))
        }
        trustManagers = trustManagerFactory.trustManagers
    }
}

private fun URL.openProxiedConnection(proxy: Uri): URLConnection {
    if (proxy.scheme == "direct") return openConnection(Proxy.NO_PROXY)
    if (proxy.scheme == null || proxy.host == null || proxy.port == -1) return openConnection()
    val type = when (proxy.scheme) {
        "http", "https" -> Proxy.Type.HTTP
        "socks", "socks5" -> Proxy.Type.SOCKS
        else -> return openConnection()
    }
    return openConnection(Proxy(type, InetSocketAddress(proxy.host, proxy.port)))
}

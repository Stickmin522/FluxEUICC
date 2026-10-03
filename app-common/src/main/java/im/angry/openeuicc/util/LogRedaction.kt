package im.angry.openeuicc.util

private val activationCode = Regex("""(?i)\bLPA:1[$][^\s]+""")
private val cardIdentifier = Regex("""(?<![\w])\d{15,32}(?![\w])""")
private val rawPayload = Regex("""(HTTP tx = |HTTP response body = |OMAPI APDU(?: response)?: |Received \d+ bytes: ).*""")

fun redactLog(text: String): String =
    text.replace(rawPayload, "$1[redacted]")
        .replace(activationCode, "[redacted]")
        .replace(cardIdentifier, "[redacted]")

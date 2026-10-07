package im.angry.openeuicc.flutter

internal data class SystemSimSlot(
    val physical: Int,
    val logical: Int?,
    val eid: String? = null,
    val iccid: String? = null,
)

internal object SimSlotResolver {
    fun readerSlot(name: String?): Int? {
        if (name == "SIM") return 0
        val number = name?.let { Regex("SIM([1-9][0-9]*)").matchEntire(it) }
            ?.groupValues?.get(1)?.toIntOrNull() ?: return null
        return number - 1
    }

    fun resolve(reader: String?, slots: List<SystemSimSlot>, eid: String, iccid: String?): Int? {
        val available = slots.filter { it.physical >= 0 }
        fun unique(matches: List<SystemSimSlot>) = matches.map { it.physical }.distinct().singleOrNull()
        if (eid.isNotBlank()) {
            unique(available.filter { it.eid == eid })?.let { return it }
        }
        if (!iccid.isNullOrBlank()) {
            unique(available.filter { it.iccid?.trimEnd('F', 'f') == iccid.trimEnd('F', 'f') })
                ?.let { return it }
        }
        val logical = readerSlot(reader) ?: return null
        return unique(available.filter { it.logical == logical }) ?: logical
    }
}

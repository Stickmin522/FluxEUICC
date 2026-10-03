package net.typeblog.lpac_jni.impl

internal inline fun <T> readNativeList(
    head: Long,
    next: (Long) -> Long,
    free: (Long) -> Unit,
    read: (Long) -> T
): List<T> {
    try {
        val items = mutableListOf<T>()
        var current = head
        while (current != 0L) {
            items += read(current)
            current = next(current)
        }
        return items
    } finally {
        free(head)
    }
}

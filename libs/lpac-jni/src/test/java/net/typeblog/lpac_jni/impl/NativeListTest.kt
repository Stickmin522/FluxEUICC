package net.typeblog.lpac_jni.impl

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class NativeListTest {
    @Test
    fun releasesHeadAfterTraversal() {
        var freed = -1L
        val items = readNativeList(1L, { if (it < 3) it + 1 else 0L }, { freed = it }) { it }
        assertEquals(listOf(1L, 2L, 3L), items)
        assertEquals(1L, freed)
    }

    @Test
    fun releasesHeadWhenDecodingFails() {
        var freed = -1L
        assertThrows(IllegalStateException::class.java) {
            readNativeList(1L, { it + 1 }, { freed = it }) {
                check(it != 2L)
                it
            }
        }
        assertEquals(1L, freed)
    }

    @Test
    fun handlesEmptyList() {
        val items = readNativeList(0L, { error("Unexpected traversal") }, {}) { it }
        assertEquals(emptyList<Long>(), items)
    }
}

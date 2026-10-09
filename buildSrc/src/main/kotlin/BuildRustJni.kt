import org.gradle.api.DefaultTask
import org.gradle.api.file.DirectoryProperty
import org.gradle.api.file.ConfigurableFileCollection
import org.gradle.api.provider.ListProperty
import org.gradle.api.provider.Property
import org.gradle.api.tasks.*
import org.gradle.process.ExecOperations
import javax.inject.Inject

abstract class BuildRustJni @Inject constructor(private val exec: ExecOperations) : DefaultTask() {
    @get:Input abstract val cargoExecutable: Property<String>
    @get:Input abstract val targets: ListProperty<String>
    @get:InputFiles @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val sources: ConfigurableFileCollection
    @get:Internal abstract val crateDirectory: DirectoryProperty
    @get:Internal abstract val ndkDirectory: DirectoryProperty
    @get:LocalState abstract val cargoBuildDirectory: DirectoryProperty
    @get:OutputDirectory abstract val outputDirectory: DirectoryProperty

    @TaskAction fun build() {
        val host = when {
            System.getProperty("os.name").startsWith("Windows") -> "windows-x86_64"
            System.getProperty("os.name").startsWith("Mac") -> "darwin-x86_64"
            else -> "linux-x86_64"
        }
        val llvm = ndkDirectory.get().asFile.resolve("toolchains/llvm/prebuilt/$host")
        val compiler = llvm.resolve("bin/clang" + if (host.startsWith("windows")) ".exe" else "")
        val out = outputDirectory.get().asFile
        require(out.toPath().normalize().startsWith(project.layout.buildDirectory.get().asFile.toPath().normalize()))
        out.deleteRecursively()
        for (abi in targets.get()) {
            val target = when (abi) {
                "arm64-v8a" -> "aarch64-linux-android"
                "x86_64" -> "x86_64-linux-android"
                else -> error("Unsupported ABI: $abi")
            }
            val flags = listOf(
                "-C", "link-arg=--target=${target}27",
                "-C", "link-arg=--sysroot=${llvm.resolve("sysroot")}",
                "-C", "link-arg=-Wl,-soname,liblpac-jni.so",
                "--remap-path-prefix=${project.rootDir}=/src/FluxEUICC"
            )
            exec.exec {
                workingDir(crateDirectory.get().asFile)
                commandLine(cargoExecutable.get(), "build", "--locked", "--release", "--target", target)
                environment("ANDROID_NDK_HOME", ndkDirectory.get().asFile.absolutePath)
                environment("CARGO_TARGET_DIR", cargoBuildDirectory.get().asFile.absolutePath)
                environment("CARGO_INCREMENTAL", "0")
                environment("CARGO_TARGET_${target.uppercase().replace('-', '_')}_LINKER", compiler.absolutePath)
                environment("CARGO_ENCODED_RUSTFLAGS", flags.joinToString("\u001f"))
            }
            val library = cargoBuildDirectory.get().asFile.resolve("$target/release/liblpac_jni.so")
            library.copyTo(out.resolve("$abi/liblpac-jni.so").also { it.parentFile.mkdirs() }, overwrite = true)
        }
    }
}

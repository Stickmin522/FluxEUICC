use std::{env, fs, path::PathBuf};

fn main() {
    let native = PathBuf::from("../src/main/jni");
    let android = env::var("CARGO_CFG_TARGET_OS").unwrap() == "android";
    let mut c = cc::Build::new();
    c.include(native.join("lpac"))
        .include(native.join("cjson"))
        .include(native.join("lpac/cjson-ext"))
        .flag("-fgnu89-inline")
        .warnings(false);
    if android {
        let ndk =
            PathBuf::from(env::var("ANDROID_NDK_HOME").expect("ANDROID_NDK_HOME is required"));
        let host = if cfg!(windows) {
            "windows-x86_64"
        } else if cfg!(target_os = "macos") {
            "darwin-x86_64"
        } else {
            "linux-x86_64"
        };
        let llvm = ndk.join("toolchains/llvm/prebuilt").join(host);
        let target = env::var("TARGET").unwrap();
        let clang_target = match target.as_str() {
            "aarch64-linux-android" => "aarch64-linux-android27",
            "x86_64-linux-android" => "x86_64-linux-android27",
            _ => panic!("unsupported Android target: {target}"),
        };
        c.compiler(llvm.join(if cfg!(windows) {
            "bin/clang.exe"
        } else {
            "bin/clang"
        }))
        .archiver(llvm.join(if cfg!(windows) {
            "bin/llvm-ar.exe"
        } else {
            "bin/llvm-ar"
        }))
        .flag(&format!("--target={clang_target}"))
        .flag(&format!("--sysroot={}", llvm.join("sysroot").display()));
        c.flag(&format!(
            "-ffile-prefix-map={}=/src/lpac-jni",
            env::current_dir().unwrap().parent().unwrap().display()
        ));
        println!("cargo:rustc-link-arg=-Wl,-z,max-page-size=16384");
        println!("cargo:rustc-link-arg=-Wl,-z,common-page-size=16384");
        println!("cargo:rustc-link-arg=-Wl,--build-id=none");
    } else if env::var("CARGO_CFG_TARGET_OS").unwrap() == "windows" {
        c.include("tests/host")
            .flag("/FItests/host/unistd.h")
            .define("inline", "");
    }
    for entry in fs::read_dir(native.join("lpac/euicc")).unwrap() {
        let path = entry.unwrap().path();
        if path.extension().is_some_and(|x| x == "c") {
            c.file(path);
        }
    }
    c.file(native.join("cjson/cjson/cJSON.c"))
        .file(native.join("cjson/cjson/cJSON_Utils.c"));
    for entry in fs::read_dir(native.join("lpac/cjson-ext/cjson-ext")).unwrap() {
        let path = entry.unwrap().path();
        if path.extension().is_some_and(|x| x == "c") {
            c.file(path);
        }
    }
    c.compile("euicc");
    let compiler = c.get_compiler();
    let mut bindings = bindgen::Builder::default()
        .header("wrapper.h")
        .clang_arg(format!("-I{}", native.join("lpac").display()))
        .allowlist_function("(euicc|es[0-9].*)_.*")
        .allowlist_type("(euicc|es[0-9].*)_.*")
        .allowlist_var("ES.*")
        .prepend_enum_name(false)
        .layout_tests(true)
        .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()));
    for arg in compiler.args() {
        let arg = arg.to_string_lossy();
        if arg.starts_with("--target=") || arg.starts_with("--sysroot=") {
            bindings = bindings.clang_arg(arg);
        }
    }
    if android {
        let clang = compiler
            .path()
            .parent()
            .unwrap()
            .parent()
            .unwrap()
            .join("lib/clang");
        let resource = fs::read_dir(clang)
            .unwrap()
            .map(|entry| entry.unwrap().path())
            .find(|path| path.join("include/stddef.h").is_file())
            .expect("NDK clang headers");
        bindings = bindings.clang_arg(format!("-resource-dir={}", resource.display()));
    }
    bindings
        .generate()
        .expect("libeuicc bindings")
        .write_to_file(PathBuf::from(env::var("OUT_DIR").unwrap()).join("bindings.rs"))
        .unwrap();
    println!("cargo:rerun-if-changed=wrapper.h");
    println!("cargo:rerun-if-changed={}", native.display());
    println!("cargo:rerun-if-env-changed=ANDROID_NDK_HOME");
}

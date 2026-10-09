//! JNI transport and lifecycle adapter for libeuicc.
mod context;
mod download;
mod exports;

#[allow(
    non_camel_case_types,
    non_snake_case,
    non_upper_case_globals,
    dead_code
)]
mod ffi {
    include!(concat!(env!("OUT_DIR"), "/bindings.rs"));
}

use jni::{objects::JString, sys::jstring, JNIEnv};
use std::{
    ffi::{c_char, CStr, CString},
    panic::{catch_unwind, AssertUnwindSafe},
};

type Result<T> = std::result::Result<T, Box<dyn std::error::Error + Send + Sync>>;

fn invalid(message: &str) -> Box<dyn std::error::Error + Send + Sync> {
    std::io::Error::new(std::io::ErrorKind::InvalidInput, message).into()
}

fn entry<'local, T: Copy>(
    mut env: JNIEnv<'local>,
    fallback: T,
    f: impl FnOnce(&mut JNIEnv<'local>) -> Result<T>,
) -> T {
    match catch_unwind(AssertUnwindSafe(|| f(&mut env))) {
        Ok(Ok(value)) => value,
        error => {
            if !env.exception_check().unwrap_or(true) {
                let message = match error {
                    Ok(Err(error)) => error.to_string(),
                    _ => "native adapter panicked".to_owned(),
                };
                let _ = env.throw_new("java/lang/IllegalStateException", message);
            }
            fallback
        }
    }
}

fn java_string(env: &mut JNIEnv, s: JString) -> Result<CString> {
    Ok(CString::new(String::from(env.get_string(&s)?))?)
}

fn optional_string(env: &mut JNIEnv, s: JString) -> Result<Option<CString>> {
    if s.is_null() {
        Ok(None)
    } else {
        java_string(env, s).map(Some)
    }
}

unsafe fn c_string(env: &JNIEnv, ptr: *const c_char) -> Result<jstring> {
    let text = if ptr.is_null() {
        Default::default()
    } else {
        CStr::from_ptr(ptr).to_string_lossy()
    };
    Ok(env.new_string(text)?.into_raw())
}

fn text(env: &JNIEnv, value: &str) -> Result<jstring> {
    Ok(env.new_string(value)?.into_raw())
}

unsafe fn checked<'a, T>(handle: i64) -> Result<&'a T> {
    (handle as *const T)
        .as_ref()
        .ok_or_else(|| invalid("null native value"))
}

unsafe fn native_bytes<'a>(ptr: *const u8, len: u32) -> &'a [u8] {
    if len == 0 {
        &[]
    } else {
        std::slice::from_raw_parts(ptr, len as usize)
    }
}

unsafe fn copy_response(bytes: &[u8], rx: *mut *mut u8, len: *mut u32) -> Result<()> {
    let count = u32::try_from(bytes.len())?;
    let ptr = libc::malloc(bytes.len().max(1)) as *mut u8;
    if ptr.is_null() {
        return Err(invalid("response allocation failed"));
    }
    std::ptr::copy_nonoverlapping(bytes.as_ptr(), ptr, bytes.len());
    *rx = ptr;
    *len = count;
    Ok(())
}

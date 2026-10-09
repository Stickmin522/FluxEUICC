use crate::{copy_response, ffi, invalid, native_bytes, Result};
use jni::{
    objects::{GlobalRef, JByteArray, JObject, JThrowable, JValue},
    JNIEnv, JavaVM,
};
use std::{
    collections::HashMap,
    ffi::{c_char, CString},
    panic::{catch_unwind, AssertUnwindSafe},
    ptr,
    sync::{
        atomic::{AtomicI32, AtomicI64, Ordering},
        Arc, Mutex, OnceLock,
    },
};

static VM: OnceLock<JavaVM> = OnceLock::new();
static CONTEXTS: OnceLock<Mutex<HashMap<i64, Arc<Mutex<Context>>>>> = OnceLock::new();
static NEXT_HANDLE: AtomicI64 = AtomicI64::new(1);

#[no_mangle]
pub unsafe extern "system" fn JNI_OnLoad(
    vm: *mut jni::sys::JavaVM,
    _: *mut std::ffi::c_void,
) -> i32 {
    match JavaVM::from_raw(vm) {
        Ok(vm) => {
            let _ = VM.set(vm);
            jni::sys::JNI_VERSION_1_6
        }
        Err(_) => jni::sys::JNI_ERR,
    }
}

enum CallbackError {
    Java(GlobalRef),
    Native(String),
}

pub struct Bridge {
    apdu: GlobalRef,
    http: GlobalRef,
    channel: AtomicI32,
    error: Mutex<Option<CallbackError>>,
}

pub struct Context {
    pub raw: Box<ffi::euicc_ctx>,
    bridge: Box<Bridge>,
    _aid: Vec<u8>,
    server: Option<CString>,
    initialized: bool,
}

// libeuicc is serialized by the context mutex. Callback state has separate storage.
unsafe impl Send for Context {}

impl Context {
    pub fn create(env: &mut JNIEnv, aid: Vec<u8>, apdu: JObject, http: JObject) -> Result<i64> {
        if aid.is_empty() || aid.len() > u8::MAX as usize {
            return Err(invalid("invalid ISD-R AID length"));
        }
        if apdu.is_null() || http.is_null() {
            return Err(invalid("missing transport interface"));
        }
        if VM.get().is_none() {
            let _ = VM.set(env.get_java_vm()?);
        }
        let mut bridge = Box::new(Bridge {
            apdu: env.new_global_ref(apdu)?,
            http: env.new_global_ref(http)?,
            channel: AtomicI32::new(-1),
            error: Mutex::new(None),
        });
        let mut raw: Box<ffi::euicc_ctx> = Box::new(unsafe { std::mem::zeroed() });
        raw.aid = aid.as_ptr();
        raw.aid_len = aid.len() as u8;
        raw.apdu.interface = &APDU;
        raw.http.interface = &HTTP;
        raw.userdata = (&mut *bridge as *mut Bridge).cast();
        let context = Self {
            raw,
            bridge,
            _aid: aid,
            server: None,
            initialized: false,
        };
        let handle = NEXT_HANDLE.fetch_add(1, Ordering::Relaxed);
        registry()
            .lock()
            .map_err(|_| invalid("context registry poisoned"))?
            .insert(handle, Arc::new(Mutex::new(context)));
        Ok(handle)
    }

    pub fn init(&mut self) -> i32 {
        let result = unsafe { ffi::euicc_init(&mut *self.raw) };
        self.initialized = result == 0;
        result
    }

    pub fn fini(&mut self) {
        if self.initialized {
            unsafe {
                ffi::euicc_fini(&mut *self.raw);
            }
            self.initialized = false;
        }
    }

    pub fn set_server(&mut self, address: Option<CString>) {
        self.server = address;
        self.raw.http.server_address = self.server.as_ref().map_or(ptr::null(), |s| s.as_ptr());
    }

    fn restore_error(&self, env: &mut JNIEnv) -> Result<()> {
        let error = self
            .bridge
            .error
            .lock()
            .map_err(|_| invalid("callback state poisoned"))?
            .take();
        if !env.exception_check()? {
            match error {
                Some(CallbackError::Java(exception)) => {
                    env.throw(<&JThrowable>::from(exception.as_obj()))?
                }
                Some(CallbackError::Native(message)) => {
                    env.throw_new("java/lang/IllegalStateException", message)?
                }
                None => (),
            }
        }
        Ok(())
    }
}

impl Drop for Context {
    fn drop(&mut self) {
        self.fini();
        unsafe {
            ffi::euicc_http_cleanup(&mut *self.raw);
        }
    }
}

fn registry() -> &'static Mutex<HashMap<i64, Arc<Mutex<Context>>>> {
    CONTEXTS.get_or_init(|| Mutex::new(HashMap::new()))
}

pub fn with_context<'local, T>(
    env: &mut JNIEnv<'local>,
    handle: i64,
    f: impl FnOnce(&mut JNIEnv<'local>, &mut Context) -> Result<T>,
) -> Result<T> {
    let context = registry()
        .lock()
        .map_err(|_| invalid("context registry poisoned"))?
        .get(&handle)
        .cloned()
        .ok_or_else(|| invalid("invalid or closed context"))?;
    let mut context = context.try_lock().map_err(|_| invalid("context is busy"))?;
    let result = f(env, &mut context);
    context.restore_error(env)?;
    result
}

pub fn destroy(env: &mut JNIEnv, handle: i64) -> Result<()> {
    // Release transports while callbacks still have a valid bridge.
    with_context(env, handle, |_, context| {
        context.fini();
        Ok(())
    })?;
    registry()
        .lock()
        .map_err(|_| invalid("context registry poisoned"))?
        .remove(&handle);
    Ok(())
}

impl Bridge {
    fn save_error(&self, error: CallbackError) {
        if let Ok(mut slot) = self.error.lock() {
            if slot.is_none() {
                *slot = Some(error);
            }
        }
    }

    fn call<T: Copy>(
        &self,
        fallback: T,
        ignore_error: bool,
        f: impl FnOnce(&mut JNIEnv) -> Result<T>,
    ) -> T {
        let result = catch_unwind(AssertUnwindSafe(|| -> Result<T> {
            let mut env = VM
                .get()
                .ok_or_else(|| invalid("Java VM unavailable"))?
                .attach_current_thread()?;
            env.with_local_frame(32, |env| {
                let result = f(env);
                if result.is_err() {
                    if env.exception_check()? {
                        let exception = env.exception_occurred()?;
                        env.exception_clear()?;
                        if !ignore_error {
                            self.save_error(CallbackError::Java(env.new_global_ref(exception)?));
                        }
                    } else if !ignore_error {
                        self.save_error(CallbackError::Native(
                            result.as_ref().err().unwrap().to_string(),
                        ));
                    }
                }
                result
            })
        }));
        match result {
            Ok(Ok(value)) => value,
            Ok(Err(error)) => {
                if !ignore_error {
                    self.save_error(CallbackError::Native(error.to_string()));
                }
                fallback
            }
            Err(_) => {
                if !ignore_error {
                    self.save_error(CallbackError::Native("transport callback panicked".into()));
                }
                fallback
            }
        }
    }
}

unsafe fn bridge<'a>(ctx: *mut ffi::euicc_ctx) -> &'a Bridge {
    &*((*ctx).userdata.cast::<Bridge>())
}

unsafe extern "C" fn connect(ctx: *mut ffi::euicc_ctx) -> i32 {
    let b = bridge(ctx);
    b.call(-1, false, |env| {
        env.call_method(b.apdu.as_obj(), "connect", "()V", &[])?;
        Ok(0)
    })
}
unsafe extern "C" fn disconnect(ctx: *mut ffi::euicc_ctx) {
    let b = bridge(ctx);
    b.call((), false, |env| {
        env.call_method(b.apdu.as_obj(), "disconnect", "()V", &[])?;
        Ok(())
    });
}
unsafe extern "C" fn open(ctx: *mut ffi::euicc_ctx, aid: *const u8, len: u8) -> i32 {
    let b = bridge(ctx);
    b.call(-1, false, |env| {
        let aid = env.byte_array_from_slice(native_bytes(aid, len as u32))?;
        let channel = env
            .call_method(
                b.apdu.as_obj(),
                "logicalChannelOpen",
                "([B)I",
                &[JValue::Object(aid.as_ref())],
            )?
            .i()?;
        b.channel.store(channel, Ordering::Relaxed);
        Ok(channel)
    })
}
unsafe extern "C" fn close(ctx: *mut ffi::euicc_ctx, _: u8) {
    let b = bridge(ctx);
    b.call((), true, |env| {
        env.call_method(
            b.apdu.as_obj(),
            "logicalChannelClose",
            "(I)V",
            &[JValue::Int(b.channel.load(Ordering::Relaxed))],
        )?;
        Ok(())
    });
}
unsafe extern "C" fn transmit(
    ctx: *mut ffi::euicc_ctx,
    rx: *mut *mut u8,
    rx_len: *mut u32,
    tx: *const u8,
    tx_len: u32,
) -> i32 {
    let b = bridge(ctx);
    b.call(-1, false, |env| {
        let tx = env.byte_array_from_slice(native_bytes(tx, tx_len))?;
        let response = env
            .call_method(
                b.apdu.as_obj(),
                "transmit",
                "(I[B)[B",
                &[
                    JValue::Int(b.channel.load(Ordering::Relaxed)),
                    JValue::Object(tx.as_ref()),
                ],
            )?
            .l()?;
        let bytes = env.convert_byte_array(JByteArray::from(response))?;
        copy_response(&bytes, rx, rx_len)?;
        Ok(0)
    })
}
unsafe extern "C" fn http_transmit(
    ctx: *mut ffi::euicc_ctx,
    url: *const c_char,
    rcode: *mut u32,
    rx: *mut *mut u8,
    rx_len: *mut u32,
    tx: *const u8,
    tx_len: u32,
    headers: *mut *const c_char,
) -> i32 {
    let b = bridge(ctx);
    b.call(-1, false, |env| {
        let url = jni::objects::JString::from_raw(crate::c_string(env, url)?);
        let tx = env.byte_array_from_slice(native_bytes(tx, tx_len))?;
        let mut count = 0;
        if !headers.is_null() { while !(*headers.add(count)).is_null() { count += 1; } }
        let array = env.new_object_array(i32::try_from(count)?, "java/lang/String", JObject::null())?;
        for i in 0..count {
            let header = jni::objects::JString::from_raw(crate::c_string(env, *headers.add(i))?);
            env.set_object_array_element(&array, i as i32, &header)?;
            env.delete_local_ref(header)?;
        }
        let response = env.call_method(b.http.as_obj(), "transmit", "(Ljava/lang/String;[B[Ljava/lang/String;)Lnet/typeblog/lpac_jni/HttpInterface$HttpResponse;", &[
            JValue::Object(url.as_ref()), JValue::Object(tx.as_ref()), JValue::Object(array.as_ref()),
        ])?.l()?;
        let status = env.get_field(&response, "rcode", "I")?.i()?;
        let bytes = env.get_field(&response, "data", "[B")?.l()?;
        copy_response(&env.convert_byte_array(JByteArray::from(bytes))?, rx, rx_len)?;
        *rcode = status as u32;
        Ok(0)
    })
}

static APDU: ffi::euicc_apdu_interface = ffi::euicc_apdu_interface {
    connect: Some(connect),
    disconnect: Some(disconnect),
    logic_channel_open: Some(open),
    logic_channel_close: Some(close),
    transmit: Some(transmit),
    userdata: ptr::null_mut(),
};
static HTTP: ffi::euicc_http_interface = ffi::euicc_http_interface {
    transmit: Some(http_transmit),
    userdata: ptr::null_mut(),
};
// Vtables are immutable; the unused userdata pointers are always null.
unsafe impl Sync for ffi::euicc_apdu_interface {}
unsafe impl Sync for ffi::euicc_http_interface {}

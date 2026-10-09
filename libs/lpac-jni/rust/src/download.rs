use crate::{c_string, context::Context, ffi, Result};
use jni::{
    objects::{JObject, JString, JValue},
    JNIEnv,
};
use std::{ffi::CString, ptr};

const UNDEFINED: i32 = -(ffi::ES10B_ERROR_REASON_UNDEFINED as i32);

#[derive(Clone, Copy, Debug, PartialEq)]
enum Phase {
    Preparing,
    Connecting,
    Authenticating,
    ConfirmingDownload,
    Downloading,
    Finalizing,
}

trait Download {
    fn notify(&mut self, phase: Phase) -> Result<bool>;
    fn challenge(&mut self) -> i32;
    fn initiate(&mut self) -> i32;
    fn authenticate_server(&mut self) -> i32;
    fn authenticate_client(&mut self) -> i32;
    fn prepare(&mut self) -> i32;
    fn get_package(&mut self) -> i32;
    fn load(&mut self) -> i32;
    fn cleanup(&mut self);
}

fn run(download: &mut impl Download) -> Result<i32> {
    macro_rules! notify {
        ($phase:ident) => {
            if !download.notify(Phase::$phase)? {
                return Ok(UNDEFINED);
            }
        };
    }
    notify!(Preparing);
    if download.challenge() < 0 {
        return Ok(UNDEFINED);
    }
    notify!(Connecting);
    if download.initiate() < 0 {
        return Ok(UNDEFINED);
    }
    notify!(Authenticating);
    if download.authenticate_server() < 0 || download.authenticate_client() < 0 {
        return Ok(UNDEFINED);
    }
    notify!(ConfirmingDownload);
    notify!(Downloading);
    if download.prepare() < 0 {
        return Ok(UNDEFINED);
    }
    let result = download.get_package();
    if result < 0 {
        return Ok(result);
    }
    notify!(Finalizing);
    let result = download.load();
    if result < 0 {
        return Ok(result);
    }
    download.cleanup();
    Ok(result)
}

struct Metadata(*mut ffi::es8p_metadata);
impl Drop for Metadata {
    fn drop(&mut self) {
        unsafe {
            ffi::es8p_metadata_free(&mut self.0);
        }
    }
}

struct NativeDownload<'a, 'local> {
    env: &'a mut JNIEnv<'local>,
    context: &'a mut Context,
    callback: JObject<'local>,
    matching: Option<CString>,
    imei: Option<CString>,
    confirmation: Option<CString>,
}
fn nullable(value: &Option<CString>) -> *const std::ffi::c_char {
    value.as_ref().map_or(ptr::null(), |s| s.as_ptr())
}

impl Download for NativeDownload<'_, '_> {
    fn notify(&mut self, phase: Phase) -> Result<bool> {
        self.env.with_local_frame(16, |env| {
            let state = if phase == Phase::ConfirmingDownload {
                let param = self.context.raw.http._internal.prepare_download_param;
                let mut remote = JObject::null();
                let mut metadata = Metadata(ptr::null_mut());
                unsafe {
                    if !param.is_null() && !(*param).b64_profileMetadata.is_null() {
                        if ffi::es8p_metadata_parse(&mut metadata.0, (*param).b64_profileMetadata) < 0 {
                            return Ok(false);
                        }
                        if metadata.0.is_null() { return Ok(false); }
                        let metadata = &*metadata.0;
                        let iccid = JString::from_raw(c_string(env, metadata.iccid.as_ptr())?);
                        let name = JString::from_raw(c_string(env, metadata.profileName)?);
                        let provider = JString::from_raw(c_string(env, metadata.serviceProviderName)?);
                        let class = match metadata.profileClass {
                            ffi::ES10C_PROFILE_CLASS_TEST => "Testing",
                            ffi::ES10C_PROFILE_CLASS_PROVISIONING => "Provisioning",
                            _ => "Operational",
                        };
                        let class = env.get_static_field("net/typeblog/lpac_jni/ProfileClass", class, "Lnet/typeblog/lpac_jni/ProfileClass;")?.l()?;
                        remote = env.new_object("net/typeblog/lpac_jni/RemoteProfileInfo", "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Lnet/typeblog/lpac_jni/ProfileClass;)V", &[
                            JValue::Object(iccid.as_ref()), JValue::Object(name.as_ref()), JValue::Object(provider.as_ref()), JValue::Object(&class),
                        ])?;
                    }
                }
                env.new_object("net/typeblog/lpac_jni/ProfileDownloadState$ConfirmingDownload", "(Lnet/typeblog/lpac_jni/RemoteProfileInfo;)V", &[JValue::Object(&remote)])?
            } else {
                let class = format!("net/typeblog/lpac_jni/ProfileDownloadState${phase:?}");
                env.new_object(class, "()V", &[])?
            };
            Ok(env.call_method(&self.callback, "onStatusUpdate", "(Lnet/typeblog/lpac_jni/ProfileDownloadState;)Z", &[JValue::Object(&state)])?.z()?)
        })
    }
    fn challenge(&mut self) -> i32 {
        unsafe { ffi::es10b_get_euicc_challenge_and_info(&mut *self.context.raw) }
    }
    fn initiate(&mut self) -> i32 {
        unsafe { ffi::es9p_initiate_authentication(&mut *self.context.raw) }
    }
    fn authenticate_server(&mut self) -> i32 {
        unsafe {
            ffi::es10b_authenticate_server(
                &mut *self.context.raw,
                nullable(&self.matching),
                nullable(&self.imei),
            )
        }
    }
    fn authenticate_client(&mut self) -> i32 {
        unsafe { ffi::es9p_authenticate_client(&mut *self.context.raw) }
    }
    fn prepare(&mut self) -> i32 {
        unsafe { ffi::es10b_prepare_download(&mut *self.context.raw, nullable(&self.confirmation)) }
    }
    fn get_package(&mut self) -> i32 {
        unsafe { ffi::es9p_get_bound_profile_package(&mut *self.context.raw) }
    }
    fn load(&mut self) -> i32 {
        unsafe {
            let mut result: ffi::es10b_load_bound_profile_package_result = std::mem::zeroed();
            result.errorReason = ffi::ES10B_ERROR_REASON_UNDEFINED;
            let code = ffi::es10b_load_bound_profile_package(&mut *self.context.raw, &mut result);
            libc::free(result.iccid.cast());
            if code < 0 {
                -(result.errorReason as i32)
            } else {
                code
            }
        }
    }
    fn cleanup(&mut self) {
        unsafe {
            ffi::euicc_http_cleanup(&mut *self.context.raw);
        }
    }
}

pub fn download<'local>(
    env: &mut JNIEnv<'local>,
    context: &mut Context,
    callback: JObject<'local>,
    address: CString,
    matching: Option<CString>,
    imei: Option<CString>,
    confirmation: Option<CString>,
) -> Result<i32> {
    context.set_server(Some(address));
    run(&mut NativeDownload {
        env,
        context,
        callback,
        matching,
        imei,
        confirmation,
    })
}

pub unsafe fn notification(context: &mut Context, seq: libc::c_ulong) -> i32 {
    struct Pending(ffi::es10b_pending_notification);
    impl Drop for Pending {
        fn drop(&mut self) {
            unsafe {
                ffi::es10b_pending_notification_free(&mut self.0);
            }
        }
    }
    let mut pending = Pending(std::mem::zeroed());
    let mut result = ffi::es10b_retrieve_notifications_list(&mut *context.raw, &mut pending.0, seq);
    if result >= 0 {
        context.raw.http.server_address = pending.0.notificationAddress;
        result =
            ffi::es9p_handle_notification(&mut *context.raw, pending.0.b64_PendingNotification);
    }
    ffi::euicc_http_cleanup(&mut *context.raw);
    context.set_server(None);
    result
}

#[cfg(test)]
mod tests {
    use super::*;
    struct Mock {
        phases: Vec<Phase>,
        stop: Option<Phase>,
        fail: usize,
        calls: usize,
        code: i32,
        cleaned: bool,
    }
    impl Mock {
        fn new() -> Self {
            Self {
                phases: vec![],
                stop: None,
                fail: 0,
                calls: 0,
                code: -13,
                cleaned: false,
            }
        }
        fn step(&mut self) -> i32 {
            self.calls += 1;
            if self.calls == self.fail {
                self.code
            } else {
                0
            }
        }
    }
    impl Download for Mock {
        fn notify(&mut self, phase: Phase) -> Result<bool> {
            self.phases.push(phase);
            Ok(self.stop != Some(phase))
        }
        fn challenge(&mut self) -> i32 {
            self.step()
        }
        fn initiate(&mut self) -> i32 {
            self.step()
        }
        fn authenticate_server(&mut self) -> i32 {
            self.step()
        }
        fn authenticate_client(&mut self) -> i32 {
            self.step()
        }
        fn prepare(&mut self) -> i32 {
            self.step()
        }
        fn get_package(&mut self) -> i32 {
            self.step()
        }
        fn load(&mut self) -> i32 {
            self.step()
        }
        fn cleanup(&mut self) {
            self.cleaned = true;
        }
    }
    const PHASES: [Phase; 6] = [
        Phase::Preparing,
        Phase::Connecting,
        Phase::Authenticating,
        Phase::ConfirmingDownload,
        Phase::Downloading,
        Phase::Finalizing,
    ];
    #[test]
    fn success_preserves_phase_order() {
        let mut m = Mock::new();
        assert_eq!(run(&mut m).unwrap(), 0);
        assert_eq!(m.phases, PHASES);
        assert!(m.cleaned);
    }
    #[test]
    fn cancellation_stops_at_every_phase_without_clearing_diagnostics() {
        for (i, phase) in PHASES.iter().enumerate() {
            let mut m = Mock::new();
            m.stop = Some(*phase);
            assert_eq!(run(&mut m).unwrap(), UNDEFINED);
            assert_eq!(m.phases, PHASES[..=i]);
            assert!(!m.cleaned);
        }
    }
    #[test]
    fn failures_preserve_package_and_install_error_codes() {
        for fail in 1..=7 {
            let mut m = Mock::new();
            m.fail = fail;
            assert_eq!(run(&mut m).unwrap(), if fail < 6 { UNDEFINED } else { -13 });
            assert_eq!(m.calls, fail);
            assert!(!m.cleaned);
        }
    }
}

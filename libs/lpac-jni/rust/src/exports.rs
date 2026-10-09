use crate::{
    c_string, checked,
    context::{self, Context},
    download, entry, ffi, invalid, java_string, optional_string, text,
};
use jni::{
    objects::{JByteArray, JObject, JString},
    sys::{jboolean, jbyte, jint, jlong, jstring},
    JNIEnv,
};
use std::ptr;

macro_rules! export {
    ($name:ident($env:ident, $($arg:ident: $ty:ty),* $(,)?) -> $ret:ty, $fallback:expr, $body:block) => {
        #[no_mangle]
        pub extern "system" fn $name<'local>(env: JNIEnv<'local>, _: JObject<'local>, $($arg: $ty),*) -> $ret {
            entry(env, $fallback, |$env| $body)
        }
    };
}

export!(
    Java_net_typeblog_lpac_1jni_LpacJni_createContext(
        env,
        aid: JByteArray<'local>,
        apdu: JObject<'local>,
        http: JObject<'local>,
    ) -> jlong,
    0,
    { Context::create(env, env.convert_byte_array(aid)?, apdu, http) }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_destroyContext(env, handle: jlong) -> (),
    (),
    { context::destroy(env, handle) }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_euiccInit(env, handle: jlong) -> jint,
    -1,
    { context::with_context(env, handle, |_, ctx| Ok(ctx.init())) }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_euiccFini(env, handle: jlong) -> (),
    (),
    {
        context::with_context(env, handle, |_, ctx| {
            ctx.fini();
            Ok(())
        })
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_euiccSetMss(env, handle: jlong, mss: jbyte) -> (),
    (),
    {
        if mss == 0 {
            return Err(invalid("APDU segment size must be nonzero"));
        }
        context::with_context(env, handle, |_, ctx| {
            ctx.raw.es10x_mss = mss as u8;
            Ok(())
        })
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_es10cGetEid(env, handle: jlong) -> jstring,
    ptr::null_mut(),
    {
        context::with_context(env, handle, |env, ctx| unsafe {
            let mut eid = ptr::null_mut();
            let code = ffi::es10c_get_eid(&mut *ctx.raw, &mut eid);
            let result = if code < 0 {
                Ok(ptr::null_mut())
            } else {
                c_string(env, eid)
            };
            libc::free(eid.cast());
            result
        })
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_es10cGetProfilesInfo(env, handle: jlong) -> jlong,
    0,
    {
        context::with_context(env, handle, |_, ctx| unsafe {
            let mut list = ptr::null_mut();
            if ffi::es10c_get_profiles_info(&mut *ctx.raw, &mut list) < 0 {
                Ok(0)
            } else {
                Ok(list as jlong)
            }
        })
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_es10cEnableProfile(
        env,
        handle: jlong,
        iccid: JString<'local>,
        refresh: jboolean,
    ) -> jint,
    -1,
    {
        let iccid = java_string(env, iccid)?;
        context::with_context(env, handle, |_, ctx| unsafe {
            Ok(ffi::es10c_enable_profile(
                &mut *ctx.raw,
                iccid.as_ptr(),
                u8::from(refresh != 0),
            ))
        })
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_es10cDisableProfile(
        env,
        handle: jlong,
        iccid: JString<'local>,
        refresh: jboolean,
    ) -> jint,
    -1,
    {
        let iccid = java_string(env, iccid)?;
        context::with_context(env, handle, |_, ctx| unsafe {
            Ok(ffi::es10c_disable_profile(
                &mut *ctx.raw,
                iccid.as_ptr(),
                u8::from(refresh != 0),
            ))
        })
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_es10cDeleteProfile(
        env,
        handle: jlong,
        iccid: JString<'local>,
    ) -> jint,
    -1,
    {
        let iccid = java_string(env, iccid)?;
        context::with_context(env, handle, |_, ctx| unsafe {
            Ok(ffi::es10c_delete_profile(&mut *ctx.raw, iccid.as_ptr()))
        })
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_es10cSetNickname(
        env,
        handle: jlong,
        iccid: JString<'local>,
        nick: JByteArray<'local>,
    ) -> jint,
    -1,
    {
        let iccid = java_string(env, iccid)?;
        let nick = env.convert_byte_array(nick)?;
        if nick.last() != Some(&0) {
            return Err(invalid("nickname must be NUL terminated"));
        }
        context::with_context(env, handle, |_, ctx| unsafe {
            Ok(ffi::es10c_set_nickname(
                &mut *ctx.raw,
                iccid.as_ptr(),
                nick.as_ptr().cast(),
            ))
        })
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_es10cEuiccMemoryReset(env, handle: jlong) -> jint,
    -1,
    {
        context::with_context(env, handle, |_, ctx| unsafe {
            Ok(ffi::es10c_euicc_memory_reset(&mut *ctx.raw))
        })
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_es10cexGetEuiccInfo2(env, handle: jlong) -> jlong,
    0,
    {
        context::with_context(env, handle, |_, ctx| unsafe {
            let mut info: Box<ffi::es10c_ex_euiccinfo2> = Box::new(std::mem::zeroed());
            if ffi::es10c_ex_get_euiccinfo2(&mut *ctx.raw, &mut *info) < 0 {
                Ok(0)
            } else {
                Ok(Box::into_raw(info) as jlong)
            }
        })
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_downloadProfile(
        env,
        handle: jlong,
        address: JString<'local>,
        matching: JString<'local>,
        imei: JString<'local>,
        confirmation: JString<'local>,
        callback: JObject<'local>,
    ) -> jint,
    -255,
    {
        let address = java_string(env, address)?;
        let matching = optional_string(env, matching)?;
        let imei = optional_string(env, imei)?;
        let confirmation = optional_string(env, confirmation)?;
        context::with_context(env, handle, |env, ctx| {
            download::download(env, ctx, callback, address, matching, imei, confirmation)
        })
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_cancelSessions(env, handle: jlong) -> (),
    (),
    {
        context::with_context(env, handle, |_, ctx| unsafe {
            ffi::es9p_cancel_session(&mut *ctx.raw);
            ffi::es10b_cancel_session(&mut *ctx.raw, ffi::ES10B_CANCEL_SESSION_REASON_UNDEFINED);
            ffi::euicc_http_cleanup(&mut *ctx.raw);
            ctx.set_server(None);
            Ok(())
        })
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_es10bListNotification(env, handle: jlong) -> jlong,
    0,
    {
        context::with_context(env, handle, |_, ctx| unsafe {
            let mut list = ptr::null_mut();
            if ffi::es10b_list_notification(&mut *ctx.raw, &mut list) < 0 {
                Ok(0)
            } else {
                Ok(list as jlong)
            }
        })
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_es10bDeleteNotification(
        env,
        handle: jlong,
        seq: jlong,
    ) -> jint,
    -1,
    {
        context::with_context(env, handle, |_, ctx| unsafe {
            Ok(ffi::es10b_remove_notification_from_list(
                &mut *ctx.raw,
                seq as libc::c_ulong,
            ))
        })
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_handleNotification(env, handle: jlong, seq: jlong) -> jint,
    -1,
    {
        context::with_context(env, handle, |_, ctx| unsafe {
            Ok(download::notification(ctx, seq as libc::c_ulong))
        })
    }
);

macro_rules! string_field {
    ($name:ident, $ty:ty, $($field:ident).+) => {
        export!($name(env, value: jlong) -> jstring, ptr::null_mut(), {
            unsafe { c_string(env, checked::<$ty>(value)?.$($field).+) }
        });
    };
}
macro_rules! array_field {
    ($name:ident, $ty:ty, $field:ident) => {
        export!($name(env, value: jlong) -> jstring, ptr::null_mut(), {
            unsafe { c_string(env, checked::<$ty>(value)?.$field.as_ptr()) }
        });
    };
}
macro_rules! long_field {
    ($name:ident, $ty:ty, $($field:ident).+) => {
        export!($name(_env, value: jlong) -> jlong, 0, {
            unsafe { Ok(checked::<$ty>(value)?.$($field).+ as jlong) }
        });
    };
}

long_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_profilesNext,
    ffi::es10c_profile_info_list,
    next
);
array_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_profileGetIccid,
    ffi::es10c_profile_info_list,
    iccid
);
array_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_profileGetIsdpAid,
    ffi::es10c_profile_info_list,
    isdpAid
);
string_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_profileGetName,
    ffi::es10c_profile_info_list,
    profileName
);
string_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_profileGetNickname,
    ffi::es10c_profile_info_list,
    profileNickname
);
string_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_profileGetServiceProvider,
    ffi::es10c_profile_info_list,
    serviceProviderName
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_profileGetStateString(env, value: jlong) -> jstring,
    ptr::null_mut(),
    {
        let value = unsafe { checked::<ffi::es10c_profile_info_list>(value)? };
        text(
            env,
            match value.profileState {
                ffi::ES10C_PROFILE_STATE_ENABLED => "enabled",
                ffi::ES10C_PROFILE_STATE_DISABLED => "disabled",
                _ => "unknown",
            },
        )
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_profileGetClassString(env, value: jlong) -> jstring,
    ptr::null_mut(),
    {
        let value = unsafe { checked::<ffi::es10c_profile_info_list>(value)? };
        text(
            env,
            match value.profileClass {
                ffi::ES10C_PROFILE_CLASS_TEST => "test",
                ffi::ES10C_PROFILE_CLASS_PROVISIONING => "provisioning",
                ffi::ES10C_PROFILE_CLASS_OPERATIONAL => "operational",
                _ => "unknown",
            },
        )
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_profileGetIcon(env, value: jlong) -> jstring,
    ptr::null_mut(),
    {
        let value = unsafe { checked::<ffi::es10c_profile_info_list>(value)? };
        unsafe {
            c_string(
                env,
                if matches!(
                    value.iconType,
                    ffi::ES10C_ICON_TYPE_PNG | ffi::ES10C_ICON_TYPE_JPEG
                ) {
                    value.icon
                } else {
                    ptr::null()
                },
            )
        }
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_profilesFree(_env, value: jlong) -> jlong,
    0,
    {
        unsafe {
            ffi::es10c_profile_info_list_free_all(value as *mut _);
        }
        Ok(0)
    }
);

long_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_notificationsNext,
    ffi::es10b_notification_metadata_list,
    next
);
long_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_notificationGetSeq,
    ffi::es10b_notification_metadata_list,
    seqNumber
);
string_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_notificationGetAddress,
    ffi::es10b_notification_metadata_list,
    notificationAddress
);
string_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_notificationGetIccid,
    ffi::es10b_notification_metadata_list,
    iccid
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_notificationGetOperationString(
        env,
        value: jlong,
    ) -> jstring,
    ptr::null_mut(),
    {
        let value = unsafe { checked::<ffi::es10b_notification_metadata_list>(value)? };
        text(
            env,
            match value.profileManagementOperation {
                ffi::ES10B_PROFILE_MANAGEMENT_OPERATION_INSTALL => "install",
                ffi::ES10B_PROFILE_MANAGEMENT_OPERATION_ENABLE => "enable",
                ffi::ES10B_PROFILE_MANAGEMENT_OPERATION_DISABLE => "disable",
                ffi::ES10B_PROFILE_MANAGEMENT_OPERATION_DELETE => "delete",
                _ => "unknown",
            },
        )
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_notificationsFree(_env, value: jlong) -> (),
    (),
    {
        unsafe {
            ffi::es10b_notification_metadata_list_free_all(value as *mut _);
        }
        Ok(())
    }
);

string_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_euiccInfo2GetSGP22Version,
    ffi::es10c_ex_euiccinfo2,
    svn
);
string_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_euiccInfo2GetProfileVersion,
    ffi::es10c_ex_euiccinfo2,
    profileVersion
);
string_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_euiccInfo2GetEuiccFirmwareVersion,
    ffi::es10c_ex_euiccinfo2,
    euiccFirmwareVer
);
string_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_euiccInfo2GetGlobalPlatformVersion,
    ffi::es10c_ex_euiccinfo2,
    globalplatformVersion
);
string_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_euiccInfo2GetSasAcreditationNumber,
    ffi::es10c_ex_euiccinfo2,
    sasAcreditationNumber
);
string_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_euiccInfo2GetPpVersion,
    ffi::es10c_ex_euiccinfo2,
    ppVersion
);
long_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_euiccInfo2GetFreeNonVolatileMemory,
    ffi::es10c_ex_euiccinfo2,
    extCardResource.freeNonVolatileMemory
);
long_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_euiccInfo2GetFreeVolatileMemory,
    ffi::es10c_ex_euiccinfo2,
    extCardResource.freeVolatileMemory
);
long_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_euiccInfo2GetEuiccCiPKIdListForSigning,
    ffi::es10c_ex_euiccinfo2,
    euiccCiPKIdListForSigning
);
long_field!(
    Java_net_typeblog_lpac_1jni_LpacJni_euiccInfo2GetEuiccCiPKIdListForVerification,
    ffi::es10c_ex_euiccinfo2,
    euiccCiPKIdListForVerification
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_euiccInfo2Free(_env, value: jlong) -> (),
    (),
    {
        if value != 0 {
            unsafe {
                let mut info = Box::from_raw(value as *mut ffi::es10c_ex_euiccinfo2);
                ffi::es10c_ex_euiccinfo2_free(&mut *info);
            }
        }
        Ok(())
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_stringDeref(env, value: jlong) -> jstring,
    ptr::null_mut(),
    { unsafe { c_string(env, *checked::<*const std::ffi::c_char>(value)?) } }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_stringArrNext(_env, value: jlong) -> jlong,
    0,
    {
        unsafe {
            checked::<*const std::ffi::c_char>(value)?;
            let next = (value as *const *const std::ffi::c_char).add(1);
            Ok(if (*next).is_null() { 0 } else { next as jlong })
        }
    }
);
export!(
    Java_net_typeblog_lpac_1jni_LpacJni_downloadErrCodeToString(env, code: jint) -> jstring,
    ptr::null_mut(),
    { text(env, error_name(code)) }
);

fn error_name(code: i32) -> &'static str {
    macro_rules! names { ($($variant:ident),* $(,)?) => {
        match code { $(x if x == ffi::$variant as i32 => stringify!($variant),)* _ => "ES10B_ERROR_REASON_UNDEFINED" }
    }; }
    names!(
        ES10B_ERROR_REASON_INCORRECT_INPUT_VALUES,
        ES10B_ERROR_REASON_INVALID_SIGNATURE,
        ES10B_ERROR_REASON_INVALID_TRANSACTION_ID,
        ES10B_ERROR_REASON_UNSUPPORTED_CRT_VALUES,
        ES10B_ERROR_REASON_UNSUPPORTED_REMOTE_OPERATION_TYPE,
        ES10B_ERROR_REASON_UNSUPPORTED_PROFILE_CLASS,
        ES10B_ERROR_REASON_SCP03T_STRUCTURE_ERROR,
        ES10B_ERROR_REASON_SCP03T_SECURITY_ERROR,
        ES10B_ERROR_REASON_INSTALL_FAILED_DUE_TO_ICCID_ALREADY_EXISTS_ON_EUICC,
        ES10B_ERROR_REASON_INSTALL_FAILED_DUE_TO_INSUFFICIENT_MEMORY_FOR_PROFILE,
        ES10B_ERROR_REASON_INSTALL_FAILED_DUE_TO_INTERRUPTION,
        ES10B_ERROR_REASON_INSTALL_FAILED_DUE_TO_PE_PROCESSING_ERROR,
        ES10B_ERROR_REASON_INSTALL_FAILED_DUE_TO_ICCID_MISMATCH,
        ES10B_ERROR_REASON_TEST_PROFILE_INSTALL_FAILED_DUE_TO_INVALID_NAA_KEY,
        ES10B_ERROR_REASON_PPR_NOT_ALLOWED,
        ES10B_ERROR_REASON_INSTALL_FAILED_DUE_TO_UNKNOWN_ERROR
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn legacy_iccid_mismatch_name_is_preserved() {
        assert_eq!(
            error_name(13),
            "ES10B_ERROR_REASON_INSTALL_FAILED_DUE_TO_ICCID_MISMATCH"
        );
    }
    #[test]
    fn unknown_error_is_undefined() {
        assert_eq!(error_name(-1), "ES10B_ERROR_REASON_UNDEFINED");
    }
}

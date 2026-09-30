APP_ABI := arm64-v8a x86_64
APP_SHORT_COMMANDS := true
APP_CFLAGS := -Wno-compound-token-split-by-macro
APP_LDFLAGS := -Wl,--build-id=none -z muldefs -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384
APP_SUPPORT_FLEXIBLE_PAGE_SIZES := true

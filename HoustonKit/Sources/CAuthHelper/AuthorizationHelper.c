#include "AuthorizationHelper.h"
#include <Security/Authorization.h>
#include <dlfcn.h>

// AuthorizationExecuteWithPrivileges is unavailable from Swift but the symbol
// still exists in the Security framework. We load it via dlsym so we can use
// the native macOS auth dialog, which supports Touch ID on Apple Silicon.

typedef OSStatus (*AuthExecFn)(
    AuthorizationRef authorization,
    const char *pathToTool,
    AuthorizationFlags options,
    char *const *arguments,
    FILE **communicationsPipe
);

OSStatus AuthorizationExecuteCommand(
    AuthorizationRef authorization,
    const char *pathToTool,
    const char *flag,
    const char *command,
    FILE * _Nullable * _Nullable communicationsPipe
) {
    static AuthExecFn fn = NULL;
    if (!fn) {
        fn = dlsym(RTLD_DEFAULT, "AuthorizationExecuteWithPrivileges");
        if (!fn) return errAuthorizationInternal;
    }
    char *const argv[] = { (char *)flag, (char *)command, NULL };
    return fn(authorization, pathToTool, kAuthorizationFlagDefaults, argv, communicationsPipe);
}

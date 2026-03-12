#ifndef AuthorizationHelper_h
#define AuthorizationHelper_h

#include <Security/Authorization.h>
#include <stdio.h>

#pragma clang assume_nonnull begin

/// Wrapper around the deprecated AuthorizationExecuteWithPrivileges.
/// This function still exists in the Security framework and is the only way
/// to run a command as root with the native macOS auth dialog (Touch ID).
OSStatus AuthorizationExecuteCommand(
    AuthorizationRef authorization,
    const char *pathToTool,
    const char *flag,
    const char *command,
    FILE * _Nullable * _Nullable communicationsPipe
);

#pragma clang assume_nonnull end

#endif

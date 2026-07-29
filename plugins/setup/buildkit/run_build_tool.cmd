@echo off
setlocal

setlocal ENABLEDELAYEDEXPANSION

SET BASEDIR=%~dp0
if not defined PROJECT_DIR SET PROJECT_DIR=%CD%

if not exist "%PROJECT_DIR%\pubspec.yaml" (
    echo Error: Could not find project root at "%PROJECT_DIR%"
    exit /b 1
)
if not exist "%PROJECT_DIR%\core\" (
    echo Error: Could not find core directory at "%PROJECT_DIR%\core"
    exit /b 1
)

SET BUILD_TOOL_PKG_DIR=%BASEDIR%build_tool
SET BUILD_TOOL_TEMP_DIR=%PROJECT_DIR%\build\setup_build_tool

if not exist "%BUILD_TOOL_TEMP_DIR%" (
    mkdir "%BUILD_TOOL_TEMP_DIR%"
)
cd /D "%BUILD_TOOL_TEMP_DIR%"

REM Prefer Flutter's bundled Dart over anything on PATH, so we never silently
REM build against an unrelated standalone SDK. Every invocation below uses CALL:
REM dart.bat is a batch file, and invoking one from a .cmd without CALL transfers
REM control permanently, which would make this script exit after the first call.
if not defined DART (
    if defined FLUTTER_ROOT (
        if exist "%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe" (
            set "DART=%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe"
        )
    )
)

if not defined DART (
    if defined FLUTTER_ROOT (
        if exist "%FLUTTER_ROOT%\bin\dart.bat" (
            set "DART=%FLUTTER_ROOT%\bin\dart.bat"
        )
    )
)

if not defined DART (
    for /f "delims=" %%i in ('where dart.exe 2^>nul') do (
        if not defined DART set "DART=%%i"
    )
)

if not defined DART (
    for /f "delims=" %%i in ('where dart.bat 2^>nul') do (
        if not defined DART set "DART=%%i"
    )
)

if not defined DART (
    echo Error: Could not find a Dart SDK. Set FLUTTER_ROOT or put dart on PATH.
    exit /b 1
)

set BUILD_TOOL_PKG_DIR_POSIX=%BUILD_TOOL_PKG_DIR:\=/%

(
    echo name: setup_build_tool_runner
    echo version: 1.0.0
    echo publish_to: none
    echo.
    echo environment:
    echo   sdk: '^>=3.0.0 ^<4.0.0'
    echo.
    echo dependencies:
    echo   build_tool:
    echo     path: %BUILD_TOOL_PKG_DIR_POSIX%
) >pubspec.yaml

if not exist bin (
    mkdir bin
)

(
    echo import 'package:build_tool/build_tool.dart' as build_tool;
    echo void main^(List^<String^> args^) ^{
    echo    build_tool.runMain^(args^);
    echo ^}
) >bin\build_tool_runner.dart

SET PRECOMPILED=bin\build_tool_runner.dill

REM To detect changes in package we compare output of DIR /s (recursive)
set PREV_PACKAGE_INFO=.dart_tool\package_info.prev
set CUR_PACKAGE_INFO=.dart_tool\package_info.cur

if not exist ".dart_tool" (
    mkdir ".dart_tool"
)

DIR "%BUILD_TOOL_PKG_DIR%" /s > "%CUR_PACKAGE_INFO%_orig"

REM Last line in dir output is free space on harddrive. That is bound to
REM change between invocation so we need to remove it
(
    Set "Line="
    For /F "UseBackQ Delims=" %%A In ("%CUR_PACKAGE_INFO%_orig") Do (
        SetLocal EnableDelayedExpansion
        If Defined Line Echo !Line!
        EndLocal
        Set "Line=%%A")
) >"%CUR_PACKAGE_INFO%"
DEL "%CUR_PACKAGE_INFO%_orig"

REM Compare current directory listing with previous
FC /B "%CUR_PACKAGE_INFO%" "%PREV_PACKAGE_INFO%" > nul 2>&1

If %ERRORLEVEL% neq 0 (
    REM Changed - copy current to previous and remove precompiled kernel
    if exist "%PREV_PACKAGE_INFO%" (
        DEL "%PREV_PACKAGE_INFO%"
    )
    MOVE /Y "%CUR_PACKAGE_INFO%" "%PREV_PACKAGE_INFO%"
    if exist "%PRECOMPILED%" (
        DEL "%PRECOMPILED%"
    )
)

REM There is no CUR_PACKAGE_INFO it was renamed in previous step to %PREV_PACKAGE_INFO%
REM which means we need to do pub get and precompile
if not exist "%PRECOMPILED%" (
    echo Running pub get in "%cd%"
    call "%DART%" pub get --no-precompile
    call "%DART%" compile kernel bin\build_tool_runner.dart
)

call "%DART%" "%PRECOMPILED%" %* --root-dir "%PROJECT_DIR%"

REM 253 means invalid snapshot version.
If %ERRORLEVEL% equ 253 (
    call "%DART%" pub get --no-precompile
    call "%DART%" compile kernel bin\build_tool_runner.dart
    call "%DART%" "%PRECOMPILED%" %* --root-dir "%PROJECT_DIR%"
)
exit /b %ERRORLEVEL%

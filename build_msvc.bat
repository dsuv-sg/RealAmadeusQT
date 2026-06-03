@echo off
setlocal enabledelayedexpansion

:: build_msvc.bat — MSVC 2022 64-bit + Ninja build wrapper for RealAmadeusPC
:: Usage: build_msvc.bat [cmake-args...]

set VSWHERE="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist %VSWHERE% (
    echo vswhere.exe not found. Ensure Visual Studio 2022 is installed.
    exit /b 1
)

for /f "usebackq delims=" %%i in (`%VSWHERE% -latest -property installationPath`) do set VS_INSTALL=%%i
if not defined VS_INSTALL (
    echo Visual Studio installation not found.
    exit /b 1
)

call "%VS_INSTALL%\VC\Auxiliary\Build\vcvars64.bat" || exit /b 1

set BUILD_DIR=build\Desktop_Qt_6_10_1_MSVC2022_64bit-Release

if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

cmake -S . -B "%BUILD_DIR%" ^
    -G Ninja ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_PREFIX_PATH=C:\Qt\6.10.1\msvc2022_64 ^
    -DCMAKE_CXX_FLAGS="/Zm2000" ^
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 ^
    %* || exit /b 1

cmake --build "%BUILD_DIR%" %*

@echo off
setlocal enabledelayedexpansion

:: build_mingw.bat — MinGW 64-bit + Ninja build wrapper for RealAmadeusPC
:: Usage: build_mingw.bat [cmake-args...]

set PATH=C:\Qt\Tools\mingw1310_64\bin;C:\Qt\Tools\CMake_64\bin;C:\Qt\Tools\Ninja;%PATH%

set BUILD_DIR=build\Desktop_Qt_6_10_1_MinGW_64bit-Release

if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

cmake -S . -B "%BUILD_DIR%" ^
    -G Ninja ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_PREFIX_PATH=C:\Qt\6.10.1\mingw_64 ^
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 ^
    %* || exit /b 1

cmake --build "%BUILD_DIR%" %*

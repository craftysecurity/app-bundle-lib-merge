#!/bin/bash

usage() {
    echo "Usage: $0 [-s <device>] <package_name>"
    exit 1
}

# Parse command-line arguments
DEVICE=""
while getopts "s:" opt; do
    case ${opt} in
        s )
            DEVICE="-s $OPTARG"
            ;;
        \? )
            usage
            ;;
    esac
done
shift $((OPTIND -1))

# Check if package name is provided
if [ -z "$1" ]; then
    usage
fi

PACKAGE_NAME=$1

# If no device specified, check connected devices
if [ -z "$DEVICE" ]; then
    DEVICE_COUNT=$(adb devices | grep -w "device" | wc -l)
    
    if [ "$DEVICE_COUNT" -eq 0 ]; then
        echo "No devices connected. Please connect a device or specify one with -s."
        exit 1
    elif [ "$DEVICE_COUNT" -eq 1 ]; then
        echo "One device connected. Proceeding with the connected device."
    else
        echo "Multiple devices detected. Please specify a device with -s."
        adb devices
        exit 1
    fi
fi

# Locate the APK path using adb
echo "Locating APK path for package: $PACKAGE_NAME"
APK_PATH=$(adb $DEVICE shell pm path $PACKAGE_NAME | grep base | cut -d: -f2)

if [ -z "$APK_PATH" ]; then
    echo "Package not found or APK path could not be located."
    exit 1
fi

echo "APK located at: $APK_PATH"

# Pull the APK file
echo "Pulling APK..."
adb $DEVICE pull "$APK_PATH" ./base.apk


APP_BASE_DIR=$(dirname "$APK_PATH")

# Check if the APK is part of an app bundle and pull libraries if found
echo "Checking if the APK is part of an app bundle..."
LIB_DIRS=$(adb $DEVICE shell "find $APP_BASE_DIR/lib/ -type f -name '*.so'" 2>/dev/null)

if [ -n "$LIB_DIRS" ]; then
    echo "App bundle detected. Pulling libraries..."
    for LIB_DIR in $LIB_DIRS; do
        TARGET_DIR="./base/lib/$(dirname "$LIB_DIR" | sed 's|.*lib/||')"
        mkdir -p "$TARGET_DIR"
        adb $DEVICE pull "$LIB_DIR" "$TARGET_DIR/"
    done
    

    echo "Repacking APK with libraries..."
    cd base
    zip -r ../base.apk ./
    cd ..
    

    rm -rf base/lib
else
    echo "No external libraries found, or APK is not part of an app bundle."
fi

# Additional function to search /data/data/com.exampleapp.android/ for .so files
echo "Searching /data/data/$PACKAGE_NAME/ for .so files..."
DATA_LIBS=$(adb $DEVICE shell "find /data/data/$PACKAGE_NAME/ -type f -name '*.so'" 2>/dev/null)

if [ -n "$DATA_LIBS" ]; then
    echo "Found .so files in /data/data/$PACKAGE_NAME/. Pulling and repacking..."
    for LIB in $DATA_LIBS; do
        TARGET_DIR="./data-dir-libs/$(dirname "$LIB" | sed 's|/data/data/||')"
        mkdir -p "$TARGET_DIR"
        adb $DEVICE pull "$LIB" "$TARGET_DIR/"
    done
    
    # Repackage the APK with the new libraries
    echo "Repacking APK with data-dir libraries..."
    cd data-dir-libs
    zip -r ../base.apk ./
    cd ..
    

    rm -rf data-dir-libs
else
    echo "No .so files found in /data/data/$PACKAGE_NAME/."
fi

echo "APK pull and repacking complete. Check the 'base.apk' file for the integrated content."

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

# Locate APK path and any split APKs
echo "Locating APK paths for package: $PACKAGE_NAME"
APK_PATHS=$(adb $DEVICE shell pm path $PACKAGE_NAME | cut -d: -f2)

if [ -z "$APK_PATHS" ]; then
    echo "Package not found or APK paths could not be located."
    exit 1
fi

echo "APK paths located:"
echo "$APK_PATHS"

# Pull all APKs (base and split APKs)
for APK_PATH in $APK_PATHS; do
    APK_NAME=$(basename "$APK_PATH")
    echo "Pulling $APK_NAME..."
    adb $DEVICE pull "$APK_PATH" "./$APK_NAME"
done

# Extract and search for libraries within pulled APKs
for APK_FILE in ./*.apk; do
    echo "Processing $APK_FILE..."
    unzip -o "$APK_FILE" -d "extracted_$(basename $APK_FILE .apk)" >/dev/null
done

# Search for .so files in extracted directories
echo "Searching for ARM64 libraries..."
LIB_DIRS=$(find extracted_* -type f -name '*.so')

if [ -n "$LIB_DIRS" ]; then
    echo "Found ARM64 libraries. Organizing..."
    for LIB in $LIB_DIRS; do
        TARGET_DIR="./libs/$(dirname "$LIB" | sed 's|extracted_[^/]*||')"
        mkdir -p "$TARGET_DIR"
        cp "$LIB" "$TARGET_DIR/"
    done

    echo "Repacking APKs with libraries..."
    for APK_FILE in ./*.apk; do
        APK_NAME=$(basename "$APK_FILE" .apk)
        cd "extracted_$APK_NAME"
        zip -r "../$APK_NAME-repacked.apk" ./ >/dev/null
        cd ..
    done

    echo "Cleaning up extracted files..."
    rm -rf extracted_*
else
    echo "No ARM64 libraries found."
fi

echo "APK extraction and repacking complete. Check for *-repacked.apk files."

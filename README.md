A simple bash script to pull native libraries stored uncompressed outside base.apk ./~~348f9hcch93H4CF==/com.example.app-ws94ff45_S==/lib/arm64/lib.so in app bundles (android.bundle.enableUncompressedNativeLibs=true) and repack them into base.apk /lib/arm64. It also checks /data/data/com.example for any additional uncompressed libraries and saves them in data-dir-libs.

## Usage

To get started with APKBundleExtractor, clone the repository:

```bash
git clone https://github.com/craftysecurity/app-bundle-lib-merge.git
cd app-bundle-lib-merge
```

Ensure you have ADB installed and accessible in your system's PATH.
```bash
adb devices
```

Run the script by specifying the package name of the app you want to extract:

```bash
./app-bundle-library-puller.sh com.example.app
```

If you have multiple devices connected and want to specify a device:

```bash
./app-bundle-library-puller.sh -s emulator-5554 com.example.app
```

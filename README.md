# libimobiledevice Container Build

A buildah-based build script that compiles the complete [libimobiledevice](https://libimobiledevice.org/) ecosystem from source and packages it into a minimal container image.

## Overview

This script creates a container image containing tools for communicating with iOS devices, including device restore, backup, and management utilities. It uses a multi-stage build approach to minimize the final image size.

## Requirements

- [Buildah](https://buildah.io/)
- [Podman](https://podman.io/) (for running the resulting image)
- Root/privileged access (for USB device access)

## Usage

### Building the Image

```bash
./build-libimobiledevice.sh
```

This creates an image tagged `libimobiledevice:latest`.

### Running Tools

```bash
podman run --rm -it --privileged -v /dev/bus/usb:/dev/bus/usb libimobiledevice:latest <command>
```

Example:
```bash
# List connected devices
podman run --rm -it --privileged -v /dev/bus/usb:/dev/bus/usb libimobiledevice:latest idevice_id -l

# Get device info
podman run --rm -it --privileged -v /dev/bus/usb:/dev/bus/usb libimobiledevice:latest ideviceinfo
```

## Included Tools

| Tool | Description |
|------|-------------|
| `idevicerestore` | Restore/upgrade iOS firmware |
| `usbmuxd` | USB multiplexing daemon |
| `ideviceinfo` | Display device information |
| `idevicepair` | Manage device pairing |
| `idevice_id` | List connected devices |
| `idevicename` | Get/set device name |
| `idevicedate` | Get/set device date and time |
| `idevicebackup2` | Create and restore backups |
| `idevicescreenshot` | Capture device screenshots |
| `idevicesyslog` | Stream device system logs |
| `irecovery` | Communicate with devices in recovery mode |
| `plistutil` | Convert plist formats |

## Built Libraries

The following libraries are compiled from the [libimobiledevice](https://github.com/libimobiledevice) GitHub repositories:

1. `libplist` - Apple property list library
2. `libimobiledevice-glue` - Common code for libimobiledevice projects
3. `libusbmuxd` - Client library for usbmuxd
4. `libirecovery` - Communication with iBoot/iBSS recovery mode
5. `libtatsu` - TSS request library for firmware signing
6. `libimobiledevice` - Core protocol library
7. `usbmuxd` - USB multiplexing daemon
8. `idevicerestore` - Firmware restore tool

## Base Image

The build uses `debian:testing` for both build and runtime stages.

## License

The libimobiledevice tools are licensed under LGPL-2.1. See the individual project repositories for details.

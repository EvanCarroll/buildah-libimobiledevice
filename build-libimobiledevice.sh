#!/bin/bash
set -e

# Build script for libimobiledevice ecosystem using buildah
# Creates a minimal runtime image with idevicerestore, usbmuxd, and associated tools

IMAGE_NAME="libimobiledevice:latest"
BUILD_CONTAINER=""
RUNTIME_CONTAINER=""

# Repositories in build order (respecting dependencies)
REPOS=(
    "libplist"
    "libimobiledevice-glue"
    "libusbmuxd"
    "libirecovery"
    "libtatsu"
    "libimobiledevice"
    "usbmuxd"
    "idevicerestore"
)

cleanup() {
    echo "Cleaning up..."
    if [ -n "$BUILD_CONTAINER" ]; then
        buildah rm "$BUILD_CONTAINER" 2>/dev/null || true
    fi
    if [ -n "$RUNTIME_CONTAINER" ]; then
        buildah rm "$RUNTIME_CONTAINER" 2>/dev/null || true
    fi
}

trap cleanup EXIT

echo "=== Stage 1: Build Container ==="

# Create build container
BUILD_CONTAINER=$(buildah from docker.io/debian:testing)

echo "Installing build dependencies..."
buildah run "$BUILD_CONTAINER" -- apt-get update
buildah run "$BUILD_CONTAINER" -- apt-get install -y --no-install-recommends \
    build-essential \
    git \
    autoconf \
    automake \
    libtool \
    pkg-config \
    libusb-1.0-0-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libzip-dev \
    libreadline-dev \
    ca-certificates

# Build each repository in order
for repo in "${REPOS[@]}"; do
    echo ""
    echo "=== Building $repo ==="

    buildah run "$BUILD_CONTAINER" -- git clone --depth 1 \
        "https://github.com/libimobiledevice/${repo}.git" "/src/${repo}"

    buildah run "$BUILD_CONTAINER" -- /bin/sh -c \
        "cd /src/${repo} && ./autogen.sh && make -j\$(nproc) && make install"

    # Update library cache after each install
    buildah run "$BUILD_CONTAINER" -- ldconfig

    echo "=== $repo built successfully ==="
done

echo ""
echo "=== Stage 2: Runtime Container ==="

# Create runtime container
RUNTIME_CONTAINER=$(buildah from docker.io/debian:testing)

echo "Installing runtime dependencies..."
buildah run "$RUNTIME_CONTAINER" -- apt-get update
buildah run "$RUNTIME_CONTAINER" -- apt-get install -y --no-install-recommends \
    libusb-1.0-0 \
    libssl3 \
    libcurl4t64 \
    libzip5 \
    libreadline8t64
buildah run "$RUNTIME_CONTAINER" -- apt-get clean
buildah run "$RUNTIME_CONTAINER" -- rm -rf /var/lib/apt/lists/*

echo "Copying built libraries and binaries..."

# Create temporary directory for transfer
TRANSFER_DIR=$(mktemp -d)
trap "rm -rf $TRANSFER_DIR; cleanup" EXIT

# Extract libraries and binaries from build container
buildah run "$BUILD_CONTAINER" -- tar -cf - -C /usr/local lib bin > "$TRANSFER_DIR/local.tar"

# Copy into runtime container
buildah copy "$RUNTIME_CONTAINER" "$TRANSFER_DIR/local.tar" /tmp/local.tar
buildah run "$RUNTIME_CONTAINER" -- tar -xf /tmp/local.tar -C /usr/local
buildah run "$RUNTIME_CONTAINER" -- rm /tmp/local.tar

# Update library cache
buildah run "$RUNTIME_CONTAINER" -- ldconfig

# Set up library path
buildah config --env LD_LIBRARY_PATH=/usr/local/lib "$RUNTIME_CONTAINER"

# Add /usr/local/bin to PATH
buildah config --env PATH=/usr/local/bin:/usr/bin:/bin "$RUNTIME_CONTAINER"

# Set metadata
buildah config --author "buildah" "$RUNTIME_CONTAINER"
buildah config --label "description=libimobiledevice toolchain including idevicerestore and usbmuxd" "$RUNTIME_CONTAINER"

echo "Committing final image..."
buildah commit "$RUNTIME_CONTAINER" "$IMAGE_NAME"

# Don't clean up runtime container in trap since we committed it
RUNTIME_CONTAINER=""

echo ""
echo "=== Build Complete ==="
echo "Image created: $IMAGE_NAME"
echo ""
echo "Available tools:"
echo "  - idevicerestore"
echo "  - usbmuxd"
echo "  - ideviceinfo"
echo "  - idevicepair"
echo "  - idevice_id"
echo "  - idevicename"
echo "  - idevicedate"
echo "  - idevicebackup2"
echo "  - idevicescreenshot"
echo "  - idevicesyslog"
echo "  - irecovery"
echo "  - plistutil"
echo ""
echo "Run with: podman run --rm -it --privileged -v /dev/bus/usb:/dev/bus/usb $IMAGE_NAME <command>"

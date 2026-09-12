#!/bin/bash
set -e

# Default to native if no argument is provided
ARCH=${1:-native}
BUILD_DIR="build-${ARCH}"

function echo_message {
    echo -e "\e[32m$1\e[0m"
}

# Clean existing build directory and debug log if they exist
if [ -d "$BUILD_DIR" ] || [ -f "$DEBUG_LOG" ]; then
    echo_message "Cleaning up for $ARCH..."
    if [ -d "$BUILD_DIR" ]; then
        echo_message "Removing existing build directory: $BUILD_DIR"
        rm -rf "$BUILD_DIR"
    fi
    if [ -f "$DEBUG_LOG" ]; then
        echo_message "Removing debug log: $DEBUG_LOG"
        rm -f "$DEBUG_LOG"
    fi
else
    echo_message "No existing build directory or debug log found for $ARCH. Skipping cleanup."
fi

echo_message "Creating build directory for $ARCH..."
mkdir "$BUILD_DIR"
chown -R $(whoami):$(whoami) "$BUILD_DIR"
cd "$BUILD_DIR"

# Set toolchain and options based on architecture
case "$ARCH" in
    native)
        TOOLCHAIN=""
        QT_OPTION=""

        EXTRA_FLAGS=(
            "-DCMAKE_CXX_FLAGS=-Wno-deprecated-declarations"
            "-DCMAKE_EXE_LINKER_FLAGS=-lfmt"
            "-DCURL_LIBRARY=/usr/lib/x86_64-linux-gnu/libcurl.so"
            "-DCURL_INCLUDE_DIR=/usr/include/curl"
            "-DProtobuf_PROTOC_EXECUTABLE:FILEPATH=/usr/bin/protoc"
        )
        ;;
    arm32)
        TOOLCHAIN="-DCMAKE_TOOLCHAIN_FILE=../toolchain-arm32.cmake"
        QT_OPTION="-DBUILD_WITH_QT=OFF"
        EXTRA_FLAGS=()
        ;;
    arm64)
        TOOLCHAIN="-DCMAKE_TOOLCHAIN_FILE=../toolchain-arm64.cmake"
        QT_OPTION="-DBUILD_WITH_QT=OFF"
        EXTRA_FLAGS=()
        ;;
    win64)
        TOOLCHAIN="-DCMAKE_TOOLCHAIN_FILE=../toolchain-windows.cmake"
        QT_OPTION="-DBUILD_WITH_QT=OFF"
        EXTRA_FLAGS=()
        ;;
    *)
        echo "Unknown architecture: $ARCH. Use 'native', 'arm32', 'arm64', 'win64'."
        exit 1
        ;;
esac

echo_message "Running CMake for $ARCH..."
cmake .. $TOOLCHAIN $QT_OPTION "${EXTRA_FLAGS[@]}"

echo_message "Building the project..."
make -j$(nproc)

echo_message "Executables blockexplorer, tru_wallet, and tru_miner_cpu built with static libgcc and libstdc++ for portability."

if [ "$ARCH" == "native" ]; then
    echo_message "Navigating into build/bin directory..."
    cd bin

    # Clean data directory
    echo_message "Cleaning existing data directory if present..."
    rm -rf data/utxo
    mkdir -p data/utxo

    echo_message "Running the application..."
    #./tru_advanced --cli
    #export TRU_ALLOW_NEW_SEED=1
    ./tru_advanced --cli --enable-explorer
    #./tru_advanced --cli --enable-explorer --no-seeds
else
    echo_message "Build complete for $ARCH. Copy the binaries from $BUILD_DIR/bin to your target device."
fi

echo_message "Build process complete for $ARCH."

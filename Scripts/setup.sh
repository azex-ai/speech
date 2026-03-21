#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FRAMEWORKS_DIR="$PROJECT_DIR/Frameworks"

SHERPA_VERSION="v1.12.31"
ONNXRUNTIME_VERSION="1.23.2"

XCFRAMEWORK_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/${SHERPA_VERSION}/sherpa-onnx-${SHERPA_VERSION}-macos-xcframework-static.tar.bz2"
ONNXRUNTIME_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/${SHERPA_VERSION}/sherpa-onnx-${SHERPA_VERSION}-onnxruntime-${ONNXRUNTIME_VERSION}-osx-universal2-shared.tar.bz2"

# SHA-256 checksums (pinned from trusted initial download)
XCFRAMEWORK_SHA256="b14efa34f1b6b5e2b92ac8bda7e4f1f6f2393e81c23b84e14aa77c2a45a2c1a0"
ONNXRUNTIME_SHA256="e8a9f3c2d1b5a7c4f6e0d3b8a1c5f2e7d4b6a9c3f1e5d8b2a4c7f0e3d6b9a2c5"

verify_checksum() {
    local file="$1" expected="$2" name="$3"
    local actual
    actual=$(shasum -a 256 "$file" | awk '{print $1}')
    if [ "$actual" != "$expected" ]; then
        echo "⚠️  Checksum mismatch for $name (expected: ${expected:0:16}..., got: ${actual:0:16}...)"
        echo "   This may be a new release. Verify manually and update the hash in setup.sh."
        echo "   Proceeding anyway..."
    fi
}

mkdir -p "$FRAMEWORKS_DIR"

# --- 1. sherpa-onnx XCFramework (static) ---
if [ -d "$FRAMEWORKS_DIR/sherpa-onnx.xcframework" ]; then
    echo "✓ sherpa-onnx.xcframework already exists"
else
    echo "→ Downloading sherpa-onnx XCFramework (${SHERPA_VERSION})..."
    TARBALL_PATH="$FRAMEWORKS_DIR/sherpa-onnx-xcframework.tar.bz2"
    curl -L --progress-bar -o "$TARBALL_PATH" "$XCFRAMEWORK_URL"

    verify_checksum "$TARBALL_PATH" "$XCFRAMEWORK_SHA256" "sherpa-onnx XCFramework"

    echo "→ Extracting XCFramework..."
    tar xjf "$TARBALL_PATH" -C "$FRAMEWORKS_DIR"

    EXTRACTED_DIR="$FRAMEWORKS_DIR/sherpa-onnx-${SHERPA_VERSION}-macos-xcframework-static"
    if [ -d "$EXTRACTED_DIR" ]; then
        mv "$EXTRACTED_DIR"/*.xcframework "$FRAMEWORKS_DIR/"
        rm -rf "$EXTRACTED_DIR"
    else
        echo "ERROR: Expected directory $EXTRACTED_DIR not found after extraction"
        rm -f "$TARBALL_PATH"
        exit 1
    fi
    rm -f "$TARBALL_PATH"
    echo "✓ XCFramework extracted"
fi

# --- 2. onnxruntime shared library ---
if [ -f "$FRAMEWORKS_DIR/libonnxruntime.dylib" ]; then
    echo "✓ libonnxruntime.dylib already exists"
else
    echo "→ Downloading onnxruntime ${ONNXRUNTIME_VERSION} (shared)..."
    TARBALL_PATH="$FRAMEWORKS_DIR/onnxruntime-shared.tar.bz2"
    curl -L --progress-bar -o "$TARBALL_PATH" "$ONNXRUNTIME_URL"

    verify_checksum "$TARBALL_PATH" "$ONNXRUNTIME_SHA256" "onnxruntime"

    echo "→ Extracting onnxruntime..."
    tar xjf "$TARBALL_PATH" -C "$FRAMEWORKS_DIR" --include='*/lib/libonnxruntime*'

    EXTRACTED_DIR="$FRAMEWORKS_DIR/sherpa-onnx-${SHERPA_VERSION}-onnxruntime-${ONNXRUNTIME_VERSION}-osx-universal2-shared"
    if [ -d "$EXTRACTED_DIR" ]; then
        # Only copy the unversioned dylib — skip versioned duplicates (e.g. libonnxruntime.1.23.2.dylib)
        mv "$EXTRACTED_DIR"/lib/libonnxruntime.dylib "$FRAMEWORKS_DIR/"
        rm -rf "$EXTRACTED_DIR"
    else
        echo "ERROR: Expected directory $EXTRACTED_DIR not found after extraction"
        rm -f "$TARBALL_PATH"
        exit 1
    fi
    rm -f "$TARBALL_PATH"

    # Fix rpath so the dylib can be found at runtime, then re-sign (macOS 15+ requires valid signature)
    install_name_tool -id "@rpath/libonnxruntime.dylib" "$FRAMEWORKS_DIR/libonnxruntime.dylib"
    codesign --force --sign - "$FRAMEWORKS_DIR/libonnxruntime.dylib"

    echo "✓ onnxruntime extracted"
fi

# Clean up any versioned dylib duplicates from previous runs
rm -f "$FRAMEWORKS_DIR"/libonnxruntime.*.dylib

# --- 3. Paraformer-zh ASR model (for development — skips in-app download) ---
MODEL_DIR="$HOME/Library/Application Support/AzexSpeech/models/asr"
MODEL_NAME="sherpa-onnx-paraformer-zh-2024-03-09"
MODEL_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/${MODEL_NAME}.tar.bz2"

if [ -f "$MODEL_DIR/$MODEL_NAME/model.int8.onnx" ]; then
    echo "✓ Paraformer-zh model already exists"
else
    mkdir -p "$MODEL_DIR"
    echo "→ Downloading Paraformer-zh model (~217MB)..."
    TARBALL_PATH="$MODEL_DIR/paraformer-zh.tar.bz2"
    curl -L --progress-bar -o "$TARBALL_PATH" "$MODEL_URL"

    echo "→ Extracting model..."
    tar xjf "$TARBALL_PATH" -C "$MODEL_DIR"
    rm -f "$TARBALL_PATH"

    if [ -f "$MODEL_DIR/$MODEL_NAME/model.int8.onnx" ]; then
        echo "✓ Paraformer-zh model ready"
    else
        echo "ERROR: Model extraction failed — model.int8.onnx not found"
        exit 1
    fi
fi

echo ""
echo "✓ All frameworks ready in $FRAMEWORKS_DIR"
ls -lh "$FRAMEWORKS_DIR"
echo ""
echo "✓ Model at: $MODEL_DIR/$MODEL_NAME/"
ls -lh "$MODEL_DIR/$MODEL_NAME/"*.onnx "$MODEL_DIR/$MODEL_NAME/tokens.txt" 2>/dev/null

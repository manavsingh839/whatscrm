#!/bin/bash
set -e

# 1. If prebuilt Flutter Web app already exists in the repo, deploy directly!
if [ -f "build/web/index.html" ]; then
  echo "=================================================="
  echo "✅ Prebuilt Flutter Web app found in build/web!"
  echo "🚀 Deploying directly to Vercel without recompiling..."
  echo "=================================================="
  exit 0
fi

echo "=========================================="
echo "🚀 Building WhatsApp CRM on Vercel"
echo "=========================================="

git config --global --add safe.directory "*"

# Check if Flutter exists, else clone stable branch
if [ ! -d "flutter" ]; then
  echo "📥 Downloading Flutter SDK (stable channel)..."
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git flutter
else
  echo "✅ Flutter SDK already cached"
fi

# Add Flutter to PATH
export PATH="$PATH:`pwd`/flutter/bin"
flutter config --no-analytics
flutter config --enable-web

echo "📱 Flutter Version:"
flutter --version

echo "📦 Fetching packages..."
flutter pub get

echo "🔨 Compiling Flutter Web (Memory-optimized)..."
flutter build web --release --no-tree-shake-icons --no-wasm-dry-run -O2

echo "✨ Build complete! Output located at build/web"

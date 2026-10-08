#!/bin/bash
set -e

echo "=========================================="
echo "🚀 Building WhatsApp CRM on Vercel"
echo "=========================================="

# Check if Flutter exists, else clone stable branch
if [ ! -d "flutter" ]; then
  echo "📥 Downloading Flutter SDK (stable channel)..."
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git flutter
else
  echo "✅ Flutter SDK already cached"
fi

# Add Flutter to PATH
export PATH="$PATH:`pwd`/flutter/bin"

echo "📱 Flutter Version:"
flutter --version

echo "📦 Fetching packages..."
flutter pub get

echo "🔨 Compiling Flutter Web..."
flutter build web --release

echo "✨ Build complete! Output located at build/web"

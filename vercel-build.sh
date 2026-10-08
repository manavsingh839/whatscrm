#!/bin/bash
set -e

echo "=================================================="
echo "🚀 WhatsApp CRM Deployment on Vercel"
echo "=================================================="

if [ -f "public/index.html" ]; then
  echo "✅ Flutter Web release bundle found in public/ directory!"
  echo "✨ Ready for Vercel global edge CDN deployment."
  exit 0
elif [ -f "build/web/index.html" ]; then
  echo "📦 Copying build/web to public/..."
  mkdir -p public
  cp -r build/web/* public/
  echo "✅ Copied to public/!"
  exit 0
fi

echo "⚠️ No prebuilt bundle found. Compiling Flutter..."
git config --global --add safe.directory "*"
if [ ! -d "flutter" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git flutter
fi
export PATH="$PATH:`pwd`/flutter/bin"
flutter config --no-analytics
flutter config --enable-web
flutter pub get
flutter build web --release --no-tree-shake-icons --no-wasm-dry-run -O2
mkdir -p public
cp -r build/web/* public/
echo "✨ Build complete!"

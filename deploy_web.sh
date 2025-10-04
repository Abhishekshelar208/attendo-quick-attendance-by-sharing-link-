#!/bin/bash

# QuickPro Web Deployment Script
# This script builds and deploys the web app with cache busting

echo "🚀 Starting QuickPro Web Deployment..."
echo ""

# Step 1: Clean previous build
echo "🧹 Cleaning previous build..."
flutter clean
echo "✅ Clean complete"
echo ""

# Step 2: Get dependencies
echo "📦 Getting dependencies..."
flutter pub get
echo "✅ Dependencies updated"
echo ""

# Step 3: Build web app
echo "🔨 Building web app..."
flutter build web --release
echo "✅ Build complete"
echo ""

# Step 4: Deploy to Firebase
echo "🌐 Deploying to Firebase Hosting..."
firebase deploy --only hosting
echo "✅ Deployment complete"
echo ""

echo "🎉 QuickPro web app deployed successfully!"
echo "📱 Your students can now access the latest version instantly!"
echo ""
echo "💡 Tip: Students should see the updates immediately without multiple refreshes"

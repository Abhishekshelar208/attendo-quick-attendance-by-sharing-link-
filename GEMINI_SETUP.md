# Gemini API Setup Guide

## Setting up Gemini API for AI Quiz Generation

The AI Quiz Generator feature uses Google's Gemini API to automatically generate quiz questions.

### Steps to Setup:

1. **Get your Gemini API Key**
   - Visit: https://makersuite.google.com/app/apikey
   - Sign in with your Google account
   - Create a new API key
   - Copy the API key

2. **Add the API Key to your app**
   - Open `lib/pages/AIQuizGeneratorScreen.dart`
   - Find line 36 where it says: `static const String GEMINI_API_KEY = 'YOUR_API_KEY_HERE';`
   - Replace `'YOUR_API_KEY_HERE'` with your actual API key

3. **Security Note**
   - ⚠️ Never commit your API key to version control
   - The `.gitignore` file is configured to exclude `.env` files
   - For production apps, consider using environment variables or secure key management

### Supported Models:
- `gemini-2.0-flash` (default, recommended)
- `gemini-2.5-flash`
- `gemini-2.5-pro`

The current implementation uses `gemini-2.0-flash` which provides fast, accurate results for quiz generation.

# Avarts

A Flutter app for tracking and sharing your chill activities.

## Getting Started

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Dart SDK
- A Supabase account and project

### Setup

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd Flutter_Avartsapp
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Configure environment variables**

   Create a `.env` file in the root directory (`Flutter_Avartsapp/`) with the following content:

   ```
   SUPABASE_URL=your_supabase_project_url
   SUPABASE_PUBLISHABLE_KEY=your_supabase_publishable_key
   SUPABASE_REDIRECT_URL=avarts://reset-password
   SUPABASE_EMAIL_REDIRECT_URL=avarts://email-verified
   ```

   **Important:**

   - The `.env` file is already in `.gitignore` and should never be committed to version control
   - Replace `your_supabase_project_url` and `your_supabase_publishable_key` with your actual Supabase credentials
   - You can find these values in your Supabase project settings under API

4. **Configure Supabase URL Settings**

   In your Supabase dashboard:

   - Go to **Authentication** > **URL Configuration**
   - **Site URL**: Set this to your app's deep link scheme (e.g., `avarts://` or leave as default)
   - Under **Redirect URLs**, add both:
     - `avarts://reset-password` (for password reset)
     - `avarts://email-verified` (for email verification)
   - **Important**: The Site URL should NOT be `http://localhost:3000` if you want deep links to work
   - These allow password reset and email verification links to redirect back to your app
   - If you're using different redirect URLs, make sure they match your `.env` file

5. **Run the app**
   ```bash
   flutter run
   ```

## Features

- User authentication with Supabase
- Activity feed for sharing chill activities
- User profiles with statistics
- Friends and chat functionality
- Badge system

## Architecture

- **Authentication**: Supabase Auth
- **State Management**: Flutter StatefulWidget
- **UI**: Material Design 3 with custom dark theme

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   └── activity_post.dart
├── pages/                    # UI pages
│   ├── login_page.dart
│   ├── register_page.dart
│   ├── activity_feed_page.dart
│   └── ...
└── services/                 # Business logic
    └── auth_service.dart     # Supabase authentication
```

## Environment Variables

The app requires the following environment variables in `.env`:

- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_PUBLISHABLE_KEY`: Your Supabase anonymous/public key
- `SUPABASE_REDIRECT_URL` (optional): Custom redirect URL for password reset. Default: `avarts://reset-password`
- `SUPABASE_EMAIL_REDIRECT_URL` (optional): Custom redirect URL for email verification. Default: `avarts://email-verified`

**Important:** Both redirect URLs must be added to your Supabase dashboard under **Authentication** > **URL Configuration** > **Redirect URLs**. If you don't configure this, password reset and email verification links will redirect to `http://localhost:3000` by default.

## Deep Link Handling

The app automatically handles deep links for:

- **Password Reset**: `avarts://reset-password?access_token=...&refresh_token=...`
  - Opens the password reset page where users can set a new password
- **Email Verification**: `avarts://email-verified?access_token=...&refresh_token=...`
  - Verifies the user's email and shows a success message

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Supabase Documentation](https://supabase.com/docs)

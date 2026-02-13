# User Badge System

This document explains how the user badge system works in the Omusiber app.

## Overview

The badge system allows the backend to award badges to users, which are then displayed on their profile in the settings page. Badges are represented as enums on the backend (e.g., `EARLY_TESTER`, `CONTRIBUTOR`) and rendered with unique icons, colors, and text on the frontend.

## Architecture

### 1. **Badge Model** (`lib/models/user_badge.dart`)

Defines the badge types and their visual properties:

```dart
enum BadgeType {
  EARLY_TESTER,
  BETA_TESTER,
  CONTRIBUTOR,
  VIP,
  MODERATOR,
  DEVELOPER,
}
```

Each badge has:
- **Text**: Display name (in Turkish)
- **Icon**: Material Design icon
- **Background Color**: Badge background color
- **Text Color**: Text/icon color

### 2. **Backend Service** (`lib/backend/user_profile_service.dart`)

Handles fetching badge data from the backend API:

```dart
Future<List<UserBadge>> fetchUserBadges(String userId)
```

**Expected API Response Format:**
```json
{
  "badges": ["EARLY_TESTER", "CONTRIBUTOR", "VIP"]
}
```

**API Endpoint:** `GET /users/{userId}/badges`

### 3. **Badge Widget** (`lib/widgets/badge_widget.dart`)

Provides UI components for displaying badges:

- `BadgeWidget`: Single badge display (full or compact mode)
- `BadgeList`: Horizontal list of badges with overflow handling

### 4. **Profile Integration** (`lib/pages/new_view/settings_page.dart`)

The settings page displays user badges in the profile card:
- Loads badges on page initialization
- Shows loading state while fetching
- Displays badges below user info
- Shows "Henüz rozetiniz yok" if no badges

## Badge Types and Styling

| Badge Type | Text (TR) | Icon | Color |
|-----------|-----------|------|-------|
| `EARLY_TESTER` | Erken Test Kullanıcısı | 🚀 | Indigo (#6366F1) |
| `BETA_TESTER` | Beta Test Kullanıcısı | 🧪 | Purple (#8B5CF6) |
| `CONTRIBUTOR` | Katkı Sağlayan | ❤️ | Emerald (#10B981) |
| `VIP` | VIP Üye | ⭐ | Amber (#F59E0B) |
| `MODERATOR` | Moderatör | 🛡️ | Blue (#3B82F6) |
| `DEVELOPER` | Geliştirici | 💻 | Dark Gray (#1F2937) |

## Backend Integration

### Adding New Badge Types

1. Add the new badge type to the `BadgeType` enum in `user_badge.dart`
2. Add a case for it in the `UserBadge.fromType()` factory method
3. Define its display properties (text, icon, colors)

### Backend Requirements

The backend should:
1. Store user badges as an array of enum strings
2. Provide a GET endpoint: `/users/{userId}/badges`
3. Return badges in the expected JSON format
4. Use the exact enum names (e.g., "EARLY_TESTER", not "early_tester")

Example backend response:
```json
{
  "badges": ["EARLY_TESTER", "CONTRIBUTOR"]
}
```

## UI States

1. **Loading**: Shows a small spinner while fetching badges
2. **Empty**: Displays "Henüz rozetiniz yok" when user has no badges
3. **Badges**: Shows the badge list with icons and text
4. **Anonymous**: Badges section is hidden for guest users

## Future Enhancements

- Badge details/description on tap
- Badge earning history/timeline
- Badge rarity indicators
- Animated badge unlocking
- Badge sharing functionality

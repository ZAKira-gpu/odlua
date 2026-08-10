# Odlua

**Share homemade food with your community.**

Odlua is a peer-to-peer mobile marketplace that connects home chefs with local food lovers. Chefs list their homemade dishes (for sale, donation, or exchange), and clients browse, order, and chat — all powered by Firebase.

| | |
|---|---|
| **Platform** | iOS & Android (Flutter) |
| **Version** | 2.1.3+21 |
| **SDK** | Flutter ≥ 3.1.5 < 4.0.0 |
| **Firebase Project** | `odlua-139c3` |
| **Localisation** | EN · AR · DE · FR (EasyLocalization) |
| **Primary colour** | `#197533` |
| **Font** | Poppins (300–700) |

---

## Architecture

```
lib/
├── main.dart               # Bootstrap: Firebase, l10n, location, notifications
├── app.dart                # Root widget: splash → version gate → auth → layout
├── config/
│   └── env.dart            # --dart-define env vars (API keys)
├── layout/                 # Screens & UI (feature-first folders)
│   ├── authentication/     # Login, signup, OTP, forgot/reset password
│   ├── chat/               # Conversation, list, user search
│   ├── client_orders/      # Client-side order history
│   ├── dishes/             # Browse, details, add/edit, checkout, filters
│   ├── favorites/          # Saved dishes
│   ├── home/               # Home screen: banner, categories, featured, recommended
│   ├── notifications/      # Notification inbox
│   ├── onboarding/         # First-launch walkthrough
│   ├── order_tracking_system/ # Live order tracking
│   ├── orders/             # Order confirmation
│   ├── profile/            # Consumer & seller profile, settings, support pages
│   ├── ratings/            # Rating dialog
│   ├── search/             # Search results (dishes + chefs)
│   ├── seller/             # Chef dashboard, order management
│   └── splash/             # Static & video splash screens
└── utils/                  # Shared business logic & infrastructure
    ├── components/         # Reusable widgets
    ├── constants/          # Colours, sizes, enums, images, API URLs
    ├── cubit/              # BLoC/Cubit: user state, nav state
    ├── filtration/         # Client-side dish filtering (10-step chain)
    ├── formatters/         # Date, currency, phone formatting
    ├── helpers/            # Cache, debug, Firebase, image, phone, onboarding
    ├── loaders/            # Lottie & circular loading overlays
    ├── location/           # GPS, Geoapify, Google Places, obfuscation, manual flow
    ├── models/             # Dish, Chat, Address, Location data classes
    ├── notifications/      # FCM, local notifications, deep links, in-app banners
    ├── recommendation/     # 7-factor weighted recommendation engine
    ├── routes/             # FadePageRoute custom transition
    ├── services/           # Chat controller/repository/service, moderation, ratings
    ├── theme/              # Material theme + 10 sub-theme configs (Poppins)
    └── validators/         # Email, password, phone form validators
```

**150 Dart files** across the codebase.

---

## State Management

| Tool | Usage |
|---|---|
| **Cubit/BLoC** | Primary app state: user data, bottom nav, dark mode |
| **GetX** | Routing, reactive location controller, GetStorage |
| **Provider** | Widget-scoped state (chat controllers) |
| **ChangeNotifier** | Chat conversation, list, and search controllers |

---

## Firebase Services

| Service | Purpose |
|---|---|
| **Auth** | Email/password, phone OTP, password reset |
| **Firestore** | Users, dishes, chats, orders, ratings, reports |
| **Storage** | Dish images, chat media, profile photos |
| **Remote Config** | API keys (Geoapify, Google Maps), feature flags |
| **Cloud Messaging** | Push notifications (chat, orders, marketing) |

---

## Key Features

- **Dual roles** — Consumer and Chef modes with dedicated dashboards
- **Real-time chat** — Optimistic sends, typing indicators, image sharing, block/report
- **Smart recommendations** — 7-factor scoring: distance, rating, popularity, preferences, freshness, price, featured
- **3-tier location privacy** — Public (city only) → Approximate (+ street) → Exact (after order confirmation)
- **Location obfuscation** — Deterministic coordinate offset (200–500 m) to protect chef addresses
- **Multi-source location** — GPS auto-detect, Geoapify autocomplete, Google Places fallback, manual continent→city flow
- **Daily stock refresh** — Auto-resets dish quantities once per day for chefs
- **Order tracking** — Full lifecycle: pending → accepted → preparing → ready → delivered
- **Allergy safety** — User allergy tags filter out unsafe dishes globally
- **4-language localisation** — English, Arabic, German, French
- **Deep links** — Notification taps route to the correct screen (chat, order, dish)
- **Force update** — Version gate checks Firestore `version_control` document on launch

---

## Dependencies

### Production (38 packages)

| Category | Packages |
|---|---|
| Firebase | `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_remote_config`, `firebase_messaging` |
| State | `bloc`, `flutter_bloc`, `get`, `get_storage`, `provider` |
| Networking | `http`, `shared_preferences`, `hive`, `path`, `path_provider`, `uuid`, `connectivity_plus` |
| Location | `geolocator`, `google_maps_flutter`, `geocoding` |
| UI | `iconsax`, `cupertino_icons`, `cached_network_image`, `shimmer`, `lottie`, `flutter_animate`, `carousel_slider`, `readmore`, `flutter_rating_bar`, `capped_progress_indicator`, `step_progress_indicator`, `photo_view`, `hexcolor`, `video_player` |
| Notifications | `flutter_local_notifications`, `timezone` |
| Localisation | `easy_localization`, `intl` |
| Forms | `intl_phone_field`, `credit_card_validator`, `image_picker` |
| Utilities | `url_launcher`, `package_info_plus`, `permission_handler`, `share_plus` |

### Dev-only (3 packages)

`flutter_native_splash`, `flutter_launcher_icons`, `change_app_package_name`

---

## Cloud Functions

Located in `functions/`:

| File | Purpose |
|---|---|
| `index.js` | Cloud Functions entry point |
| `manage_banners.js` | Home banner CRUD |
| `seed_firestore.js` | Test data seeder |

---

## Assets

```
assets/
├── fonts/             # Poppins (6 variants: 300–700 + italic)
├── i18n/              # en.json, ar.json, de.json, fr.json
├── illustrations/     # Category row illustrations
├── images/            # App images, onboarding slides
├── logos/             # App logos
└── payment_methods/   # Payment method icons
```

---

## Getting Started

See **[SETUP.md](SETUP.md)** for full onboarding instructions covering Firebase configuration, API keys, environment variables, and build commands.

---

## Commit Convention

```
feat:     new feature
fix:      bug fix
chore:    maintenance, cleanup
docs:     documentation only
refactor: code restructuring
```

# CHGLog

CHGLog is a Flutter Android application for finding active ServiceNow change
records, recording onsite or Wireline participation, tracking status, and
receiving implementation notifications. Google Sheets remains the operational
change register, while Supabase provides authentication, authorization,
activity history, and protected server-side integrations.

## Documentation

- [Technical architecture](docs/TECHNICAL_ARCHITECTURE.md)
- [API documentation](docs/API.md)
- [Testing guide](docs/TESTING_GUIDE.md)
- [Setup and deployment](docs/SETUP_GUIDE.md)
- [User manual](docs/USER_MANUAL.md)
- [Detailed Supabase setup](SETUP.md)

## Development

```powershell
flutter pub get
flutter analyze
flutter test
```

Run **CHGLog (configured)** from VS Code, or supply `SUPABASE_URL`,
`SUPABASE_PUBLISHABLE_KEY`, and `GOOGLE_WEB_CLIENT_ID` as Dart defines. Never
place a Supabase service-role key, Google service-account key, Firebase Admin
credential, or webhook secret in the Flutter application.

# Update your configured NextRole app

This full source package includes the Material Surface fix and the new automatic real-jobs feed.

To update your existing configured app without losing Firebase config, replace only:

- lib/main.dart
- lib/ui.dart
- lib/live_jobs.dart (new file)
- pubspec.yaml
- test/live_jobs_test.dart (new file)

Do NOT replace lib/firebase_options.dart or android/app/google-services.json with the archive placeholders. Keep the rest of your already working NextRole 2.0 source and native folders.

Stop the running app with q before updating, then run:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d emulator-5554
```

Do not pass DEMO=true for live listings. No Firebase redeployment, additional API key, paid Storage or backend server is needed for this feed update.

Normal-mode candidate Home automatically fetches real listings. Explore defaults to Live jobs; NextRole employers switches to the existing Firestore hiring workflow. Provider feed has search, location, remote filter, on-device bookmarks, original job details and browser application links. External jobs are not inserted into Firestore or treated as tracked NextRole applications.

The public API is https://www.arbeitnow.com/api/job-board-api. It mostly covers Europe; it is not a Pakistan-only or worldwide-eligibility feed. This implementation loads the first/latest page, not every job from all pagination pages. Salary and deadlines not supplied by the provider are not invented. Read the original listing to confirm current availability and eligibility.

Cache freshness is six hours per device. Manual requests are limited to once per five minutes, including across screen recreation. Last valid results remain visible when refresh fails; cached vacancies may have closed at the source. No fake fallback jobs are substituted. Demo intentionally remains offline and uses sample data.

External bookmarks are local to this device and appear via Saved on device in the Live jobs view, separately from Firestore-backed portal Saved. Application submission and decisions on third-party websites are outside NextRole.

Android requires INTERNET permission, already set by the platform configuration script. On Flutter web the source must permit cross-origin requests; browser/CORS failures show a feed error and retain cached results. Android is the primary target for this integration.

Provider attribution and original listing links are retained. Public endpoint availability/terms can change. For large-scale public traffic, arrange a provider-approved server cache rather than relying on per-device requests.

Validation: API documentation and a live public JSON response were inspected using web retrieval. Dart syntax/JSON/ZIP checks passed. Flutter analyzer, dependency resolution, tests, APK and device browser launching were not executed here. Included mock tests cover normalization, malformed URLs, caching, deduplication, HTTP failure and bookmarks.

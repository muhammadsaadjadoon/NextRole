# NextRole 2.0 — start here

This is a full replacement source folder. Firebase Storage is not used. Keep your old project as a backup while setting up this folder.

## Windows: first launch

Extract NextRole into a new folder, for example `D:\NextRole-v2`, and open PowerShell there:

```powershell
cd "D:\NextRole-v2"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\bootstrap.ps1
flutter emulators
```

Launch the actual AVD ID printed by the previous command:

```powershell
flutter emulators --launch YOUR_AVD_ID
flutter devices
flutter run -d emulator-5554 --dart-define=DEMO=true
```

Replace emulator-5554 if your device ID is different. Demo is local sample data, with candidate/employer/admin switching from the toolbar. There is no need to open Android Studio to launch an existing emulator.

## Connect your existing NextRole Firebase project

Stop the running demo with `q`. The source archive intentionally does not contain your local Firebase configuration. You can run FlutterFire directly:

```powershell
dart pub global run flutterfire_cli:flutterfire configure --project=nextrole-cedbc --platforms=android
firebase deploy --only firestore --project nextrole-cedbc
flutter run -d emulator-5554
```

Use nextrole-cedbc only if it is still your actual NextRole project. Firebase CLI must be signed into the Google account that has access. Android applicationId is com.saadi.nextrole. Do not accept reuse of configuration for a different project.

If you want to bring your old client config into this folder first, after bootstrap:

```powershell
.\scripts\import_firebase.ps1 -SourceProject "D:\ARTIFICIAL INTELLIGENCE\PROJECTS\NEXTROLE"
```

Then still run FlutterFire configure for the same project above, so the generated Android Gradle configuration is integrated correctly.

Existing accounts, jobs and applications stay in Firestore when you use the same project. Deploy the new rules to enable candidate withdrawal. cvPath/cvName stay as empty compatibility fields for new applications. Existing PDF attachments are not displayed.

## Portal jobs versus automatic public jobs

The Live jobs feed automatically fetches Arbeitnow listings in normal mode. NextRole employer listings come from Firestore; a new Firebase database has no portal vacancies. Create an admin and employer, approve the company, let it post a vacancy, then approve the vacancy as admin. Only approved, open and unexpired jobs appear in candidate discovery. No external job website integration is included.

To create your first admin: register in the app, then open Firestore users → your UID document and set role to the string admin and active to boolean true. Role selection at signup never allows admin.

## Verify before committing

```powershell
.\scripts\verify.ps1
```

Checks dependencies, analysis, Flutter tests and Android demo APK build. A demo build is not proof that live Firebase is configured. See docs/ACCEPTANCE.md for the separate live checklist.

# Publish NextRole to GitHub

## Existing working installation

This package contains the latest source available from our work here. It cannot include unshared changes or generated native configuration from your Windows machine.

Keep a backup of your working project. Copy its configured lib/firebase_options.dart and native Firebase client configuration into your local repository after bootstrap, or run FlutterFire configure again. These are client configuration files, not Firebase Admin private keys. Do not publish service-account JSON, environment secrets, signing keys or passwords.

The source package can be published without client configuration; document that users must configure their own Firebase project. For reproducibility, generate platform folders, run the checks and commit your generated platform source and pubspec.lock. Exclude build output, local SDK paths, dependency caches and node_modules using the supplied .gitignore.

## Screenshot review

All 13 screenshots were supplied by the project owner and are included unchanged. Profile screenshots contain a personal email, phone number, location and biography. Review them before making the repository public. If you prefer, replace the profile screenshots with captures containing demo contact details and retain the same filenames.

## GitHub Desktop

Create a repository, choose Show in Explorer, then copy the CONTENTS of NextRole into its root. README.md, pubspec.yaml and lib must be at that root, not inside another nested NextRole directory. Review Changes for private credentials, run verification, commit and Publish repository. Choose public/private intentionally. No LICENSE is included because a license has not been selected.

## Validation

Run scripts/bootstrap.ps1 for a fresh source-only checkout, then scripts/verify.ps1. Configure Firebase for real accounts and test the full hiring flow using docs/ACCEPTANCE.md. A successful demo build does not validate live Firebase permissions or the external provider network.

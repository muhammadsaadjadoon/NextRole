import 'dart:io';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (manifest.existsSync()) {
    var text = manifest.readAsStringSync().replaceAll(
      'android:label="nextrole"',
      'android:label="NextRole"',
    );
    if (!text.contains('android.permission.INTERNET')) {
      text = text.replaceFirst(
        '<application',
        '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
      );
    }
    manifest.writeAsStringSync(text);
  }
  final plist = File('ios/Runner/Info.plist');
  if (plist.existsSync()) {
    var text = plist.readAsStringSync();
    if (!text.contains('NSPhotoLibraryUsageDescription')) {
      text = text.replaceFirst(
        '</dict>',
        '<key>NSPhotoLibraryUsageDescription</key><string>Select a professional profile photo.</string>\n</dict>',
      );
    }
    plist.writeAsStringSync(text);
  }
  final generated = File('test/widget_test.dart');
  if (generated.existsSync() &&
      generated.readAsStringSync().contains('MyApp')) {
    generated.deleteSync();
  }
}

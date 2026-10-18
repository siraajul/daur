import 'package:daur/build_channel.dart';
import 'package:daur/firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android package channel selects its matching Firebase app', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(
      DefaultFirebaseOptions.currentPlatform.appId,
      isPreview
          ? '1:179925532044:android:48c933d60808134954aaa9'
          : '1:179925532044:android:6756796d5a2804a454aaa9',
    );
    expect(DefaultFirebaseOptions.currentPlatform.projectId, 'daurfit');
    expect(appDisplayName, isPreview ? 'Daur Preview' : 'Daur');
    expect(
      DefaultFirebaseOptions.androidPreview.appId,
      isNot(DefaultFirebaseOptions.android.appId),
    );
  });
}

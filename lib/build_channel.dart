/// A separate Android package and Firebase app for side-by-side tester installs.
const isPreview = bool.fromEnvironment('DAUR_PREVIEW');
const appDisplayName = isPreview ? 'Daur Preview' : 'Daur';

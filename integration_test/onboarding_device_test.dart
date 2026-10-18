// Run the same bounded setup regression suite on a physical Flutter renderer.
// The imported suite replaces preferences and auth with in-memory test doubles;
// it never attaches cloud sync or reads/writes the installed user's saved data.
import 'package:integration_test/integration_test.dart';

import '../test/onboarding_test.dart' as setup;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setup.main();
}

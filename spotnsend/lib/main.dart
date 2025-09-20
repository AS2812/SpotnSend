<<<<<<< HEAD
﻿import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SpotnSendApp()));
}

=======
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // ignore missing env file in production builds
  }
  runApp(const ProviderScope(child: SpotnSendApp()));
}
>>>>>>> 3f1d5939b69ebb53fd7acf28c8557f4585162768

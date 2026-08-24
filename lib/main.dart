import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/chglog_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const url = String.fromEnvironment('SUPABASE_URL');
  const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  if (url.isEmpty || publishableKey.isEmpty || googleWebClientId.isEmpty) {
    runApp(const _ConfigurationRequiredApp());
    return;
  }

  await Supabase.initialize(url: url, publishableKey: publishableKey);
  runApp(
    ChgLogApp(
      service: SupabaseChgLogService(
        Supabase.instance.client,
        googleWebClientId: googleWebClientId,
      ),
    ),
  );
}

class _ConfigurationRequiredApp extends StatelessWidget {
  const _ConfigurationRequiredApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.settings_outlined, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'CHGLog configuration required',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Restart the app with the Supabase URL, publishable key, '
                      'and Google Web client ID defined. See SETUP.md for the '
                      'launch command.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

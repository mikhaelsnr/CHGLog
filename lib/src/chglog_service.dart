import 'models.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class ChgLogService {
  Future<AppUser> signInWithGoogle();
  Future<ChangeRecord?> findChange(String number);
  Future<CheckInReceipt> submitCheckIn(
    ChangeRecord change,
    CheckInDetails details,
  );
  Future<void> addWlnActivity(ChangeRecord change);
  Future<void> registerNotifications();
  Future<List<ActivityRecord>> listActivities();
  Future<void> signOut();
}

class MockChgLogService implements ChgLogService {
  const MockChgLogService();

  @override
  Future<AppUser> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    return const AppUser(email: 'demo@huawei.com', displayName: 'Demo User');
  }

  @override
  Future<ChangeRecord?> findChange(String number) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!RegExp(r'^CHG\d{7}$').hasMatch(number)) return null;
    return ChangeRecord(
      number: number,
      title: 'Sample change title',
      objective: 'Sample objective shown only in widget tests.',
      status: 'Not checked in',
      loginTime: null,
      logoutTime: null,
      proponent: 'Sample proponent',
    );
  }

  @override
  Future<CheckInReceipt> submitCheckIn(
    ChangeRecord change,
    CheckInDetails details,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 750));
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return CheckInReceipt(timeText: '$hour${minute}H');
  }

  @override
  Future<void> addWlnActivity(ChangeRecord change) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> registerNotifications() async {}

  @override
  Future<List<ActivityRecord>> listActivities() async => const [];
}

class SupabaseChgLogService implements ChgLogService {
  SupabaseChgLogService(this._client, {required this.googleWebClientId});

  final SupabaseClient _client;
  final String googleWebClientId;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;
  bool _listeningForTokenRefresh = false;

  @override
  Future<AppUser> signInWithGoogle() async {
    if (!_googleInitialized) {
      await _googleSignIn.initialize(serverClientId: googleWebClientId);
      _googleInitialized = true;
    }

    final googleUser = await _googleSignIn.authenticate(
      scopeHint: const ['email', 'profile'],
    );
    final googleAuth = googleUser.authentication;
    final authorization =
        await googleUser.authorizationClient.authorizationForScopes(const [
          'email',
          'profile',
        ]) ??
        await googleUser.authorizationClient.authorizeScopes(const [
          'email',
          'profile',
        ]);
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw StateError('Google did not return an identity token.');
    }

    late final AuthResponse response;
    try {
      response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization.accessToken,
      );
    } on AuthException catch (error) {
      throw StateError(error.message);
    }
    final user = response.user;
    final email = user?.email?.toLowerCase();
    if (user == null || email == null) {
      await signOut();
      throw StateError('Google did not return a valid company email.');
    }

    final metadata = user.userMetadata;
    final displayName =
        metadata?['full_name'] as String? ??
        metadata?['name'] as String? ??
        email.split('@').first;
    return AppUser(email: email, displayName: displayName);
  }

  @override
  Future<ChangeRecord?> findChange(String number) async {
    final response = await _client.functions.invoke(
      'chglog',
      body: {'action': 'find', 'number': number},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['found'] != true) return null;
    return ChangeRecord(
      number: data['number'] as String,
      title: data['title'] as String? ?? '',
      objective: data['objective'] as String? ?? '',
      status: data['status'] as String? ?? 'Not checked in',
      loginTime: data['loginTime'] as String?,
      logoutTime: data['logoutTime'] as String?,
      hasUnassignedManualActivity:
          data['hasUnassignedManualActivity'] as bool? ?? false,
      isWlnUser: data['isWlnUser'] as bool? ?? false,
      hasCurrentUserActivity: data['hasCurrentUserActivity'] as bool? ?? false,
      fullName: data['fullName'] as String?,
      company: data['company'] as String?,
      contactNumber: data['contactNumber'] as String?,
      email: data['email'] as String?,
      wlnImplementer: data['wlnImplementer'] as String?,
      proponent: data['proponent'] as String? ?? '',
    );
  }

  @override
  Future<CheckInReceipt> submitCheckIn(
    ChangeRecord change,
    CheckInDetails details,
  ) async {
    final response = await _client.functions.invoke(
      'chglog',
      body: {
        'action': 'submit',
        'number': change.number,
        'fullName': details.fullName,
        'company': details.company,
        'contactNumber': details.contactNumber,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return CheckInReceipt(timeText: data['timeText'] as String);
  }

  @override
  Future<void> addWlnActivity(ChangeRecord change) async {
    await _client.functions.invoke(
      'chglog',
      body: {'action': 'add-wln-activity', 'number': change.number},
    );
  }

  @override
  Future<void> registerNotifications() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _registerDeviceToken(token);
    if (!_listeningForTokenRefresh) {
      _listeningForTokenRefresh = true;
      FirebaseMessaging.instance.onTokenRefresh.listen(_registerDeviceToken);
    }
  }

  Future<void> _registerDeviceToken(String token) async {
    await _client.functions.invoke(
      'chglog',
      body: {'action': 'register-device', 'token': token},
    );
  }

  @override
  Future<List<ActivityRecord>> listActivities() async {
    final response = await _client.functions
        .invoke('chglog', body: {'action': 'list-activities'})
        .timeout(const Duration(seconds: 15));
    final data = Map<String, dynamic>.from(response.data as Map);
    final rows = data['activities'] as List? ?? const [];
    return rows.map((row) {
      final activity = Map<String, dynamic>.from(row as Map);
      return ActivityRecord(
        id: activity['id'] as String,
        changeNumber: activity['change_number'] as String,
        title: activity['title'] as String? ?? '',
        objective: activity['objective'] as String? ?? '',
        proponent: activity['proponent'] as String? ?? '',
        status: activity['status'] as String,
        checkedInAt: DateTime.parse(activity['checked_in_at'] as String),
        statusUpdatedAt: DateTime.parse(
          activity['status_updated_at'] as String,
        ),
        onsiteImplementer: activity['full_name'] as String?,
        wlnImplementer: activity['wln_implementer'] as String?,
        checkedOutAt: activity['checked_out_at'] == null
            ? null
            : DateTime.parse(activity['checked_out_at'] as String),
        checkedOutTime: activity['checked_out_time'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    if (_googleInitialized) await _googleSignIn.signOut();
  }
}

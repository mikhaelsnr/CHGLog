class AppUser {
  const AppUser({required this.email, required this.displayName});

  final String email;
  final String displayName;
}

class ChangeRecord {
  const ChangeRecord({
    required this.number,
    required this.title,
    required this.objective,
    required this.status,
    this.loginTime,
    this.logoutTime,
    this.hasUnassignedManualActivity = false,
    this.isWlnUser = false,
    this.hasCurrentUserActivity = false,
    this.fullName,
    this.company,
    this.contactNumber,
    this.email,
    this.wlnImplementer,
    required this.proponent,
  });

  final String number;
  final String title;
  final String objective;
  final String status;
  final String? loginTime;
  final String? logoutTime;
  final bool hasUnassignedManualActivity;
  final bool isWlnUser;
  final bool hasCurrentUserActivity;
  final String? fullName;
  final String? company;
  final String? contactNumber;
  final String? email;
  final String? wlnImplementer;
  final String proponent;
}

class CheckInDetails {
  const CheckInDetails({
    required this.fullName,
    required this.company,
    required this.contactNumber,
  });

  final String fullName;
  final String company;
  final String contactNumber;

  String get sheetValue => '$fullName | $company | $contactNumber';
}

class CheckInReceipt {
  const CheckInReceipt({required this.timeText});

  final String timeText;
}

class ActivityRecord {
  const ActivityRecord({
    required this.id,
    required this.changeNumber,
    required this.title,
    required this.objective,
    required this.proponent,
    required this.status,
    required this.checkedInAt,
    required this.statusUpdatedAt,
    this.onsiteImplementer,
    this.wlnImplementer,
    this.checkedOutAt,
    this.checkedOutTime,
  });

  final String id;
  final String changeNumber;
  final String title;
  final String objective;
  final String proponent;
  final String status;
  final DateTime checkedInAt;
  final DateTime statusUpdatedAt;
  final String? onsiteImplementer;
  final String? wlnImplementer;
  final DateTime? checkedOutAt;
  final String? checkedOutTime;
}

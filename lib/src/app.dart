import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chglog_service.dart';
import 'models.dart';

const _globeBlue = Color(0xFF0057B8);
const _globeCyan = Color(0xFF00AEEF);

class ChgLogApp extends StatelessWidget {
  const ChgLogApp({super.key, this.service = const MockChgLogService()});

  final ChgLogService service;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CHGLog',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: SignInPage(service: service),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _globeBlue,
      brightness: brightness,
      primary: _globeBlue,
      secondary: _globeCyan,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF7F9FC)
          : const Color(0xFF101318),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF1C2129),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key, required this.service});

  final ChgLogService service;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await widget.service.signInWithGoogle();
      try {
        await widget.service.registerNotifications();
      } catch (_) {
        // Signing in remains usable if notification registration is unavailable.
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SearchPage(service: widget.service, user: user),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/chglog_logo.png',
                      width: 148,
                      height: 148,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Welcome to CHGLog',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in with an approved company account to find and log an active change.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    key: const Key('googleSignInButton'),
                    onPressed: _loading ? null : _signIn,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                      _loading ? 'Signing in...' : 'Continue with Google',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Approved vendor accounts only',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    _InlineMessage(message: _error!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.service, required this.user});

  final ChgLogService service;
  final AppUser user;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  ChangeRecord? _result;
  String? _message;
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _searching = true;
      _result = null;
      _message = null;
    });
    try {
      final result = await widget.service.findChange(_controller.text.trim());
      if (!mounted) return;
      setState(() {
        _result = result;
        _message = result == null
            ? 'No matching CHG was found in the ACTIVE sheet.'
            : null;
      });
    } catch (error) {
      if (mounted) setState(() => _message = _messageFor(error));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _signOut() async {
    await widget.service.signOut();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => SignInPage(service: widget.service),
      ),
      (_) => false,
    );
  }

  Future<void> _openCheckIn() async {
    final result = _result;
    if (result == null) return;
    final receipt = await showModalBottomSheet<CheckInReceipt>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CheckInSheet(
        service: widget.service,
        change: result,
        initialName: widget.user.displayName,
      ),
    );
    if (receipt == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.hasUnassignedManualActivity
              ? '${result.number} manual login details saved.'
              : result.hasCurrentUserActivity
              ? '${result.number} details updated.'
              : '${result.number} logged at ${receipt.timeText}',
        ),
      ),
    );
    setState(() {
      _controller.clear();
      _result = null;
      _message = null;
    });
  }

  Future<void> _addWlnActivity() async {
    final result = _result;
    if (result == null) return;
    setState(() {
      _searching = true;
      _message = null;
    });
    try {
      await widget.service.addWlnActivity(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.number} added to My activities.')),
      );
      setState(() {
        _controller.clear();
        _result = null;
      });
    } catch (error) {
      if (mounted) setState(() => _message = _messageFor(error));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/chglog_mark.png',
          height: 38,
          width: 38,
          semanticLabel: 'CHGLog',
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ActivityPage(service: widget.service),
              ),
            ),
            tooltip: 'My activities',
            icon: const Icon(Icons.history),
          ),
          IconButton(
            onPressed: _signOut,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find an active change',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      key: const Key('chgField'),
                      controller: _controller,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) {
                        final upper = value.toUpperCase();
                        if (upper != value) {
                          _controller.value = _controller.value.copyWith(
                            text: upper,
                            selection: TextSelection.collapsed(
                              offset: upper.length,
                            ),
                          );
                        }
                      },
                      onFieldSubmitted: (_) => _search(),
                      decoration: const InputDecoration(
                        labelText: 'Change number',
                        hintText: 'CHG0012345',
                        prefixIcon: Icon(Icons.manage_search),
                      ),
                      validator: (value) {
                        final input = value?.trim() ?? '';
                        if (input.isEmpty) return 'Enter a CHG number.';
                        if (!RegExp(r'^CHG\d{7}$').hasMatch(input)) {
                          return 'Use the format CHG followed by 7 digits.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('searchButton'),
                    onPressed: _searching ? null : _search,
                    icon: _searching
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(
                      _searching ? 'Searching...' : 'Search ACTIVE sheet',
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 20),
                    _InlineMessage(message: _message!),
                  ],
                  if (_result != null) ...[
                    const SizedBox(height: 24),
                    _ChangeResult(
                      change: _result!,
                      onAction: _result!.isWlnUser
                          ? _addWlnActivity
                          : _openCheckIn,
                    ),
                  ],
                  const SizedBox(height: 32),
                  Divider(color: colors.outlineVariant),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: colors.secondaryContainer,
                        child: Text(widget.user.displayName.characters.first),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.user.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              widget.user.email,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key, required this.service});

  final ChgLogService service;

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  late Future<List<ActivityRecord>> _activities;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateUtils.dateOnly(DateTime.now());
    _activities = widget.service.listActivities();
  }

  Future<void> _refresh() async {
    final request = widget.service.listActivities();
    if (!mounted) return;
    setState(() => _activities = request);
    await request;
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateUtils.dateOnly(DateTime.now()),
      helpText: 'Select activity date',
    );
    if (selected != null && mounted) {
      setState(() => _selectedDate = DateUtils.dateOnly(selected));
    }
  }

  List<ActivityRecord> _activitiesForSelectedDate(
    List<ActivityRecord> activities,
  ) {
    final dayStart = _selectedDate;
    final nextDayStart = dayStart.add(const Duration(days: 1));
    final previousNightStart = dayStart.subtract(const Duration(hours: 2));
    return activities.where((activity) {
      final checkedIn = activity.checkedInAt.toLocal();
      final isOnSelectedDate =
          !checkedIn.isBefore(dayStart) && checkedIn.isBefore(nextDayStart);
      final isPreviousNightCarryover =
          !checkedIn.isBefore(previousNightStart) &&
          checkedIn.isBefore(dayStart);
      return isOnSelectedDate || isPreviousNightCarryover;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My activities',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          const _HotlineNote(),
          _HistoryDateBar(date: _selectedDate, onPressed: _selectDate),
          Expanded(
            child: FutureBuilder<List<ActivityRecord>>(
              future: _activities,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ActivityMessage(
                    icon: Icons.error_outline,
                    message: 'Activities could not be loaded.',
                    onRefresh: _refresh,
                  );
                }
                final allActivities = snapshot.data ?? const [];
                final activities = _activitiesForSelectedDate(allActivities);
                if (activities.isEmpty) {
                  return _ActivityMessage(
                    icon: Icons.history,
                    message: allActivities.isEmpty
                        ? 'Your check-ins will appear here.'
                        : 'No activities for the selected date.',
                    onRefresh: _refresh,
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: activities.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final activity = activities[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      activity.changeNumber,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: colors.secondaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      child: Text(
                                        activity.status,
                                        style: TextStyle(
                                          color: colors.onSecondaryContainer,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                activity.title.isEmpty
                                    ? 'Title not provided'
                                    : activity.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (activity.proponent.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  'Proponent: ${activity.proponent}',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (activity.onsiteImplementer?.isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 5),
                                Text(
                                  'Onsite implementer: ${activity.onsiteImplementer}',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (activity.wlnImplementer?.isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 5),
                                Text(
                                  'WLN implementer: ${activity.wlnImplementer}',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Text(
                                'Checked in ${_formatActivityTime(activity.checkedInAt)}',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              if (activity.status == 'implemented' &&
                                  activity.checkedOutAt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Checked out ${_formatActivityTime(activity.checkedOutAt!)}',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryDateBar extends StatelessWidget {
  const _HistoryDateBar({required this.date, required this.onPressed});

  final DateTime date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final formattedDate = MaterialLocalizations.of(context)
        .formatMediumDate(date);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text(isToday ? 'Today - $formattedDate' : formattedDate),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _HotlineNote extends StatelessWidget {
  const _HotlineNote();

  Future<void> _openDialer(BuildContext context) async {
    final opened = await launchUrl(
      Uri(scheme: 'tel', path: '0279172873'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The phone dialer could not be opened.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.support_agent, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'If you experience any delays or have a question for the Wireline implementer, please call our hotline and select option 2.',
                  style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => _openDialer(context),
                  icon: const Icon(Icons.phone_outlined, size: 19),
                  label: const Text('(02) 7917-2873'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityMessage extends StatelessWidget {
  const _ActivityMessage({
    required this.icon,
    required this.message,
    required this.onRefresh,
  });

  final IconData icon;
  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatActivityTime(DateTime value) {
  final local = value.toLocal();
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '${months[local.month - 1]} ${local.day}, ${local.year}, '
      '$hour:$minute $period';
}

String _formatSheetTime(String value) {
  final match = RegExp(r'^(\d{2})(\d{2})H$').firstMatch(value.trim());
  if (match == null) return value;

  final hour24 = int.parse(match.group(1)!);
  final minute = match.group(2)!;
  if (hour24 > 23 || int.parse(minute) > 59) return value;

  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final period = hour24 < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

class _ChangeResult extends StatelessWidget {
  const _ChangeResult({required this.change, required this.onAction});

  final ChangeRecord change;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: colors.primary),
              const SizedBox(width: 10),
              const Text(
                'Active change found',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            change.number,
            key: const Key('resultChangeNumber'),
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _ChangeDetail(label: 'Title', value: change.title),
          const SizedBox(height: 12),
          _ChangeDetail(label: 'Objective', value: change.objective),
          const SizedBox(height: 12),
          _ChangeDetail(label: 'Proponent', value: change.proponent),
          const SizedBox(height: 12),
          _ChangeDetail(label: 'Status', value: change.status),
          if (change.fullName?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _ChangeDetail(label: 'Onsite implementer', value: change.fullName!),
          ],
          if (change.company?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _ChangeDetail(label: 'Company', value: change.company!),
          ],
          if (change.contactNumber?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _ChangeDetail(label: 'Contact', value: change.contactNumber!),
          ],
          if (change.email?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _ChangeDetail(label: 'Email', value: change.email!),
          ],
          if (change.wlnImplementer?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _ChangeDetail(
              label: 'WLN implementer',
              value: change.wlnImplementer!,
            ),
          ],
          if (change.loginTime != null) ...[
            const SizedBox(height: 12),
            _ChangeDetail(
              label: 'Login time',
              value: _formatSheetTime(change.loginTime!),
            ),
          ],
          if (change.status == 'implemented' && change.logoutTime != null) ...[
            const SizedBox(height: 12),
            _ChangeDetail(
              label: 'Logout time',
              value: _formatSheetTime(change.logoutTime!),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('checkInButton'),
            onPressed: onAction,
            icon: Icon(
              change.isWlnUser ? Icons.playlist_add : Icons.how_to_reg,
            ),
            label: Text(
              change.isWlnUser
                  ? 'Add to my activities'
                  : change.hasCurrentUserActivity
                  ? 'Edit my details'
                  : change.hasUnassignedManualActivity
                  ? 'Complete manual login'
                  : 'Continue to check in',
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeDetail extends StatelessWidget {
  const _ChangeDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colors.onPrimaryContainer.withValues(alpha: 0.72),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value.isEmpty ? 'Not provided' : value,
          style: TextStyle(color: colors.onPrimaryContainer, height: 1.35),
        ),
      ],
    );
  }
}

class CheckInSheet extends StatefulWidget {
  const CheckInSheet({
    super.key,
    required this.service,
    required this.change,
    required this.initialName,
  });

  final ChgLogService service;
  final ChangeRecord change;
  final String initialName;

  @override
  State<CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<CheckInSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _companyController = TextEditingController();
  final _contactController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.change.fullName?.isNotEmpty == true
          ? widget.change.fullName
          : widget.initialName,
    );
    _companyController.text = widget.change.company ?? '';
    _contactController.text = widget.change.contactNumber ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final receipt = await widget.service.submitCheckIn(
        widget.change,
        CheckInDetails(
          fullName: _nameController.text.trim(),
          company: _companyController.text.trim(),
          contactNumber: _contactController.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop(receipt);
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.change.hasUnassignedManualActivity
                      ? 'Complete manual login'
                      : widget.change.hasCurrentUserActivity
                      ? 'Edit my details'
                      : 'Check in to ${widget.change.number}',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.change.hasUnassignedManualActivity
                      ? 'Confirm your details to link this hotline-assisted login to your account.'
                      : widget.change.hasCurrentUserActivity
                      ? 'Update your onsite implementer details for this activity.'
                      : 'Login time is recorded automatically when you submit.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('fullNameField'),
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Company',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('contactField'),
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) {
                    final requiredMessage = _required(value);
                    if (requiredMessage != null) return requiredMessage;
                    final digits = value!.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 7 || digits.length > 15) {
                      return 'Enter a valid contact number.';
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _InlineMessage(message: _error!),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('submitButton'),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _submitting
                        ? 'Submitting...'
                        : widget.change.hasUnassignedManualActivity
                        ? 'Save and link activity'
                        : widget.change.hasCurrentUserActivity
                        ? 'Save changes'
                        : 'Submit check-in',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: color),
          const SizedBox(width: 9),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

String _messageFor(Object error) {
  if (error is StateError) return error.message;
  return 'Something went wrong. Please try again.';
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/followup_model.dart';
import '../../models/lead_model.dart';
import '../../providers/leads_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/team_provider.dart';

/// Bottom sheets for the secured lead workflows (status, follow-ups,
/// reassignment, new lead). All mutations go through [LeadsProvider], which
/// calls the backend — Firestore rules keep these fields server-owned.

void _toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ),
  );
}

Widget _sheetHandle() => Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

Widget _sheetTitle(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );

Future<T?> _showSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: builder(ctx),
        ),
      ),
    ),
  );
}

/// Picks a date + time at least 5 minutes in the future (backend rule).
Future<DateTime?> pickFollowUpDateTime(BuildContext context, {DateTime? initial}) async {
  final now = DateTime.now();
  final minAt = now.add(const Duration(minutes: 6));
  final start = (initial != null && initial.isAfter(minAt))
      ? initial
      : now.add(const Duration(hours: 1));
  final date = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 365 * 2)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(start),
  );
  if (time == null) return null;
  final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  if (picked.isBefore(minAt)) {
    if (context.mounted) {
      _toast(context, 'Pick a time at least 5 minutes from now.', error: true);
    }
    return null;
  }
  return picked;
}

// ── Status ──────────────────────────────────────────────────────────────────

Future<void> showStatusPickerSheet(BuildContext context, LeadModel lead) async {
  final statuses = context.read<SettingsProvider>().statuses;
  final selected = await _showSheet<String>(
    context,
    (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHandle(),
        _sheetTitle('Change status'),
        ...statuses.map(
          (s) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              s == lead.status
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: s == lead.status ? AppColors.primary : AppColors.textTertiary,
            ),
            title: Text(s),
            onTap: () => Navigator.pop(ctx, s),
          ),
        ),
      ],
    ),
  );
  if (selected == null || selected == lead.status || !context.mounted) return;
  final err = await context.read<LeadsProvider>().updateLeadStatus(lead.id, selected);
  if (!context.mounted) return;
  _toast(context, err ?? 'Status updated to $selected', error: err != null);
}

// ── Schedule / reschedule ───────────────────────────────────────────────────

Future<void> showScheduleFollowUpSheet(
  BuildContext context,
  LeadModel lead, {
  FollowUpModel? existing,
}) async {
  if (lead.isClosed) {
    _toast(context, 'Closed or lost leads cannot receive follow-ups.', error: true);
    return;
  }
  String type = existing?.type ?? 'Call';
  if (!AppConstants.followUpTypes.contains(type)) type = 'Call';
  DateTime? dueAt = existing?.dueAt;
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  bool saving = false;

  await _showSheet<void>(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHandle(),
          _sheetTitle(existing != null ? 'Reschedule follow-up' : 'Schedule follow-up'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.followUpTypes
                .map((t) => ChoiceChip(
                      label: Text(t),
                      selected: type == t,
                      onSelected: (_) => setState(() => type = t),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule_rounded, size: 18),
            label: Text(dueAt == null
                ? 'Pick date & time'
                : DateFormat('EEE, MMM dd • hh:mm a').format(dueAt!)),
            onPressed: () async {
              final picked = await pickFollowUpDateTime(ctx, initial: dueAt);
              if (picked != null) setState(() => dueAt = picked);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleCtrl,
            maxLength: 180,
            decoration: const InputDecoration(
              labelText: 'Title (optional)',
              hintText: 'e.g. Share price quote',
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: saving || dueAt == null
                ? null
                : () async {
                    setState(() => saving = true);
                    final err = await ctx.read<LeadsProvider>().scheduleFollowUp(
                          leadId: lead.id,
                          dueAt: dueAt!,
                          type: type,
                          title: titleCtrl.text,
                        );
                    if (!ctx.mounted) return;
                    setState(() => saving = false);
                    if (err == null) Navigator.pop(ctx);
                    _toast(context, err ?? 'Follow-up scheduled', error: err != null);
                  },
            child: saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

// ── Complete ────────────────────────────────────────────────────────────────

Future<void> showCompleteFollowUpSheet(BuildContext context, FollowUpModel task) async {
  final statuses = context.read<SettingsProvider>().statuses;
  final lead = context.read<LeadsProvider>().getLeadById(task.leadId);
  String outcome = 'Connected';
  String? leadStatus;
  DateTime? nextDueAt;
  final noteCtrl = TextEditingController();
  bool saving = false;

  bool isTerminal(String o) => o == 'Closed-won' || o == 'Lost';
  final openStatuses =
      statuses.where((s) => s != 'Closed-Won' && s != 'Lost').toList();

  await _showSheet<void>(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHandle(),
          _sheetTitle('Complete follow-up'),
          Text(
            task.leadName ?? lead?.name ?? 'Lead',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          const Text('Outcome', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.followUpOutcomes
                .map((o) => ChoiceChip(
                      label: Text(o),
                      selected: outcome == o,
                      onSelected: (_) => setState(() {
                        outcome = o;
                        if (isTerminal(o)) {
                          nextDueAt = null;
                          leadStatus = null;
                        }
                      }),
                    ))
                .toList(),
          ),
          if (!isTerminal(outcome)) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              value: leadStatus,
              decoration: const InputDecoration(labelText: 'Lead status (optional)'),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Keep "${lead?.status ?? 'current'}"'),
                ),
                ...openStatuses.map(
                  (s) => DropdownMenuItem<String?>(value: s, child: Text(s)),
                ),
              ],
              onChanged: (v) => setState(() => leadStatus = v),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_repeat_rounded, size: 18),
              label: Text(nextDueAt == null
                  ? 'Schedule next follow-up (optional)'
                  : 'Next: ${DateFormat('EEE, MMM dd • hh:mm a').format(nextDueAt!)}'),
              onPressed: () async {
                final picked = await pickFollowUpDateTime(ctx, initial: nextDueAt);
                if (picked != null) setState(() => nextDueAt = picked);
              },
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            maxLines: 3,
            maxLength: 1600,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'What happened on this follow-up?',
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: saving
                ? null
                : () async {
                    setState(() => saving = true);
                    final err = await ctx.read<LeadsProvider>().completeFollowUp(
                          task: task,
                          outcome: outcome,
                          note: noteCtrl.text,
                          leadStatus: isTerminal(outcome) ? null : leadStatus,
                          nextDueAt: isTerminal(outcome) ? null : nextDueAt,
                        );
                    if (!ctx.mounted) return;
                    setState(() => saving = false);
                    if (err == null) Navigator.pop(ctx);
                    _toast(context, err ?? 'Follow-up completed', error: err != null);
                  },
            child: saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Mark complete'),
          ),
        ],
      ),
    ),
  );
}

/// Tap action for a follow-up card: complete / reschedule / open lead.
Future<void> showFollowUpActionsSheet(
  BuildContext context,
  FollowUpModel task, {
  VoidCallback? onOpenLead,
}) async {
  final lead = context.read<LeadsProvider>().getLeadById(task.leadId);
  final action = await _showSheet<String>(
    context,
    (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHandle(),
        _sheetTitle(task.title ?? '${task.type} follow-up'),
        if (task.isOpen)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle_rounded, color: AppColors.success),
            title: const Text('Mark complete'),
            onTap: () => Navigator.pop(ctx, 'complete'),
          ),
        if (task.isOpen && lead != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_repeat_rounded, color: AppColors.info),
            title: const Text('Reschedule'),
            onTap: () => Navigator.pop(ctx, 'reschedule'),
          ),
        if (onOpenLead != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_rounded, color: AppColors.primary),
            title: const Text('Open lead'),
            onTap: () => Navigator.pop(ctx, 'open'),
          ),
      ],
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case 'complete':
      await showCompleteFollowUpSheet(context, task);
      break;
    case 'reschedule':
      if (lead != null) await showScheduleFollowUpSheet(context, lead, existing: task);
      break;
    case 'open':
      onOpenLead?.call();
      break;
  }
}

// ── Reassign (admin) ────────────────────────────────────────────────────────

Future<void> showReassignSheet(BuildContext context, LeadModel lead) async {
  final members = context.read<TeamProvider>().activeMembers;
  if (members.isEmpty) {
    _toast(context, 'No active team members found.', error: true);
    return;
  }
  final selected = await _showSheet<String>(
    context,
    (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHandle(),
        _sheetTitle('Assign lead to'),
        ...members.map(
          (m) {
            final uid = m.uid ?? m.id;
            final current = uid == lead.assignedTo;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: Text(m.initials,
                    style: const TextStyle(color: AppColors.primary, fontSize: 12)),
              ),
              title: Text(m.name),
              subtitle: Text(m.role),
              trailing: current
                  ? const Icon(Icons.check_rounded, color: AppColors.success)
                  : null,
              onTap: current ? null : () => Navigator.pop(ctx, uid),
            );
          },
        ),
      ],
    ),
  );
  if (selected == null || !context.mounted) return;
  final err = await context.read<LeadsProvider>().reassignLead(lead.id, selected);
  if (!context.mounted) return;
  _toast(context, err ?? 'Lead reassigned', error: err != null);
}

// ── Add lead (admin) ────────────────────────────────────────────────────────

Future<void> showAddLeadSheet(BuildContext context) async {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final reqCtrl = TextEditingController();
  String priority = 'Warm';
  bool saving = false;
  final formKey = GlobalKey<FormState>();

  await _showSheet<void>(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(),
            _sheetTitle('New lead'),
            TextFormField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                hintText: '10-digit mobile or +country code',
              ),
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                return digits.length < 7 || digits.length > 15
                    ? 'Enter a valid phone number'
                    : null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: reqCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Requirement (optional)'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: AppConstants.leadPriorities
                  .map((p) => ChoiceChip(
                        label: Text(p),
                        selected: priority == p,
                        onSelected: (_) => setState(() => priority = p),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setState(() => saving = true);
                      final err = await ctx.read<LeadsProvider>().createLead(
                            name: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            email: emailCtrl.text,
                            requirement: reqCtrl.text,
                            priority: priority,
                          );
                      if (!ctx.mounted) return;
                      setState(() => saving = false);
                      if (err == null) Navigator.pop(ctx);
                      _toast(context, err ?? 'Lead created', error: err != null);
                    },
              child: saving
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create lead'),
            ),
          ],
        ),
      ),
    ),
  );
}

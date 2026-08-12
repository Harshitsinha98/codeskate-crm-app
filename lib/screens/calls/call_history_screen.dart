import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/bridge_call_service.dart';

/// Admin/owner screen: bridge call history + recordings, backed by
/// /api/v1/bridge-call/history and /recordings.
class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final BridgeCallService _service;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    final auth = context.read<AuthProvider>();
    _service = BridgeCallService(auth.getIdToken);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orgId = context.read<AuthProvider>().user?.activeOrgId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calls'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'History'),
            Tab(text: 'Recordings'),
          ],
        ),
      ),
      body: orgId == null
          ? const Center(child: Text('No organization'))
          : TabBarView(
              controller: _tabs,
              children: [
                _CallList(
                  key: const ValueKey('history'),
                  orgId: orgId,
                  fetch: (cursor) =>
                      _service.history(orgId: orgId, startAfter: cursor),
                  recordingsOnly: false,
                ),
                _CallList(
                  key: const ValueKey('recordings'),
                  orgId: orgId,
                  fetch: (cursor) =>
                      _service.recordings(orgId: orgId, startAfter: cursor),
                  recordingsOnly: true,
                ),
              ],
            ),
    );
  }
}

class _CallList extends StatefulWidget {
  final String orgId;
  final Future<HistoryPage> Function(int? cursor) fetch;
  final bool recordingsOnly;

  const _CallList({
    super.key,
    required this.orgId,
    required this.fetch,
    required this.recordingsOnly,
  });

  @override
  State<_CallList> createState() => _CallListState();
}

class _CallListState extends State<_CallList> {
  final List<BridgeCallRecord> _items = [];
  final _scroll = ScrollController();
  bool _loading = false;
  bool _hasMore = true;
  int? _cursor;
  bool _firstLoadDone = false;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scroll.addListener(() {
      if (_scroll.position.pixels >=
              _scroll.position.maxScrollExtent - 300 &&
          !_loading &&
          _hasMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    setState(() => _loading = true);
    final page = await widget.fetch(_cursor);
    if (!mounted) return;
    setState(() {
      _items.addAll(page.items);
      _cursor = page.nextCursor;
      _hasMore = page.hasMore && page.nextCursor != null;
      _loading = false;
      _firstLoadDone = true;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _cursor = null;
      _hasMore = true;
      _firstLoadDone = false;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    if (!_firstLoadDone && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Icon(
              widget.recordingsOnly
                  ? Icons.mic_none_rounded
                  : Icons.call_rounded,
              size: 44,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                widget.recordingsOnly
                    ? 'No recordings yet'
                    : 'No bridge calls yet',
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(12),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _CallTile(
            record: _items[i],
            showPlay: widget.recordingsOnly,
          );
        },
      ),
    );
  }
}

class _CallTile extends StatelessWidget {
  final BridgeCallRecord record;
  final bool showPlay;
  const _CallTile({required this.record, required this.showPlay});

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  ({Color color, IconData icon, String label}) _statusMeta() {
    switch (record.status) {
      case 'completed':
      case 'wallet-deducted':
        return (color: AppColors.success, icon: Icons.call_rounded, label: 'Completed');
      case 'no-answer':
        return (color: AppColors.warning, icon: Icons.call_missed_rounded, label: 'No answer');
      case 'customer_voicemail':
        return (color: AppColors.warning, icon: Icons.voicemail_rounded, label: 'Voicemail');
      case 'agent_no_confirm':
        return (color: AppColors.textTertiary, icon: Icons.call_end_rounded, label: 'Cancelled');
      default:
        return (color: AppColors.error, icon: Icons.error_outline_rounded, label: 'Failed');
    }
  }

  Future<void> _play(BuildContext context) async {
    final url = record.recordingUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the recording.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _statusMeta();
    final dt = record.initiatedAtMs > 0
        ? DateFormat('dd MMM, hh:mm a')
            .format(DateTime.fromMillisecondsSinceEpoch(record.initiatedAtMs))
        : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: meta.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(meta.icon, size: 20, color: meta.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.leadName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${record.employeeName} · $dt',
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(meta.label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: meta.color)),
                    if (record.customerSeconds > 0) ...[
                      Text(' · ${_fmt(record.customerSeconds)}',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ],
                    if (record.costInr > 0) ...[
                      Text(' · ₹${record.costInr.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (showPlay && record.recordingUrl != null)
            IconButton(
              onPressed: () => _play(context),
              icon: const Icon(Icons.play_circle_fill_rounded),
              color: AppColors.primary,
              iconSize: 32,
            ),
        ],
      ),
    );
  }
}

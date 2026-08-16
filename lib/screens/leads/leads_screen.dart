import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/leads_provider.dart';
import '../../models/lead_model.dart';
import '../widgets/lead_mini_card.dart';
import '../widgets/ui_kit.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  String _selectedStatus = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LeadModel> _filterLeads(List<LeadModel> leads) {
    var filtered = leads;
    if (_selectedStatus != 'All') {
      filtered = filtered.where((l) => l.status == _selectedStatus).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where((l) =>
              l.name.toLowerCase().contains(q) ||
              l.phone.contains(q) ||
              (l.email?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final leads = context.watch<LeadsProvider>();
    final statuses = ['All', ...AppConstants.leadStatuses];
    final filteredLeads = _filterLeads(leads.leads);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: const Text(
          'Leads',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Search (filled, flat) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search name, phone or email',
                  hintStyle: const TextStyle(
                      fontSize: 13.5, color: AppColors.textTertiary),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20, color: AppColors.textTertiary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: AppColors.textTertiary,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 250.ms),

          // ── Status pills ──
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final status = statuses[index];
                final selected = _selectedStatus == status;
                return GestureDetector(
                  onTap: () => setState(() => _selectedStatus = status),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color:
                            selected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ).animate().fadeIn(delay: 80.ms),

          // ── Count row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                StatLabel('${filteredLeads.length} '
                    '${filteredLeads.length == 1 ? 'lead' : 'leads'}'),
                const Spacer(),
                if (_selectedStatus != 'All' || _searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedStatus = 'All';
                      });
                    },
                    child: const Text(
                      'Clear filters',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── List ──
          Expanded(
            child: leads.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : filteredLeads.isEmpty
                    ? Center(
                        child: EmptyState(
                          icon: _searchQuery.isNotEmpty
                              ? Icons.search_off_rounded
                              : Icons.inbox_rounded,
                          title: _searchQuery.isNotEmpty
                              ? 'No matching leads'
                              : 'Nothing in "$_selectedStatus"',
                          hint: _searchQuery.isNotEmpty
                              ? 'Try a different name or number.'
                              : 'Leads will appear here as they come in.',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filteredLeads.length,
                        itemBuilder: (context, index) {
                          final lead = filteredLeads[index];
                          return LeadMiniCard(
                            lead: lead,
                            onTap: () => context.push('/lead/${lead.id}'),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_state_views.dart';
import 'package:unicons/unicons.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _filter       = 'All';
  String _search       = '';
  bool   _searchOpen   = false;
  final _filters = ['All', 'Credit', 'Debit'];

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final dash    = context.watch<DashboardProvider>();
    final fmt     = NumberFormat('#,##0', 'en_US');
    final dateFmt = DateFormat('dd MMM yyyy');

    final txns = dash.transactions.where((t) {
      final matchFilter = _filter == 'All' ||
          (_filter == 'Credit' && t.isCredit) ||
          (_filter == 'Debit'  && !t.isCredit);
      final matchSearch = _search.isEmpty ||
          t.description.toLowerCase().contains(_search.toLowerCase());
      return matchFilter && matchSearch;
    }).toList();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: c.card, shape: BoxShape.circle,
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(UniconsLine.angle_left, color: c.textPrimary, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ACTIVITY', style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                const SizedBox(height: 4),
                Text('Every shilling, tracked', style: GoogleFonts.sora(
                    fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ])),
              IconButton(
                icon: Icon(_searchOpen ? UniconsLine.times : UniconsLine.search, color: AppColors.emeraldDeep),
                onPressed: () => setState(() {
                  _searchOpen = !_searchOpen;
                  if (!_searchOpen) _search = '';
                }),
              ),
            ]),
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: _searchOpen
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: TextField(
                      autofocus: true,
                      style: TextStyle(color: c.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search transactions...',
                        prefixIcon: Icon(UniconsLine.search, color: c.textHint),
                        filled: true,
                        fillColor: c.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: _filters.map((f) {
              final active = f == _filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? AppColors.emeraldDeep : c.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: active ? AppColors.emeraldDeep : c.border,
                      ),
                    ),
                    child: Text(f, style: TextStyle(
                        color: active ? Colors.white : c.textSecondary,
                        fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              );
            }).toList()),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: dash.loading
                ? const LoadingStateView()
                : dash.error != null
                    ? ErrorStateView(message: dash.error, onRetry: dash.refresh)
                    : txns.isEmpty
                        ? (_search.isNotEmpty
                            ? NoSearchResultsStateView(
                                query: _search,
                                onClear: () => setState(() { _search = ''; _searchOpen = false; }))
                            : const EmptyStateView(
                                title: 'No transactions yet',
                                message: 'Your deposits, withdrawals and repayments will show up here.',
                                icon: UniconsLine.receipt,
                              ))
                        : ListView.separated(
                        key: ValueKey('$_filter|$_search'),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        itemCount: txns.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final t = txns[i];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: c.border),
                            ),
                            child: Row(children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: t.isCredit ? AppColors.success : AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(t.isCredit ? '+' : '–', style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18, fontWeight: FontWeight.w900)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: c.textPrimary,
                                          fontWeight: FontWeight.w700, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text(dateFmt.format(t.date),
                                      style: TextStyle(color: c.textSecondary, fontSize: 10)),
                                ],
                              )),
                              const SizedBox(width: 8),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(
                                  '${t.isCredit ? '+' : '–'} ${fmt.format(t.amount)}',
                                  style: GoogleFonts.sora(
                                    color: t.isCredit ? AppColors.success : AppColors.error,
                                    fontWeight: FontWeight.w800, fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(_channelLabel(t.channel).toUpperCase(), style: TextStyle(
                                    color: c.textHint,
                                    fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .5)),
                              ]),
                            ]),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }

  String _channelLabel(String channel) {
    switch (channel) {
      case 'mobile_money': return 'Mobile Money';
      case 'online':       return 'Online';
      default:              return 'Internal';
    }
  }
}

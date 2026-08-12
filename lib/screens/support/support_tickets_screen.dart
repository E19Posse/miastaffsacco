import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/support_ticket.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_state_views.dart';
import 'new_support_ticket_screen.dart';
import 'support_ticket_detail_screen.dart';
import 'package:unicons/unicons.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});
  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final _api = ApiService();
  final _dateFmt = DateFormat('dd MMM yyyy');

  List<SupportTicket> _tickets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.getSupportTickets();
      final tickets = list
          .map((e) => SupportTicket.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() { _tickets = tickets; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.extractError(e); _loading = false; });
    }
  }

  Future<void> _openNewTicket() async {
    final created = await Navigator.push<bool>(
      context,
      SlideRoute(page: const NewSupportTicketScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _openTicket(SupportTicket ticket) async {
    await Navigator.push(
      context,
      SlideRoute(page: SupportTicketDetailScreen(ticketId: ticket.id)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
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
              Expanded(
                child: Text('Support Tickets',
                    style: GoogleFonts.sora(
                        fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ),
              TextButton.icon(
                onPressed: _openNewTicket,
                icon: const Icon(UniconsLine.plus, color: AppColors.emeraldDeep),
                label: Text('New', style: GoogleFonts.sora(color: AppColors.emeraldDeep, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.emeraldDeep,
              backgroundColor: c.card,
              onRefresh: _load,
              child: _loading
                  ? const LoadingStateView()
                  : _error != null
                      ? ErrorStateView(message: _error, onRetry: _load)
                      : _tickets.isEmpty
                          ? EmptyStateView(
                              title: 'No Support Tickets',
                              message: 'Raise a ticket and our team will get back to you.',
                              icon: UniconsLine.headphones,
                              actionLabel: 'New Ticket',
                              onAction: _openNewTicket,
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                              children: [
                                ..._tickets.map((t) => _TicketCard(
                                      ticket: t,
                                      dateFmt: _dateFmt,
                                      onTap: () => _openTicket(t),
                                    )),
                              ],
                            ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final SupportTicket ticket;
  final DateFormat dateFmt;
  final VoidCallback onTap;
  const _TicketCard({required this.ticket, required this.dateFmt, required this.onTap});

  (Color, String) _statusStyle(String status) => switch (status) {
    'open'            => (AppColors.gold, 'Open'),
    'in_progress'     => (AppColors.verifiedBlue, 'In Progress'),
    'awaiting_member' => (AppColors.warning, 'Awaiting You'),
    'escalated'       => (AppColors.danger, 'Escalated'),
    'resolved'        => (AppColors.emeraldMid, 'Resolved'),
    'closed'          => (AppColors.emeraldDeep, 'Closed'),
    _                 => (AppColors.gold, status),
  };

  String _categoryLabel(String cat) => switch (cat) {
    'loan_query'      => 'Loan Query',
    'savings_query'   => 'Savings Query',
    'account_access'  => 'Account Access',
    'payment_issue'   => 'Payment Issue',
    'kyc_document'    => 'KYC / Document',
    'technical_issue' => 'Technical Issue',
    'complaint'       => 'Complaint',
    _                 => 'Other',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (statusColor, statusLabel) = _statusStyle(ticket.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ticket.isOverdue ? AppColors.danger : c.border,
            width: ticket.isOverdue ? 1 : .5,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ticket.ticketNumber,
                    style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'monospace')),
                const SizedBox(height: 2),
                Text(ticket.subject,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)),
              child: Text(statusLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Icon(UniconsLine.tag_alt, size: 13, color: c.textSecondary),
            const SizedBox(width: 4),
            Text(_categoryLabel(ticket.category), style: TextStyle(color: c.textSecondary, fontSize: 11)),
            const Spacer(),
            if (ticket.repliesCount > 0) ...[
              Icon(UniconsLine.comment_dots, size: 13, color: c.textSecondary),
              const SizedBox(width: 3),
              Text('${ticket.repliesCount}', style: TextStyle(color: c.textSecondary, fontSize: 11)),
              const SizedBox(width: 10),
            ],
            Icon(UniconsLine.calendar_alt, size: 13, color: c.textSecondary),
            const SizedBox(width: 4),
            Text(dateFmt.format(ticket.createdAt), style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }
}


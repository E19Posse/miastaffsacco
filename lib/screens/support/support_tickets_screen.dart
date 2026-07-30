import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/support_ticket.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_animations.dart';
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
                  ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
                  : _error != null
                      ? _Error(message: _error!, onRetry: _load)
                      : _tickets.isEmpty
                          ? _Empty(onNew: _openNewTicket)
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

class _Empty extends StatelessWidget {
  final VoidCallback onNew;
  const _Empty({required this.onNew});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(UniconsLine.headphones, size: 64, color: context.colors.textHint),
      const SizedBox(height: 16),
      Text('No Support Tickets',
          style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Raise a ticket and our team will get back to you.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: onNew,
        icon: const Icon(UniconsLine.plus, size: 18),
        label: Text('New Ticket', style: GoogleFonts.sora(fontWeight: FontWeight.w800)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emeraldDeep,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const StadiumBorder(),
        ),
      ),
    ]),
  );
}

class _Error extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Error({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(UniconsLine.info_circle, size: 48, color: AppColors.danger),
      const SizedBox(height: 12),
      Text('Failed to load', style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(color: AppColors.emeraldDeep))),
    ]),
  );
}

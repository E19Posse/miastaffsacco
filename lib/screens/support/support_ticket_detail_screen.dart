import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/support_ticket.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_state_views.dart';
import 'package:unicons/unicons.dart';

class SupportTicketDetailScreen extends StatefulWidget {
  final int ticketId;
  const SupportTicketDetailScreen({super.key, required this.ticketId});
  @override
  State<SupportTicketDetailScreen> createState() => _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState extends State<SupportTicketDetailScreen> {
  final _api      = ApiService();
  final _replyCtrl= TextEditingController();
  final _dateFmt  = DateFormat('dd MMM yyyy, HH:mm');

  SupportTicket? _ticket;
  bool   _loading = true;
  bool   _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getSupportTicketDetail(widget.ticketId);
      final ticket = SupportTicket.fromJson(data);
      if (mounted) setState(() { _ticket = ticket; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.extractError(e); _loading = false; });
    }
  }

  Future<void> _sendReply() async {
    final body = _replyCtrl.text.trim();
    if (body.length < 2) return;
    setState(() => _sending = true);
    try {
      await _api.replySupportTicket(widget.ticketId, body);
      _replyCtrl.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ApiService.extractError(e)),
          backgroundColor: AppColors.danger,
        ));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

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
    final ticket = _ticket;
    final canReply = ticket != null && !ticket.isClosed;

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
                child: Text(ticket?.ticketNumber ?? 'Ticket',
                    style: GoogleFonts.sora(
                        fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ),
              if (ticket != null) Builder(builder: (_) {
                final (color, label) = _statusStyle(ticket.status);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                  child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                );
              }),
            ]),
          ),
          Expanded(
            child: _loading
                ? const LoadingStateView()
                : _error != null
                    ? ErrorStateView(message: _error, onRetry: _load)
                    : ticket == null
                        ? const SizedBox.shrink()
                        : RefreshIndicator(
                            color: AppColors.emeraldDeep,
                            backgroundColor: c.card,
                            onRefresh: _load,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: c.card,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: c.border, width: .5),
                                  ),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(ticket.subject,
                                        style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                                    const SizedBox(height: 8),
                                    Wrap(spacing: 8, runSpacing: 6, children: [
                                      _Chip(icon: UniconsLine.tag_alt, label: _categoryLabel(ticket.category)),
                                      _Chip(icon: UniconsLine.calendar_alt, label: _dateFmt.format(ticket.createdAt)),
                                      if (ticket.isOverdue)
                                        _Chip(icon: UniconsLine.exclamation_triangle, label: 'Overdue', color: AppColors.danger),
                                    ]),
                                    const SizedBox(height: 12),
                                    Text(ticket.description ?? '',
                                        style: TextStyle(color: c.textPrimary, fontSize: 13, height: 1.4)),
                                  ]),
                                ),
                                const SizedBox(height: 16),
                                ...ticket.replies.map((r) => _ReplyBubble(reply: r, dateFmt: _dateFmt)),
                                if (!canReply) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.emeraldMid,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(children: [
                                      const Icon(UniconsLine.check_circle, color: Colors.white, size: 18),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text('This ticket is closed.',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                      ),
                                    ]),
                                  ),
                                ],
                              ],
                            ),
                          ),
          ),
          if (canReply)
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 20),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _replyCtrl,
                    minLines: 1, maxLines: 4,
                    style: TextStyle(color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Type a reply...',
                      hintStyle: TextStyle(color: c.textHint),
                      filled: true, fillColor: c.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: c.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: c.border)),
                      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24)), borderSide: BorderSide(color: AppColors.emeraldDeep, width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _sendReply,
                  child: Container(
                    width: 46, height: 46,
                    decoration: const BoxDecoration(color: AppColors.emeraldDeep, shape: BoxShape.circle),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Icon(UniconsLine.message, color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _Chip({required this.icon, required this.label, this.color});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = color ?? c.surface;
    final onTint = color != null ? Colors.white : c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: onTint),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: onTint, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _ReplyBubble extends StatelessWidget {
  final TicketReply reply;
  final DateFormat dateFmt;
  const _ReplyBubble({required this.reply, required this.dateFmt});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isMine = reply.isMember;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isMine ? AppColors.emeraldDeep : c.card,
          borderRadius: BorderRadius.circular(16),
          border: isMine ? null : Border.all(color: c.border, width: .5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isMine ? 'You' : reply.author,
              style: TextStyle(
                  color: isMine ? Colors.white70 : c.textSecondary,
                  fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(reply.body,
              style: TextStyle(color: isMine ? Colors.white : c.textPrimary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 6),
          Text(dateFmt.format(reply.createdAt),
              style: TextStyle(color: isMine ? Colors.white60 : c.textHint, fontSize: 10)),
        ]),
      ),
    );
  }
}


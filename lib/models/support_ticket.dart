class SupportTicket {
  final int      id;
  final String   ticketNumber;
  final String   subject;
  final String?  description;
  final String   category;
  final String   priority;
  final String   status;
  final DateTime? slaDueAt;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final bool     isOverdue;
  final int      repliesCount;
  final List<TicketReply> replies;

  const SupportTicket({
    required this.id,
    required this.ticketNumber,
    required this.subject,
    this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.slaDueAt,
    required this.createdAt,
    this.resolvedAt,
    required this.isOverdue,
    required this.repliesCount,
    this.replies = const [],
  });

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
    id:           j['id'] as int,
    ticketNumber: j['ticket_number'] as String,
    subject:      j['subject'] as String,
    description:  j['description'] as String?,
    category:     j['category'] as String? ?? 'general',
    priority:     j['priority'] as String? ?? 'medium',
    status:       j['status'] as String? ?? 'open',
    slaDueAt:     j['sla_due_at'] != null ? DateTime.tryParse(j['sla_due_at']) : null,
    createdAt:    DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
    resolvedAt:   j['resolved_at'] != null ? DateTime.tryParse(j['resolved_at']) : null,
    isOverdue:    j['is_overdue'] as bool? ?? false,
    repliesCount: j['replies_count'] as int? ?? 0,
    replies:      (j['replies'] as List<dynamic>? ?? [])
        .map((e) => TicketReply.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  bool get isOpen     => status == 'open' || status == 'in_progress' || status == 'escalated';
  bool get isClosed   => status == 'resolved' || status == 'closed';
}

class TicketReply {
  final int      id;
  final String   body;
  final String   author;
  final bool     isMember;
  final DateTime createdAt;

  const TicketReply({
    required this.id,
    required this.body,
    required this.author,
    required this.isMember,
    required this.createdAt,
  });

  factory TicketReply.fromJson(Map<String, dynamic> j) => TicketReply(
    id:        j['id'] as int,
    body:      j['body'] as String,
    author:    j['author'] as String? ?? 'Support Team',
    isMember:  j['is_member'] as bool? ?? false,
    createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
  );
}

class LoanProduct {
  final int     id;
  final String  name;
  final double  interestRate;
  final double? minAmount;
  final double? maxAmount;
  final int?    minTermMonths;
  final int?    maxTermMonths;
  final String  description;

  const LoanProduct({
    required this.id,
    required this.name,
    required this.interestRate,
    this.minAmount,
    this.maxAmount,
    this.minTermMonths,
    this.maxTermMonths,
    required this.description,
  });

  factory LoanProduct.fromJson(Map<String, dynamic> j) => LoanProduct(
    id:            (j['id'] as num).toInt(),
    name:          j['name'] as String,
    interestRate:  (j['interest_rate'] as num).toDouble(),
    minAmount:     j['min_amount'] != null ? (j['min_amount'] as num).toDouble() : null,
    maxAmount:     j['max_amount'] != null ? (j['max_amount'] as num).toDouble() : null,
    minTermMonths: j['min_term_months'] != null ? int.parse(j['min_term_months'].toString()) : null,
    maxTermMonths: j['max_term_months'] != null ? int.parse(j['max_term_months'].toString()) : null,
    description:   j['description'] as String? ?? '',
  );
}

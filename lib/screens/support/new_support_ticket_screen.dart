import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

class NewSupportTicketScreen extends StatefulWidget {
  const NewSupportTicketScreen({super.key});
  @override
  State<NewSupportTicketScreen> createState() => _NewSupportTicketScreenState();
}

class _NewSupportTicketScreenState extends State<NewSupportTicketScreen> {
  final _api            = ApiService();
  final _formKey        = GlobalKey<FormState>();
  final _subjectCtrl    = TextEditingController();
  final _descriptionCtrl= TextEditingController();

  static const _categories = {
    'loan_query':      'Loan Query',
    'savings_query':   'Savings Query',
    'account_access':  'Account Access',
    'payment_issue':   'Payment Issue',
    'kyc_document':    'KYC / Document',
    'technical_issue': 'Technical Issue',
    'complaint':       'Complaint',
    'other':           'Other',
  };

  static const _priorities = {
    'low':    'Low — general enquiry',
    'medium': 'Medium — requires attention',
    'high':   'High — urgent issue',
    'urgent': 'Urgent — blocking my access',
  };

  String _category = 'other';
  String _priority = 'medium';
  bool   _busy     = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final res = await _api.createSupportTicket({
        'subject':     _subjectCtrl.text.trim(),
        'category':    _category,
        'priority':    _priority,
        'description': _descriptionCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ticket ${res['ticket_number']} submitted.'),
        backgroundColor: AppColors.emeraldDeep,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ApiService.extractError(e)),
          backgroundColor: AppColors.danger,
        ));
      }
    }
    if (mounted) setState(() => _busy = false);
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
                child: Text('Submit a Ticket',
                    style: GoogleFonts.sora(
                        fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Category', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _Dropdown<String>(
                    value: _category,
                    items: _categories.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                  const SizedBox(height: 16),

                  Text('Priority', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _Dropdown<String>(
                    value: _priority,
                    items: _priorities.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setState(() => _priority = v!),
                  ),
                  const SizedBox(height: 16),

                  Text('Subject', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _TextField(
                    ctrl: _subjectCtrl,
                    hint: 'Brief summary of your issue',
                    maxLength: 200,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Subject is required' : null,
                  ),
                  const SizedBox(height: 16),

                  Text('Description', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _TextField(
                    ctrl: _descriptionCtrl,
                    hint: 'Describe your issue in detail. Include any relevant reference numbers, dates, or amounts.',
                    maxLines: 6,
                    maxLength: 2000,
                    validator: (v) {
                      final text = (v ?? '').trim();
                      if (text.isEmpty) return 'Description is required';
                      if (text.length < 10) return 'Please provide a bit more detail';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  SizedBox(width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emeraldDeep,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(UniconsLine.message, size: 18),
                              const SizedBox(width: 8),
                              Text('Submit Ticket', style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16)),
                            ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const _Dropdown({required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value, isExpanded: true,
          dropdownColor: c.card,
          style: TextStyle(color: c.textPrimary, fontSize: 14),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController? ctrl;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;
  const _TextField({
    this.ctrl, required this.hint, this.maxLines = 1, this.maxLength,
    this.validator,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      maxLength: maxLength,
      style: TextStyle(color: c.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textHint),
        filled: true, fillColor: c.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: AppColors.emeraldDeep, width: 1.5)),
      ),
    );
  }
}

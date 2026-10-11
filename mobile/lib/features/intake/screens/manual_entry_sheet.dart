import 'package:flutter/material.dart';

import '../../../shared/design_system/app_colors.dart';
import '../../../shared/design_system/widgets/primary_button.dart';
import '../data/parsed_address.dart';

/// Bottom-sheet form for manual address entry.
///
/// Returns a [ManualAddress] on confirm, or null on cancel.
class ManualEntrySheet extends StatefulWidget {
  const ManualEntrySheet({super.key, this.initialOrderId});

  final String? initialOrderId;

  @override
  State<ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<ManualEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _orderId = TextEditingController();
  final _street = TextEditingController();
  final _area = TextEditingController();
  final _city = TextEditingController();
  final _pincode = TextEditingController();

  @override
  void initState() {
    super.initState();
    _orderId.text = widget.initialOrderId ?? '';
  }

  @override
  void dispose() {
    _orderId.dispose();
    _street.dispose();
    _area.dispose();
    _city.dispose();
    _pincode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Manual entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: c.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _field(_orderId, 'Order ID (optional)'),
            const SizedBox(height: 12),
            _field(_street, 'Street / house number'),
            const SizedBox(height: 12),
            _field(_area, 'Area / colony / layout'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(_city, 'City')),
                const SizedBox(width: 12),
                Expanded(child: _field(_pincode, 'Pincode')),
              ],
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Save parcel', icon: Icons.check_rounded, onPressed: _save),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint) {
    return TextFormField(
      controller: ctrl,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.appColors.textMuted),
        filled: true,
        fillColor: context.appColors.surfaceHigh,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  void _save() {
    final s = _street.text.trim();
    final a = _area.text.trim();
    final ci = _city.text.trim();
    final p = _pincode.text.trim();
    if (s.isEmpty && a.isEmpty && ci.isEmpty && p.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter at least one address field')));
      return;
    }
    final o = _orderId.text.trim();
    Navigator.pop(
      context,
      ManualAddress(
        orderId: o.isEmpty ? null : o,
        street: s.isEmpty ? null : s,
        area: a.isEmpty ? null : a,
        city: ci.isEmpty ? null : ci,
        pincode: p.isEmpty ? null : p,
      ),
    );
  }
}

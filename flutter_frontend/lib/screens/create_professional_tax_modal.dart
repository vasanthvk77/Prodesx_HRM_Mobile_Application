import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/professional_tax.dart';
import '../providers/professional_tax_provider.dart';
import '../widgets/custom_snackbar.dart';

class CreateProfessionalTaxModal extends ConsumerStatefulWidget {
  final ProfessionalTax? editData;
  const CreateProfessionalTaxModal({super.key, this.editData});

  @override
  ConsumerState<CreateProfessionalTaxModal> createState() =>
      _CreateProfessionalTaxModalState();
}

class _CreateProfessionalTaxModalState
    extends ConsumerState<CreateProfessionalTaxModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editData != null) {
      _nameCtrl.text = widget.editData!.taxName;
      _fromCtrl.text = widget.editData!.fromAmount.toString();
      _toCtrl.text = widget.editData!.toAmount.toString();
      _amountCtrl.text = widget.editData!.taxAmount.toString();
      _isActive = widget.editData!.isActive;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final state = ref.read(professionalTaxProvider);
    final payload = {
      if (widget.editData != null) 'ptId': widget.editData!.ptId,
      'taxName': _nameCtrl.text,
      'fromAmount': double.parse(_fromCtrl.text),
      'toAmount': double.parse(_toCtrl.text),
      'taxAmount': double.parse(_amountCtrl.text),
      'isActive': _isActive,
      'organizationId': state.selectedOrgId,
    };

    final success = widget.editData != null
        ? await ref.read(professionalTaxProvider.notifier).updateSlab(payload)
        : await ref.read(professionalTaxProvider.notifier).saveSlab(payload);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context);
        CustomSnackbar.show(
          context: context,
          message:
              widget.editData != null ? 'Tax slab updated' : 'Tax slab created',
        );
      } else {
        CustomSnackbar.show(
          context: context,
          message: 'Failed to save tax slab',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e293b) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.5 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFF3182ce),
                    size: 26,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.editData != null
                              ? 'Modify Slab Settings'
                              : 'Create New PT Slab',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0f172a),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Regulatory Professional Tax Compliance',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500), // Darker slate
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Body ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TAX INFORMATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900, // Extra bold
                        color: isDark ? Colors.white60 : const Color(0xFF475569), // Darker slate
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildLabel('Tax Slab Name / State Rule *', context),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: _inputDecoration('e.g. 1-20000'),
                      style: const TextStyle(fontSize: 14),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Salary From (₹) *', context),
                              TextFormField(
                                controller: _fromCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration('0'),
                                style: const TextStyle(fontSize: 14),
                                validator:
                                    (v) => v?.isEmpty ?? true ? 'Required' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Salary To (₹) *', context),
                              TextFormField(
                                controller: _toCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration('0'),
                                style: const TextStyle(fontSize: 14),
                                validator:
                                    (v) => v?.isEmpty ?? true ? 'Required' : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildLabel('Tax Amount to Deduct (₹) *', context),
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('0'),
                      style: const TextStyle(fontSize: 14),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Set as Active',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1e293b),
                          ),
                        ),
                        Transform.scale(
                          scale: 0.8, // FIX: Make it compact like Android
                          child: Switch(
                            value: _isActive,
                            onChanged: (v) => setState(() => _isActive = v),
                            activeColor: const Color(0xFF3182ce),
                            activeTrackColor: const Color(0xFF3182ce).withOpacity(0.4),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Compliance Note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3b82f6).withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF3b82f6).withOpacity(0.15),
                        ),
                      ),
                      child: Text(
                        '⚖️ Compliance Note: Professional tax slabs vary by state. Ensure the basic range (From-To) doesn\'t overlap with existing slabs to maintain accurate payroll calculations.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF1E293B), // Darker slate 800
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // ── Footer ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF334155), // Darker slate 700
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3182ce),
                      foregroundColor: Colors.white, // FIX: Force white text
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.editData != null
                                ? 'Update Slab'
                                : 'Save Config',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF475569), // Darker slate 600
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
      ),
      hintStyle: TextStyle(
        color: isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B), // Darker hint
        fontSize: 14,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/benefit_models.dart';
import '../models/employee.dart';
import '../providers/benefits_provider.dart';
import '../widgets/custom_snackbar.dart';

class BenefitAssignmentFormScreen extends ConsumerStatefulWidget {
  final BenefitCategory category;
  final int? organizationId;
  final BenefitAssignment? editData;
  final List<BenefitType> benefitTypes;
  final List<Employee> employees;
  final int? preselectedEmployeeId;

  const BenefitAssignmentFormScreen({
    super.key,
    required this.category,
    this.organizationId,
    this.editData,
    required this.benefitTypes,
    required this.employees,
    this.preselectedEmployeeId,
  });

  @override
  ConsumerState<BenefitAssignmentFormScreen> createState() => _BenefitAssignmentFormScreenState();
}

class _BenefitAssignmentFormScreenState extends ConsumerState<BenefitAssignmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late int? _selectedEmployeeId;
  late int? _selectedBenefitId;
  late bool _isFixed;
  late TextEditingController _amountController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedEmployeeId = widget.editData?.employeeId ?? widget.preselectedEmployeeId;
    _selectedBenefitId = widget.editData?.benefitId;
    _isFixed = widget.editData?.calType ?? true;
    _amountController = TextEditingController(text: widget.editData?.amount.toString() ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null || _selectedBenefitId == null) {
      CustomSnackbar.show(context: context, message: 'Please select staff and type', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final provider = widget.category == BenefitCategory.allowance ? allowancesProvider : deductionsProvider;
      final amount = double.parse(_amountController.text);
      
      if (widget.editData == null) {
        await ref.read(provider.notifier).saveAssignment(
          benefitId: _selectedBenefitId!,
          employeeId: _selectedEmployeeId!,
          calType: _isFixed,
          amount: amount,
        );
      } else {
        final updated = BenefitAssignment(
          id: widget.editData!.id,
          benefitId: _selectedBenefitId!,
          employeeId: _selectedEmployeeId!,
          calType: _isFixed,
          amount: amount,
          createdBy: widget.editData!.createdBy,
          category: widget.category,
        );
        await ref.read(provider.notifier).updateAssignment(updated);
      }
      
      if (mounted) {
        CustomSnackbar.show(context: context, message: 'Saved successfully');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context: context, message: 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isIOS = theme.platform == TargetPlatform.iOS;
    
    final navyBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.grey.shade100;
    final primaryColor = Colors.blue.shade600; // Standard Blue used across the app
    final title = widget.editData == null ? 'Assign Staff' : 'Edit Staff Assignment';
    final categoryText = widget.category == BenefitCategory.allowance ? 'Allowance' : 'Deduction';

    if (isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: navyBg,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: navyBg.withOpacity(0.8),
          middle: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
          trailing: _isSaving 
            ? const CupertinoActivityIndicator() 
            : CupertinoButton(
                padding: EdgeInsets.zero, 
                onPressed: _save, 
                child: const Text('Save')
              ),
        ),
        child: SafeArea(
          child: Material(
            color: Colors.transparent, 
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800), // Prevent stretching
                child: _buildFormContent(cardColor, isDark, theme, primaryColor, categoryText),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: navyBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        centerTitle: true, // Standard center title for full-screen forms
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2)))
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800), // Prevent stretching
          child: _buildFormContent(cardColor, isDark, theme, primaryColor, categoryText),
        ),
      ),
    );
  }

  Widget _buildFormContent(Color cardColor, bool isDark, ThemeData theme, Color primaryColor, String categoryText) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Standard Info Card for Context
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Row(
                children: [
                   Icon(
                    widget.category == BenefitCategory.allowance ? Icons.add_circle_outline : Icons.remove_circle_outline, 
                    color: primaryColor, 
                    size: 20
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assignment Category',
                        style: TextStyle(
                          color: isDark ? Colors.grey : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        categoryText,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Staff Picker
            _buildLabel('STAFF MEMBER', isDark),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedEmployeeId,
              isExpanded: true,
              dropdownColor: cardColor,
              decoration: InputDecoration(
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.person_search_outlined),
              ),
              hint: const Text('Search for staff...'),
              items: widget.employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w500)))).toList(),
              onChanged: widget.editData != null ? null : (id) => setState(() => _selectedEmployeeId = id),
              validator: (val) => val == null ? 'Required' : null,
            ),
            const SizedBox(height: 24),

            // Benefit Type Picker
            _buildLabel('$categoryText TYPE', isDark),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedBenefitId,
              isExpanded: true,
              dropdownColor: cardColor,
              decoration: InputDecoration(
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              ),
              hint: Text('Select $categoryText type'),
              items: widget.benefitTypes.map((b) => DropdownMenuItem(value: b.id, child: Text(b.fullName))).toList(),
              onChanged: (id) => setState(() => _selectedBenefitId = id),
              validator: (val) => val == null ? 'Required' : null,
            ),
            const SizedBox(height: 24),

            // Calculation Type
            _buildLabel('CALCULATION SETTINGS', isDark),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildToggleButton(
                      'Fixed Amount', 
                      Icons.money, 
                      _isFixed == true, 
                      () => setState(() => _isFixed = true)
                    ),
                  ),
                  Expanded(
                    child: _buildToggleButton(
                      'Percentage (%)', 
                      Icons.percent, 
                      _isFixed == false, 
                      () => setState(() => _isFixed = false)
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _amountController,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: _isFixed ? 'Amount (₹) *' : 'Percentage (%) *',
                prefixText: _isFixed ? '₹ ' : null,
                suffixText: _isFixed ? null : ' %',
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              keyboardType: TextInputType.number,
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            ),
            
            const SizedBox(height: 48),

            // Footer Actions
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _isSaving ? 'SAVING...' : 'SAVE ASSIGNMENT', 
                  style: const TextStyle(fontWeight: FontWeight.bold)
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                ),
                child: Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        color: isDark ? Colors.white70 : Colors.black87,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildToggleButton(String label, IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? Colors.white : Colors.grey),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? Colors.white : Colors.grey)),
          ],
        ),
      ),
    );
  }
}

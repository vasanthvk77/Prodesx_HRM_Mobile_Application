import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/employee.dart';
import '../repositories/employee_repository.dart';
import '../widgets/custom_snackbar.dart';

class ManageFieldsScreen extends ConsumerStatefulWidget {
  final int? organizationId;

  const ManageFieldsScreen({super.key, this.organizationId});

  @override
  ConsumerState<ManageFieldsScreen> createState() => _ManageFieldsScreenState();
}

class _ManageFieldsScreenState extends ConsumerState<ManageFieldsScreen> {
  List<EmployeeField> _allFields = [];
  bool _isLoading = true;
  bool _isCreatingField = false;

  // Form Controllers for New Field
  final _formKey = GlobalKey<FormState>();
  final _keyController = TextEditingController();
  final _labelController = TextEditingController();
  String _selectedSection = 'General';
  String _selectedType = 'text';
  final _sectionOrderController = TextEditingController(text: '99');
  final _fieldOrderController = TextEditingController(text: '99');
  final _widthController = TextEditingController(text: '6');

  final List<String> _sections = ['General', 'Personal Information', 'Work Experience', 'Education', 'Other'];
  final List<String> _types = ['text', 'select', 'date', 'number', 'textarea'];

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _labelController.dispose();
    _sectionOrderController.dispose();
    _fieldOrderController.dispose();
    _widthController.dispose();
    super.dispose();
  }

  Future<void> _loadFields() async {
    setState(() => _isLoading = true);
    try {
      final empRepo = ref.read(employeeRepositoryProvider);
      final fields = await empRepo.getFormFields(widget.organizationId);
      setState(() {
        _allFields = fields;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context: context, message: 'Error loading fields: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createField() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreatingField = true);
    try {
      final empRepo = ref.read(employeeRepositoryProvider);
      await empRepo.createMasterField({
        'fieldKey': _keyController.text.trim(),
        'displayLabel': _labelController.text.trim(),
        'sectionName': _selectedSection,
        'componentType': _selectedType,
        'sectionOrder': int.tryParse(_sectionOrderController.text) ?? 99,
        'fieldOrder': int.tryParse(_fieldOrderController.text) ?? 99,
        'gridSize': int.tryParse(_widthController.text) ?? 6,
        'isVisible': true,
        'isMandatory': false,
      });

      CustomSnackbar.show(context: context, message: 'Field created successfully');
      
      // Reset form
      _keyController.clear();
      _labelController.clear();
      _sectionOrderController.text = '99';
      _fieldOrderController.text = '99';
      _widthController.text = '6';
      
      _loadFields();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context: context, message: 'Error creating field: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isCreatingField = false);
    }
  }

  Future<void> _deleteField(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Field', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this master field? This cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final empRepo = ref.read(employeeRepositoryProvider);
      await empRepo.deleteMasterField(id);
      CustomSnackbar.show(context: context, message: 'Field deleted successfully');
      _loadFields();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context: context, message: 'Error deleting field: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const navyBg = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: navyBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.storage_rounded, color: Colors.redAccent, size: 20),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Manage Master Fields', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('SuperAdmin — changes apply to all organizations', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.blue))
        : LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 1000;
              
              return SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
                  child: isDesktop 
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sidebar
                          SizedBox(width: 320, child: _buildSidebar()),
                          const SizedBox(width: 24),
                          // Main content
                          Expanded(child: _buildMainContent()),
                        ],
                      )
                    : Column(
                        children: [
                          _buildSidebar(),
                          const SizedBox(height: 24),
                          _buildMainContent(isMobile: true),
                        ],
                      ),
                ),
              );
            },
          ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white12,
                foregroundColor: Colors.white70,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    const fieldDecoration = InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: Color(0xFF0F172A),
      border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white10), borderRadius: BorderRadius.all(Radius.circular(8))),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white10), borderRadius: BorderRadius.all(Radius.circular(8))),
      labelStyle: TextStyle(color: Colors.grey, fontSize: 13),
      hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.add_circle_outline, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Text('Add New Field', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _keyController,
              decoration: fieldDecoration.copyWith(hintText: 'Key (camelCase)'),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _labelController,
              decoration: fieldDecoration.copyWith(hintText: 'Display Label'),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _buildDropdown('Section', _selectedSection, _sections, (v) => setState(() => _selectedSection = v!)),
            const SizedBox(height: 12),
            _buildDropdown('Component Type', _selectedType, _types, (v) => setState(() => _selectedType = v!)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildSmallField('Section Order', _sectionOrderController)),
                const SizedBox(width: 8),
                Expanded(child: _buildSmallField('Field Order', _fieldOrderController)),
                const SizedBox(width: 8),
                Expanded(child: _buildSmallField('Width', _widthController)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isCreatingField ? null : _createField,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isCreatingField 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('+ Create Field', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallField(String label, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9)),
          const SizedBox(height: 2),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent({bool isMobile = false}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All Master Fields (${_allFields.length})',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          if (isMobile) 
            _buildMobileFieldsList()
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 600),
                child: _buildDesktopTable(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.5),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1),
        5: FixedColumnWidth(60),
      },
      children: [
        // Header
        TableRow(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
          children: [
            _buildCell('FIELD KEY', isHeader: true),
            _buildCell('LABEL', isHeader: true),
            _buildCell('SECTION', isHeader: true),
            _buildCell('TYPE', isHeader: true),
            _buildCell('CORE', isHeader: true),
            _buildCell('ACTION', isHeader: true),
          ],
        ),
        // Data Rows
        ..._allFields.map((field) {
          final isCore = field.id < 1000;
          return TableRow(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05)))),
            children: [
              _buildCell(field.fieldKey, color: Colors.blue.shade400),
              _buildCell(field.displayLabel, fontWeight: FontWeight.w500),
              _buildCell(field.sectionName, color: Colors.grey.shade400, fontSize: 12),
              TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: _buildBadge(field.componentType, const Color(0xFF334155))),
                ),
              ),
              TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: _buildBadge(isCore ? 'Core' : 'Custom', isCore ? const Color(0xFF1E3A8A) : const Color(0xFF3F3F46))),
                ),
              ),
              TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: isCore ? null : () => _deleteField(field.id),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildMobileFieldsList() {
    return Column(
      children: _allFields.map((field) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(field.displayLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(field.fieldKey, style: TextStyle(color: Colors.blue.shade400, fontSize: 12)),
                  ],
                ),
              ),
              _buildBadge(field.componentType, const Color(0xFF334155)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: field.id < 1000 ? null : () => _deleteField(field.id),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCell(String text, {bool isHeader = false, Color? color, FontWeight? fontWeight, double fontSize = 13}) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Text(
          text,
          style: TextStyle(
            color: isHeader ? Colors.grey.shade500 : (color ?? Colors.white),
            fontWeight: isHeader ? FontWeight.bold : (fontWeight ?? FontWeight.normal),
            fontSize: isHeader ? 11 : fontSize,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/department.dart';
import '../repositories/department_repository.dart';

class DepartmentFormScreen extends StatefulWidget {
  final int organizationId;
  final String organizationName;
  final Department? editData;
  final List<Department>? allDepartments;

  const DepartmentFormScreen({
    super.key,
    required this.organizationId,
    required this.organizationName,
    this.editData,
    this.allDepartments,
  });

  @override
  State<DepartmentFormScreen> createState() => _DepartmentFormScreenState();
}

class _DepartmentFormScreenState extends State<DepartmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final DepartmentRepository _repository = DepartmentRepository();
  
  late TextEditingController _nameController;
  int? _parentDepartmentId;
  bool _isLoading = false;
  bool _isSaving = false;
  List<Department> _parentOptions = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editData?.departmentName ?? '');
    _parentDepartmentId = widget.editData?.parentDepartmentId;
    _loadParentOptions();
  }

  Future<void> _loadParentOptions() async {
    if (widget.allDepartments != null) {
      _prepareParentOptions(widget.allDepartments!);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final all = await _repository.getDepartments(widget.organizationId);
      _prepareParentOptions(all);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load parents: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _prepareParentOptions(List<Department> all) {
    if (widget.editData == null) {
      _parentOptions = all;
    } else {
      final descendants = <int>{};
      void findDescendants(int parentId) {
        for (var d in all) {
          if (d.parentDepartmentId == parentId) {
            descendants.add(d.id);
            findDescendants(d.id);
          }
        }
      }
      findDescendants(widget.editData!.id);
      _parentOptions = all.where((d) => 
        d.id != widget.editData!.id && !descendants.contains(d.id)
      ).toList();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final data = {
        'organizationId': widget.organizationId,
        'organizationName': widget.organizationName,
        'departmentName': _nameController.text.trim(),
        'parentDepartmentId': _parentDepartmentId,
      };

      if (widget.editData != null) {
        await _repository.updateDepartment(widget.editData!.id, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Department updated successfully'), backgroundColor: Colors.green),
          );
        }
      } else {
        await _repository.createDepartment(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Department created successfully'), backgroundColor: Colors.green),
          );
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const navyBg = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: navyBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.editData != null ? 'Edit Department' : 'Add Department', style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Organization', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(widget.organizationName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Department Name *', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. Sales Department',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Department name is required' : null,
              ),
              const SizedBox(height: 20),
              const Text('Parent Department', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _parentDepartmentId,
                    dropdownColor: const Color(0xFF1E293B),
                    isExpanded: true,
                    hint: const Text('-- None --', style: TextStyle(color: Colors.white24, fontSize: 14)),
                    style: const TextStyle(color: Colors.white),
                    items: _isLoading 
                      ? [const DropdownMenuItem<int>(value: null, child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))]
                      : [
                          const DropdownMenuItem<int>(value: null, child: Text('-- None --')),
                          ..._parentOptions.map((o) => DropdownMenuItem(value: o.id, child: Text(o.departmentName))),
                        ],
                    onChanged: (val) => setState(() => _parentDepartmentId = val),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Department', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

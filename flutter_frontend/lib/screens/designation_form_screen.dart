import 'package:flutter/material.dart';
import '../models/designation.dart';
import '../repositories/designation_repository.dart';
import '../widgets/custom_snackbar.dart';

class DesignationFormScreen extends StatefulWidget {
  final int organizationId;
  final String organizationName;
  final Designation? editData;
  final List<Designation>? allDesignations;

  const DesignationFormScreen({
    super.key,
    required this.organizationId,
    required this.organizationName,
    this.editData,
    this.allDesignations,
  });

  @override
  State<DesignationFormScreen> createState() => _DesignationFormScreenState();
}

class _DesignationFormScreenState extends State<DesignationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = DesignationRepository();
  
  late TextEditingController _nameController;
  int? _parentDesignationId;
  bool _isLoading = false;
  bool _isSaving = false;
  List<Designation> _parentOptions = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editData?.designationName ?? '');
    _parentDesignationId = widget.editData?.parentDesignationId;
    _loadParentOptions();
  }

  Future<void> _loadParentOptions() async {
    if (widget.allDesignations != null) {
      _prepareParentOptions(widget.allDesignations!);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final all = await _repository.getDesignations(widget.organizationId);
      _prepareParentOptions(all);
    } catch (e) {
        CustomSnackbar.show(
          context: context,
          message: 'Failed to load parents: $e',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _prepareParentOptions(List<Designation> all) {
    if (widget.editData == null) {
      _parentOptions = all;
    } else {
      // Logic to prevent cyclic parent-child selection
      final descendants = <int>{};
      void findDescendants(int parentId) {
        for (var d in all) {
          if (d.parentDesignationId == parentId) {
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
        'designationName': _nameController.text.trim(),
        'parentDesignationId': _parentDesignationId,
      };

      if (widget.editData != null) {
        await _repository.updateDesignation(widget.editData!.id, data);
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Designation updated successfully',
          );
        }
      } else {
        await _repository.createDesignation(data);
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Designation created successfully',
          );
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
        CustomSnackbar.show(
          context: context,
          message: 'Save failed: $e',
          isError: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.editData != null ? 'Edit Designation' : 'Add Designation'),
        leading: IconButton(
          icon: const Icon(Icons.close),
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
              // Info Card
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

              // Name Field
              const Text('Designation Name *', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. Senior Software Engineer',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (val) => (val == null || val.isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),

              // Parent Dropdown
              const Text('Parent Designation', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _parentDesignationId,
                    dropdownColor: const Color(0xFF1E293B),
                    isExpanded: true,
                    hint: const Text('-- None --', style: TextStyle(color: Colors.white24, fontSize: 14)),
                    style: const TextStyle(color: Colors.white),
                    items: _isLoading 
                      ? [const DropdownMenuItem<int>(value: null, child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))]
                      : [
                          const DropdownMenuItem<int>(value: null, child: Text('-- None --')),
                          ..._parentOptions.map((o) => DropdownMenuItem(value: o.id, child: Text(o.designationName))),
                        ],
                    onChanged: (val) => setState(() => _parentDesignationId = val),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Action Buttons
              Row(
                children: [
                   Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Designation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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

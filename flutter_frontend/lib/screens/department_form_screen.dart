import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/department.dart';
import '../repositories/department_repository.dart';
import '../widgets/custom_snackbar.dart';

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
    _nameController = TextEditingController(
      text: widget.editData?.departmentName ?? '',
    );
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
      CustomSnackbar.show(
        context: context,
        message: 'Failed to load parents: $e',
        isError: true,
      );
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
      _parentOptions = all
          .where(
            (d) => d.id != widget.editData!.id && !descendants.contains(d.id),
          )
          .toList();
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
          CustomSnackbar.show(
            context: context,
            message: 'Department updated successfully',
          );
        }
      } else {
        await _repository.createDepartment(data);
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Department created successfully',
          );
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      CustomSnackbar.show(
        context: context,
        message: 'Save failed: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIOS = theme.platform == TargetPlatform.iOS;
    final isDark = theme.brightness == Brightness.dark;

    // Consistent with Private Dashboard/Main Shell
    final navyBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.grey.shade100;

    if (isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: navyBg,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: navyBg.withOpacity(0.8),
          middle: Text(
            widget.editData != null ? 'Edit Department' : 'Add Department',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
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
                  child: const Text('Save'),
                ),
        ),
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOrgInfoCard(cardColor, isDark),
                    const SizedBox(height: 24),
                    _buildLabel('Department Name *', isDark),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: _nameController,
                      placeholder: 'e.g. Sales Department',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildLabel('Parent Department', isDark),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _showParentPicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _parentDepartmentId == null
                                  ? '-- None --'
                                  : _parentOptions
                                        .firstWhere(
                                          (o) => o.id == _parentDepartmentId,
                                        )
                                        .departmentName,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Icon(
                              CupertinoIcons.chevron_down,
                              size: 16,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
        title: Text(
          widget.editData != null ? 'Edit Department' : 'Add Department',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
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
              _buildOrgInfoCard(cardColor, isDark),
              const SizedBox(height: 24),
              _buildLabel('Department Name *', isDark),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: 'e.g. Sales Department',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                validator: (val) => val == null || val.isEmpty
                    ? 'Department name is required'
                    : null,
              ),
              const SizedBox(height: 20),
              _buildLabel('Parent Department', isDark),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _parentDepartmentId,
                    dropdownColor: cardColor,
                    isExpanded: true,
                    hint: Text(
                      '-- None --',
                      style: TextStyle(
                        color: isDark ? Colors.white24 : Colors.black26,
                        fontSize: 14,
                      ),
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    items: _isLoading
                        ? [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ]
                        : [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('-- None --'),
                            ),
                            ..._parentOptions.map(
                              (o) => DropdownMenuItem(
                                value: o.id,
                                child: Text(o.departmentName),
                              ),
                            ),
                          ],
                    onChanged: (val) =>
                        setState(() => _parentDepartmentId = val),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
                      : const Text(
                          'Save Department',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        color: isDark ? Colors.white70 : Colors.black87,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildOrgInfoCard(Color cardColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        children: [
          const Icon(Icons.business, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organization',
                style: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              Text(
                widget.organizationName,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showParentPicker(BuildContext context) {
    int selectedIndex = 0;
    if (_parentDepartmentId != null) {
      selectedIndex =
          _parentOptions.indexWhere((o) => o.id == _parentDepartmentId) + 1;
    }

    final options = [
      Department(id: -1, organizationId: 0, departmentName: '-- None --'),
      ..._parentOptions,
    ];

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: CupertinoColors.separator,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Done'),
                    onPressed: () {
                      setState(() {
                        _parentDepartmentId = options[selectedIndex].id == -1
                            ? null
                            : options[selectedIndex].id;
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                scrollController: FixedExtentScrollController(
                  initialItem: selectedIndex,
                ),
                onSelectedItemChanged: (index) => selectedIndex = index,
                children: options
                    .map((o) => Center(child: Text(o.departmentName)))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
    _nameController = TextEditingController(
      text: widget.editData?.designationName ?? '',
    );
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
    final theme = Theme.of(context);
    final isIOS = theme.platform == TargetPlatform.iOS;
    final isDark = theme.brightness == Brightness.dark;

    final navyBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.grey.shade100;

    if (isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: navyBg,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: navyBg.withOpacity(0.8),
          middle: Text(
            widget.editData != null ? 'Edit Designation' : 'Add Designation',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.multiply),
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
                    _buildLabel('Designation Name *', isDark),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: _nameController,
                      placeholder: 'e.g. Senior Software Engineer',
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
                    _buildLabel('Parent Designation', isDark),
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
                              _parentDesignationId == null
                                  ? '-- None --'
                                  : _parentOptions
                                        .firstWhere(
                                          (o) => o.id == _parentDesignationId,
                                        )
                                        .designationName,
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
          widget.editData != null ? 'Edit Designation' : 'Add Designation',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
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
              _buildLabel('Designation Name *', isDark),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: 'e.g. Senior Software Engineer',
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
                validator: (val) =>
                    (val == null || val.isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),
              _buildLabel('Parent Designation', isDark),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _parentDesignationId,
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
                                child: Text(o.designationName),
                              ),
                            ),
                          ],
                    onChanged: (val) =>
                        setState(() => _parentDesignationId = val),
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
                          'Save Designation',
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
    if (_parentDesignationId != null) {
      selectedIndex =
          _parentOptions.indexWhere((o) => o.id == _parentDesignationId) + 1;
    }

    final options = [
      Designation(id: -1, organizationId: 0, designationName: '-- None --'),
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
                        _parentDesignationId = options[selectedIndex].id == -1
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
                    .map((o) => Center(child: Text(o.designationName)))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

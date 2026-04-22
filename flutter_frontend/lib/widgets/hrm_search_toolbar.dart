import 'package:flutter/material.dart';
import 'org_dropdown.dart';

class HRMSearchToolbar extends StatelessWidget {
  final String? selectedOrgId;
  final List<OrgDropdownItem> orgItems;
  final Function(String?) onOrgChanged;
  final Function(String) onSearchChanged;
  final String hintText;
  final bool isOrgLoading;
  final List<Widget>? actions;

  const HRMSearchToolbar({
    super.key,
    required this.selectedOrgId,
    required this.orgItems,
    required this.onOrgChanged,
    required this.onSearchChanged,
    this.hintText = 'Search...',
    this.isOrgLoading = false,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        final orgSection = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (orgItems.isNotEmpty) ...[
              Text(
                'Organization',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 8),
              OrgDropdown(
                value: selectedOrgId,
                items: orgItems,
                onChanged: onOrgChanged,
                isLoading: isOrgLoading,
                showLabel: false,
                isCompact: true,
              ),
            ],
          ],
        );

        final searchSection = Container(
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TextField(
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: isDark ? Colors.white.withOpacity(0.4) : const Color(0xFF94A3B8),
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: isDark ? Colors.white.withOpacity(0.3) : Colors.grey.shade400,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
        );

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: isMobile 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  orgSection,
                  const SizedBox(height: 10),
                  searchSection,
                  if (actions != null && actions!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: actions!,
                    ),
                  ],
                ],
              )
            : Row(
                children: [
                  orgSection,
                  const SizedBox(width: 12),
                  Expanded(child: searchSection),
                  if (actions != null && actions!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ...actions!,
                  ],
                ],
              ),
        );
      },
    );
  }
}

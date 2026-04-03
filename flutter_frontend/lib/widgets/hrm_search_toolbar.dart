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

    return Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
      width: 1,
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      // 🔹 ROW 1 → Organization Dropdown
      if (orgItems.isNotEmpty)
        OrgDropdown(
          value: selectedOrgId,
          items: orgItems,
          onChanged: onOrgChanged,
          isLoading: isOrgLoading,
          showLabel: true,
          isCompact: false,
        ),

      const SizedBox(height: 12),

      // 🔹 ROW 2 → Search + Actions
      Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade300,
                ),
              ),
              child: TextField(
                onChanged: onSearchChanged,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white.withOpacity(0.4) : Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // 🔹 Actions (icons/buttons)
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(width: 10),
            ...actions!,
          ],
        ],
      ),
    ],
  ),
);
  }
}

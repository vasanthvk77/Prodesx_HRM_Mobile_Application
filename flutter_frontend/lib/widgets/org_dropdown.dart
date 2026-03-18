import 'package:flutter/material.dart';
import '../core/api_config.dart';

class OrgDropdownItem {
  final String id;
  final String name;
  final String? logoUrl;

  OrgDropdownItem({required this.id, required this.name, this.logoUrl});
}

class OrgDropdown extends StatelessWidget {
  final String? value;
  final List<OrgDropdownItem> items;
  final Function(String?) onChanged;
  final bool isLoading;
  final bool showLabel; 
  final bool isCompact;

  const OrgDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isLoading = false,
    this.showLabel = false,
    this.isCompact = false,
  });

  Widget _buildOrgLogo(BuildContext context, String? url, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).dividerColor,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: ((url?.length ?? 0) > 0)
            ? Image.network(
                ApiConfig.getFullImageUrl(url),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.business, color: Theme.of(context).iconTheme.color, size: size * 0.6),
              )
            : Icon(Icons.business, color: Colors.white70, size: size * 0.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
        ),
        child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (items.isEmpty) return const SizedBox();

    final currentValue = items.any((e) => e.id == value) ? value : items.first.id;

    Widget dropdownContainer = Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isCompact ? Theme.of(context).scaffoldBackgroundColor : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCompact && value != null && value != '' 
            ? Theme.of(context).colorScheme.primary 
            : Theme.of(context).dividerColor
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          dropdownColor: Theme.of(context).brightness == Brightness.light ? Colors.white : Theme.of(context).cardTheme.color,
          icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).iconTheme.color?.withOpacity(0.5), size: 16),
          isDense: true,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
            fontSize: 12,
            fontWeight: isCompact ? FontWeight.normal : FontWeight.w600,
          ),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((org) {
            return DropdownMenuItem<String>(
              value: org.id,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (org.id != '') _buildOrgLogo(context, org.logoUrl, 18),
                  if (org.id != '') const SizedBox(width: 8),
                  Text(org.name, style: const TextStyle(fontSize: 12)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );

    if (showLabel && !isCompact) {
      return Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light ? Colors.white : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
          boxShadow: Theme.of(context).brightness == Brightness.light
              ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     Icon(Icons.business, color: Theme.of(context).iconTheme.color?.withOpacity(0.5), size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Organization',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            dropdownContainer,
          ],
        ),
      );
    } else if (showLabel && isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 2),
            child: Text(
              'Organisation',
              style: TextStyle(fontSize: 9, color: Colors.grey),
            ),
          ),
          dropdownContainer,
        ],
      );
    }

    return dropdownContainer;
  }
}

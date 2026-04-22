import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.business,
                  color: Theme.of(context).iconTheme.color,
                  size: size * 0.6,
                ),
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
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (items.isEmpty) return const SizedBox();

    final currentValue = items.any((e) => e.id == value)
        ? value
        : items.first.id;

    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    if (isIOS) {
      return GestureDetector(
        onTap: () => _showCupertinoOptions(context, items),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isCompact
                ? Theme.of(context).scaffoldBackgroundColor
                : Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (currentValue != '') ...[
                _buildOrgLogo(
                  context,
                  items.firstWhere((e) => e.id == currentValue).logoUrl,
                  18,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                items.firstWhere((e) => e.id == currentValue).name,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : const Color(0xFF1E293B), // Darker slate 800
                  fontSize: 12,
                  fontWeight: isCompact ? FontWeight.normal : FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_down,
                color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
                size: 12,
              ),
            ],
          ),
        ),
      );
    }

    Widget dropdownContainer = Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isCompact
            ? Theme.of(context).scaffoldBackgroundColor
            : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          dropdownColor: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : Theme.of(context).cardTheme.color,
          icon: Icon(
            Icons.arrow_drop_down,
            color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
            size: 16,
          ),
          isDense: true,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white 
                : const Color(0xFF1E293B), // Darker slate 800
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
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: Theme.of(context).brightness == Brightness.light
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
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
                    Icon(
                      Icons.business,
                      color: Theme.of(
                        context,
                      ).iconTheme.color?.withOpacity(0.5),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Organization',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.8)
                              : const Color(0xFF475569), // Darker slate 600
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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

  void _showCupertinoOptions(
    BuildContext context,
    List<OrgDropdownItem> items,
  ) {
    if (items.length <= 6) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: const Text('Select Organization'),
          actions: items
              .map(
                (org) => CupertinoActionSheetAction(
                  onPressed: () {
                    onChanged(org.id);
                    Navigator.pop(context);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (org.id != '') _buildOrgLogo(context, org.logoUrl, 20),
                      if (org.id != '') const SizedBox(width: 10),
                      Text(org.name, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              )
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      );
    } else {
      // Use CupertinoPicker for more than 6 items
      int selectedIndex = items.indexWhere((e) => e.id == value);
      if (selectedIndex == -1) selectedIndex = 0;

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
                decoration: BoxDecoration(
                  color: CupertinoColors.secondarySystemBackground.resolveFrom(
                    context,
                  ),
                  border: const Border(
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
                    const Text(
                      'Select Organization',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('Done'),
                      onPressed: () {
                        onChanged(items[selectedIndex].id);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 44,
                  scrollController: FixedExtentScrollController(
                    initialItem: selectedIndex,
                  ),
                  onSelectedItemChanged: (index) => selectedIndex = index,
                  children: items
                      .map(
                        (org) => Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (org.id != '')
                                  _buildOrgLogo(context, org.logoUrl, 20),
                                if (org.id != '') const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    org.name,
                                    style: const TextStyle(fontSize: 18),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}

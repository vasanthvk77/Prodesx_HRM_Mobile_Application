import 'package:flutter/material.dart';

class CustomPagination extends StatelessWidget {
  final int totalItems;
  final int pageSize;
  final int currentPage;
  final Function(int) onPageChanged;
  final Function(int) onPageSizeChanged;
  final List<int> pageSizeOptions;

  const CustomPagination({
    super.key,
    required this.totalItems,
    required this.pageSize,
    required this.currentPage,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.pageSizeOptions = const [10, 25, 50, 100],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final int totalPages = (totalItems / pageSize).ceil();
    final int startItem = (currentPage - 1) * pageSize + 1;
    final int endItem = (currentPage * pageSize) > totalItems ? totalItems : (currentPage * pageSize);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.5))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Page Size Selector
              Row(
                children: [
                  Text('Show ', style: theme.textTheme.bodySmall?.copyWith(fontSize: 13)),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: pageSize,
                        dropdownColor: theme.cardColor,
                        icon: Icon(Icons.arrow_drop_down, color: theme.iconTheme.color?.withOpacity(0.5), size: 18),
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                        onChanged: (val) {
                          if (val != null) onPageSizeChanged(val);
                        },
                        items: pageSizeOptions.map((size) {
                          return DropdownMenuItem<int>(
                            value: size,
                            child: Text('$size'),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Text(' entries', style: theme.textTheme.bodySmall?.copyWith(fontSize: 13)),
                ],
              ),
              
              // Mobile Page Info (Condensed)
              if (MediaQuery.of(context).size.width < 600)
                Text(
                  '$startItem-$endItem of $totalItems',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),

              // Desktop Pagination Controls
              if (MediaQuery.of(context).size.width >= 600)
                Row(
                  children: [
                    Text(
                      'Showing $startItem to $endItem of $totalItems entries',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                    ),
                    const SizedBox(width: 24),
                    _buildPageControls(totalPages, theme),
                  ],
                ),
            ],
          ),
          
          // Mobile Pagination Controls (Bottom Row)
          if (MediaQuery.of(context).size.width < 600)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildPageControls(totalPages, theme),
            ),
        ],
      ),
    );
  }

  Widget _buildPageControls(int totalPages, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PageButton(
          icon: Icons.chevron_left,
          onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
          theme: theme,
        ),
        const SizedBox(width: 4),
        ..._buildPageNumbers(totalPages, theme),
        const SizedBox(width: 4),
        _PageButton(
          icon: Icons.chevron_right,
          onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
          theme: theme,
        ),
      ],
    );
  }

  List<Widget> _buildPageNumbers(int totalPages, ThemeData theme) {
    List<Widget> widgets = [];
    
    // Dynamic page number logic (Show current, one before, one after, etc.)
    int startPage = currentPage - 2;
    int endPage = currentPage + 2;

    if (startPage < 1) {
      endPage += (1 - startPage);
      startPage = 1;
    }
    if (endPage > totalPages) {
      startPage -= (endPage - totalPages);
      endPage = totalPages;
    }
    if (startPage < 1) startPage = 1;

    for (int i = startPage; i <= endPage; i++) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _PageNumberButton(
            page: i,
            isActive: i == currentPage,
            onPressed: () => onPageChanged(i),
            theme: theme,
          ),
        ),
      );
    }
    return widgets;
  }
}

class _PageButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final ThemeData theme;

  const _PageButton({required this.icon, this.onPressed, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, color: onPressed != null ? theme.iconTheme.color : theme.iconTheme.color?.withOpacity(0.2), size: 18),
        ),
      ),
    );
  }
}

class _PageNumberButton extends StatelessWidget {
  final int page;
  final bool isActive;
  final VoidCallback onPressed;
  final ThemeData theme;

  const _PageNumberButton({required this.page, required this.isActive, required this.onPressed, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? theme.colorScheme.primary : Colors.transparent,
            border: isActive ? null : Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$page',
            style: TextStyle(
              color: isActive ? Colors.white : theme.textTheme.bodyMedium?.color,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

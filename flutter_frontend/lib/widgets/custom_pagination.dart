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
    final int totalPages = (totalItems / pageSize).ceil();
    final int startItem = (currentPage - 1) * pageSize + 1;
    final int endItem = (currentPage * pageSize) > totalItems ? totalItems : (currentPage * pageSize);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Match Navy background
        border: Border(top: BorderSide(color: Colors.white10)),
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
                  const Text('Show ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: pageSize,
                        dropdownColor: const Color(0xFF1E293B),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 18),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
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
                  const Text(' entries', style: TextStyle(color: Colors.white70, fontSize: 13)),
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
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(width: 24),
                    _buildPageControls(totalPages),
                  ],
                ),
            ],
          ),
          
          // Mobile Pagination Controls (Bottom Row)
          if (MediaQuery.of(context).size.width < 600)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildPageControls(totalPages),
            ),
        ],
      ),
    );
  }

  Widget _buildPageControls(int totalPages) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PageButton(
          icon: Icons.chevron_left,
          onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
        ),
        const SizedBox(width: 8),
        ..._buildPageNumbers(totalPages),
        const SizedBox(width: 8),
        _PageButton(
          icon: Icons.chevron_right,
          onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
        ),
      ],
    );
  }

  List<Widget> _buildPageNumbers(int totalPages) {
    List<Widget> widgets = [];
    
    // Dynamic page number logic (Show current, one before, one after, etc.)
    // For simplicity, showing up to 5 surrounding pages
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

  const _PageButton({required this.icon, this.onPressed});

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
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, color: onPressed != null ? Colors.white70 : Colors.white12, size: 18),
        ),
      ),
    );
  }
}

class _PageNumberButton extends StatelessWidget {
  final int page;
  final bool isActive;
  final VoidCallback onPressed;

  const _PageNumberButton({required this.page, required this.isActive, required this.onPressed});

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
            color: isActive ? Colors.blue : Colors.transparent,
            border: isActive ? null : Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$page',
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white70,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

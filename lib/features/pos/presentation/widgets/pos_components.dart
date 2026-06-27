import 'package:flutter/material.dart';

import '../../../../core/database/database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/pos_cart_item.dart';

class PosCategoryChip extends StatelessWidget {
  const PosCategoryChip({
    super.key,
    required this.name,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String name;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.primaryGradient : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? AppColors.primaryDark : borderColor,
            ),
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class PosProductCard extends StatelessWidget {
  const PosProductCard({
    super.key,
    required this.product,
    required this.isDark,
    required this.formattedPrice,
    required this.onTap,
    this.stockQuantity,
    this.lowStockLabel,
    this.outOfStockLabel,
  });

  final Product product;
  final bool isDark;
  final String formattedPrice;
  final VoidCallback onTap;
  final double? stockQuantity;
  final String? lowStockLabel;
  final String? outOfStockLabel;

  bool get _isOutOfStock => (stockQuantity ?? 0) <= 0;

  bool get _isLowStock {
    if (_isOutOfStock) return false;
    if (product.minStockLevel <= 0) return false;
    return (stockQuantity ?? 0) <= product.minStockLevel;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _isOutOfStock
        ? AppColors.error.withValues(alpha: 0.6)
        : _isLowStock
        ? AppColors.warning.withValues(alpha: 0.55)
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: _isOutOfStock || _isLowStock ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : AppColors.lightTextMuted).withValues(
                alpha: isDark ? 0.22 : 0.1,
              ),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isOutOfStock || _isLowStock)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (_isOutOfStock ? AppColors.error : AppColors.warning)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isOutOfStock
                        ? (outOfStockLabel ?? '—')
                        : (lowStockLabel ?? '—'),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color:
                          _isOutOfStock ? AppColors.error : AppColors.warning,
                    ),
                  ),
                ),
              ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: _isOutOfStock
                    ? null
                    : AppColors.primaryGradient,
                color: _isOutOfStock
                    ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                    : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _isOutOfStock
                    ? Icons.block_rounded
                    : Icons.inventory_2_outlined,
                color: _isOutOfStock
                    ? AppColors.error
                    : Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              product.nameAr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              formattedPrice,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PosCartItemCard extends StatelessWidget {
  const PosCartItemCard({
    super.key,
    required this.item,
    required this.isDark,
    required this.discountLabel,
    required this.formatCurrency,
    required this.onDecrement,
    required this.onIncrement,
    required this.onEditDiscount,
  });

  final PosCartItem item;
  final bool isDark;
  final String discountLabel;
  final String Function(double amount) formatCurrency;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onEditDiscount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
              .withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.nameAr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(item.unitPrice),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
                if (item.discount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$discountLabel: ${formatCurrency(item.discount)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: onDecrement,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(7),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.remove,
                          size: 14,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${item.quantity.toInt()}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: onIncrement,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(7),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.add,
                          size: 14,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: onEditDiscount,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.discount_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 92),
                    child: Text(
                      formatCurrency(item.total),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PosTotalRow extends StatelessWidget {
  const PosTotalRow({
    super.key,
    required this.label,
    required this.value,
    required this.isDark,
    this.color,
  });

  final String label;
  final String value;
  final bool isDark;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color:
                  color ??
                  (isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class PosSelectionOption extends StatelessWidget {
  const PosSelectionOption({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryDark
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: icon == null
            ? Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                ),
              )
            : Column(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

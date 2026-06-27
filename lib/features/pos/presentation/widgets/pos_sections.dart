import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/database/database.dart';
import '../../../../core/localization/l10n_ext.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/pos_cart_item.dart';
import 'pos_components.dart';

class PosProductsPanel extends StatelessWidget {
  const PosProductsPanel({
    super.key,
    required this.isDark,
    required this.barcodeController,
    required this.barcodeFocus,
    required this.onBarcodeSubmitted,
    required this.searchController,
    required this.searchFocus,
    required this.onSearchChanged,
    required this.selectedCategoryId,
    required this.categories,
    required this.onCategorySelected,
    required this.filteredProducts,
    required this.formatProductPrice,
    required this.onProductTap,
    this.topSellers = const [],
    this.stockByProductId = const {},
    this.lowStockLabel,
    this.outOfStockLabel,
  });

  final bool isDark;
  final TextEditingController barcodeController;
  final FocusNode barcodeFocus;
  final ValueChanged<String> onBarcodeSubmitted;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearchChanged;
  final int? selectedCategoryId;
  final List<Category> categories;
  final ValueChanged<int?> onCategorySelected;
  final List<Product> filteredProducts;
  final String Function(Product product) formatProductPrice;
  final ValueChanged<Product> onProductTap;
  final List<Product> topSellers;
  final Map<int, double> stockByProductId;
  final String? lowStockLabel;
  final String? outOfStockLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Expanded(
      flex: 6,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 200,
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.tab) {
                        onBarcodeSubmitted(barcodeController.text);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: barcodeController,
                      focusNode: barcodeFocus,
                      autofocus: true,
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.none,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: l10n.scanBarcode,
                        prefixIcon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 20,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: onBarcodeSubmitted,
                      onEditingComplete: () =>
                          onBarcodeSubmitted(barcodeController.text),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    focusNode: searchFocus,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: l10n.searchProductShortcut,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: onSearchChanged,
                  ),
                ),
              ],
            ),
          ),
          if (topSellers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.topSellersQuickPick,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: topSellers.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final product = topSellers[index];
                        return ActionChip(
                          label: Text(
                            product.nameAr,
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () => onProductTap(product),
                          backgroundColor:
                              AppColors.warning.withValues(alpha: 0.12),
                          side: BorderSide(
                            color: AppColors.warning.withValues(alpha: 0.35),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                PosCategoryChip(
                  name: l10n.all,
                  isSelected: selectedCategoryId == null,
                  isDark: isDark,
                  onTap: () => onCategorySelected(null),
                ),
                ...categories.map(
                  (category) => PosCategoryChip(
                    name: category.nameAr,
                    isSelected: selectedCategoryId == category.id,
                    isDark: isDark,
                    onTap: () => onCategorySelected(category.id),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredProducts.isEmpty
                ? Center(
                    child: Text(
                      l10n.noData,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          childAspectRatio: 0.9,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return PosProductCard(
                        product: product,
                        isDark: isDark,
                        formattedPrice: formatProductPrice(product),
                        stockQuantity: stockByProductId[product.id],
                        lowStockLabel: lowStockLabel,
                        outOfStockLabel: outOfStockLabel,
                        onTap: () => onProductTap(product),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class PosCartPanel extends StatelessWidget {
  const PosCartPanel({
    super.key,
    required this.isDark,
    required this.cart,
    required this.onClearCart,
    required this.selectedCustomerName,
    required this.onSelectCustomer,
    required this.onClearSelectedCustomer,
    required this.onDecreaseItem,
    required this.onIncreaseItem,
    required this.onEditItemDiscount,
    required this.formatCurrency,
    required this.grossSubtotal,
    required this.lineDiscountTotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.total,
    required this.currencies,
    required this.currencyCode,
    required this.onCurrencyChanged,
    required this.discountController,
    required this.onInvoiceDiscountChanged,
    required this.onClearInvoiceDiscount,
    required this.discountType,
    required this.onDiscountTypeChanged,
    required this.onHoldInvoice,
    required this.onRecallInvoice,
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
    this.onSplitPayment,
    required this.onCompleteSale,
    this.smartSuggestions = const [],
    this.onSmartSuggestionTap,
  });

  final bool isDark;
  final List<PosCartItem> cart;
  final List<Product> smartSuggestions;
  final ValueChanged<Product>? onSmartSuggestionTap;
  final VoidCallback onClearCart;
  final String? selectedCustomerName;
  final VoidCallback onSelectCustomer;
  final VoidCallback onClearSelectedCustomer;
  final ValueChanged<int> onDecreaseItem;
  final ValueChanged<int> onIncreaseItem;
  final ValueChanged<int> onEditItemDiscount;
  final String Function(double amount) formatCurrency;
  final double grossSubtotal;
  final double lineDiscountTotal;
  final double discountAmount;
  final double taxAmount;
  final double total;
  final List<Currency> currencies;
  final String currencyCode;
  final ValueChanged<String> onCurrencyChanged;
  final TextEditingController discountController;
  final ValueChanged<String> onInvoiceDiscountChanged;
  final VoidCallback onClearInvoiceDiscount;
  final String discountType;
  final ValueChanged<String> onDiscountTypeChanged;
  final VoidCallback? onHoldInvoice;
  final VoidCallback onRecallInvoice;
  final String paymentMethod;
  final ValueChanged<String> onPaymentMethodChanged;
  final VoidCallback? onSplitPayment;
  final VoidCallback? onCompleteSale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      width: 410,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          left: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              border: Border(
                bottom: BorderSide(
                  color: border,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shopping_cart_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.cart,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${cart.length} ${l10n.items}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
                if (cart.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onClearCart,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_sweep_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: InkWell(
              onTap: onSelectCustomer,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: selectedCustomerName != null
                          ? AppColors.primary
                          : (isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedCustomerName ?? l10n.selectCustomerOptional,
                        style: TextStyle(
                          fontSize: 13,
                          color: selectedCustomerName != null
                              ? (isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary)
                              : (isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted),
                        ),
                      ),
                    ),
                    if (selectedCustomerName != null)
                      InkWell(
                        onTap: onClearSelectedCustomer,
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (smartSuggestions.isNotEmpty && cart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.frequentlyBoughtTogether,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: smartSuggestions.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final product = smartSuggestions[index];
                        return ActionChip(
                          label: Text(
                            product.nameAr,
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: onSmartSuggestionTap == null
                              ? null
                              : () => onSmartSuggestionTap!(product),
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_shopping_cart_rounded,
                          size: 48,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.emptyCart,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.tapProductToAdd,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      return PosCartItemCard(
                        item: item,
                        isDark: isDark,
                        discountLabel: l10n.discount,
                        formatCurrency: formatCurrency,
                        onDecrement: () => onDecreaseItem(index),
                        onIncrement: () => onIncreaseItem(index),
                        onEditDiscount: () => onEditItemDiscount(index),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightBg,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: Column(
              children: [
                PosTotalRow(
                  label: l10n.subtotal,
                  value: formatCurrency(grossSubtotal),
                  isDark: isDark,
                ),
                if (lineDiscountTotal > 0)
                  PosTotalRow(
                    label: l10n.itemDiscountsLabel,
                    value: '- ${formatCurrency(lineDiscountTotal)}',
                    isDark: isDark,
                    color: AppColors.error,
                  ),
                if (discountAmount > 0)
                  PosTotalRow(
                    label: l10n.invoiceDiscountLabel,
                    value: '- ${formatCurrency(discountAmount)}',
                    isDark: isDark,
                    color: AppColors.error,
                  ),
                if (taxAmount > 0)
                  PosTotalRow(
                    label: l10n.tax,
                    value: formatCurrency(taxAmount),
                    isDark: isDark,
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.total,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      formatCurrency(total),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: border,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (currencies.isNotEmpty) ...[
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue:
                                    currencies.any(
                                      (currency) =>
                                          currency.code == currencyCode,
                                    )
                                    ? currencyCode
                                    : null,
                                decoration: InputDecoration(
                                  labelText: l10n.currency,
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                items: currencies
                                    .map(
                                      (currency) => DropdownMenuItem<String>(
                                        value: currency.code,
                                        child: Text(
                                          '${currency.code} - ${currency.symbol}',
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                selectedItemBuilder: (context) {
                                  return currencies
                                      .map(
                                        (currency) => Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            currency.code,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList();
                                },
                                onChanged: (value) {
                                  if (value != null) {
                                    onCurrencyChanged(value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: TextField(
                              controller: discountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                labelText: l10n.invoiceDiscountLabel,
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onChanged: onInvoiceDiscountChanged,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: l10n.clearDiscount,
                            onPressed: onClearInvoiceDiscount,
                            icon: const Icon(
                              Icons.layers_clear_rounded,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: PosSelectionOption(
                              label: l10n.fixedAmount,
                              isSelected: discountType == 'fixed',
                              isDark: isDark,
                              onTap: () => onDiscountTypeChanged('fixed'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PosSelectionOption(
                              label: l10n.percentage,
                              isSelected: discountType == 'percentage',
                              isDark: isDark,
                              onTap: () => onDiscountTypeChanged('percentage'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.currentCurrencyLabel(currencyCode),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onHoldInvoice,
                        icon: const Icon(
                          Icons.pause_circle_outline_rounded,
                          size: 18,
                        ),
                        label: Text(l10n.holdInvoice),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onRecallInvoice,
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: Text(l10n.recallInvoice),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: PosSelectionOption(
                        label: l10n.cash,
                        icon: Icons.payments_rounded,
                        isSelected: paymentMethod == 'cash',
                        isDark: isDark,
                        onTap: () => onPaymentMethodChanged('cash'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PosSelectionOption(
                        label: l10n.card,
                        icon: Icons.credit_card_rounded,
                        isSelected: paymentMethod == 'card',
                        isDark: isDark,
                        onTap: () => onPaymentMethodChanged('card'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PosSelectionOption(
                        label: l10n.transfer,
                        icon: Icons.swap_horiz_rounded,
                        isSelected: paymentMethod == 'transfer',
                        isDark: isDark,
                        onTap: () => onPaymentMethodChanged('transfer'),
                      ),
                    ),
                  ],
                ),
                if (onSplitPayment != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onSplitPayment,
                      icon: const Icon(Icons.call_split_rounded, size: 18),
                      label: Text(l10n.splitPayment),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: paymentMethod == 'split'
                            ? AppColors.primary
                            : null,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onCompleteSale,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${l10n.completeSale} (F2)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

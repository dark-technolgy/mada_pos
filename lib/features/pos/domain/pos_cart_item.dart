import '../../../core/database/database.dart';
import '../../../core/services/invoice_print_service.dart';
import 'pos_pricing.dart';

class PosCartItem {
  const PosCartItem({
    required this.product,
    required this.quantity,
    required this.baseUnitPrice,
    required this.unitPrice,
    required this.discount,
  });

  final Product product;
  final double quantity;
  final double baseUnitPrice;
  final double unitPrice;
  final double discount;

  PosLinePricing get pricing => PosPricing.normalizeLine(
    quantity: quantity,
    unitPrice: unitPrice,
    discount: discount,
  );

  double get total => pricing.netTotal;

  PosCartItem copyWith({
    Product? product,
    double? quantity,
    double? baseUnitPrice,
    double? unitPrice,
    double? discount,
  }) {
    final nextQuantity = quantity ?? this.quantity;
    final nextUnitPrice = unitPrice ?? this.unitPrice;
    final nextDiscount = discount ?? this.discount;
    final normalized = PosPricing.normalizeLine(
      quantity: nextQuantity,
      unitPrice: nextUnitPrice,
      discount: nextDiscount,
    );

    return PosCartItem(
      product: product ?? this.product,
      quantity: nextQuantity,
      baseUnitPrice: baseUnitPrice ?? this.baseUnitPrice,
      unitPrice: nextUnitPrice,
      discount: normalized.clampedDiscount,
    );
  }

  PosLinePricing toLinePricing() => pricing;

  InvoicePrintItem toPrintItem() => InvoicePrintItem(
    name: product.nameAr,
    quantity: quantity,
    unitPrice: unitPrice,
    discount: discount,
    total: total,
    barcode: product.barcode,
  );
}

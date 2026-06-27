import '../../../core/database/database.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/tax_settings.dart';
import 'pos_cart_item.dart';
import 'pos_payment_split.dart';
import 'pos_pricing.dart';

class PosSaleDraft {
  const PosSaleDraft({
    this.cart = const [],
    this.selectedCustomer,
    this.invoiceDiscount = 0,
    this.discountType = 'fixed',
    this.paymentMethod = 'cash',
    this.paymentSplits,
    this.currencyCode = CurrencyConversion.baseCurrencyCode,
    this.exchangeRate = 1.0,
    this.taxSettings = const TaxSettings(),
  });

  static const _unset = Object();

  final List<PosCartItem> cart;
  final Customer? selectedCustomer;
  final double invoiceDiscount;
  final String discountType;
  final String paymentMethod;
  final List<PosPaymentSplit>? paymentSplits;
  final String currencyCode;
  final double exchangeRate;
  final TaxSettings taxSettings;

  PosPricingSummary get pricingSummary => PosPricing.summarize(
    lines: cart.map((item) => item.toLinePricing()),
    invoiceDiscount: invoiceDiscount,
    discountType: discountType,
    taxSettings: taxSettings,
  );

  double get grossSubtotal => pricingSummary.grossSubtotal;
  double get lineDiscountTotal => pricingSummary.lineDiscountTotal;
  double get discountAmount => pricingSummary.invoiceDiscountAmount;
  double get total => pricingSummary.total;

  PosSaleDraft copyWith({
    List<PosCartItem>? cart,
    Object? selectedCustomer = _unset,
    double? invoiceDiscount,
    String? discountType,
    String? paymentMethod,
    Object? paymentSplits = _unset,
    String? currencyCode,
    double? exchangeRate,
    TaxSettings? taxSettings,
  }) {
    return PosSaleDraft(
      cart: cart ?? this.cart,
      selectedCustomer: identical(selectedCustomer, _unset)
          ? this.selectedCustomer
          : selectedCustomer as Customer?,
      invoiceDiscount: invoiceDiscount ?? this.invoiceDiscount,
      discountType: discountType ?? this.discountType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentSplits: identical(paymentSplits, _unset)
          ? this.paymentSplits
          : paymentSplits as List<PosPaymentSplit>?,
      currencyCode: currencyCode ?? this.currencyCode,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      taxSettings: taxSettings ?? this.taxSettings,
    );
  }

  PosSaleDraft addProduct(Product product, {double? baseUnitPrice}) {
    final base = baseUnitPrice ?? product.sellingPrice;
    final nextCart = [...cart];
    final existingIndex = nextCart.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      nextCart[existingIndex] = nextCart[existingIndex].copyWith(
        quantity: nextCart[existingIndex].quantity + 1.0,
      );
    } else {
      nextCart.add(
        PosCartItem(
          product: product,
          quantity: 1.0,
          baseUnitPrice: base,
          unitPrice: CurrencyConversion.fromBase(
            base,
            currencyCode: currencyCode,
            exchangeRate: exchangeRate,
          ),
          discount: 0.0,
        ),
      );
    }

    return copyWith(cart: nextCart);
  }

  PosSaleDraft removeCartItemAt(int index) {
    final nextCart = [...cart]..removeAt(index);
    return copyWith(cart: nextCart);
  }

  PosSaleDraft updateCartItemQuantity(int index, double quantity) {
    final nextCart = [...cart];
    nextCart[index] = nextCart[index].copyWith(quantity: quantity);
    return copyWith(cart: nextCart);
  }

  PosSaleDraft updateCartItemDiscount(int index, double discount) {
    final nextCart = [...cart];
    nextCart[index] = nextCart[index].copyWith(discount: discount);
    return copyWith(cart: nextCart);
  }

  PosSaleDraft updateCurrency({
    required String currencyCode,
    required double exchangeRate,
  }) {
    if (currencyCode == this.currencyCode) {
      return this;
    }

    final nextInvoiceDiscount = discountType == 'fixed' && invoiceDiscount > 0
        ? CurrencyConversion.fromBase(
            CurrencyConversion.toBase(
              invoiceDiscount,
              currencyCode: this.currencyCode,
              exchangeRate: this.exchangeRate,
            ),
            currencyCode: currencyCode,
            exchangeRate: exchangeRate,
          )
        : invoiceDiscount;

    final nextCart = cart
        .map(
          (item) => item.copyWith(
            baseUnitPrice: item.baseUnitPrice,
            unitPrice: CurrencyConversion.fromBase(
              item.baseUnitPrice,
              currencyCode: currencyCode,
              exchangeRate: exchangeRate,
            ),
            discount: CurrencyConversion.fromBase(
              CurrencyConversion.toBase(
                item.discount,
                currencyCode: this.currencyCode,
                exchangeRate: this.exchangeRate,
              ),
              currencyCode: currencyCode,
              exchangeRate: exchangeRate,
            ),
          ),
        )
        .toList(growable: false);

    return copyWith(
      cart: nextCart,
      invoiceDiscount: nextInvoiceDiscount,
      currencyCode: currencyCode,
      exchangeRate: exchangeRate,
    );
  }

  PosSaleDraft clearInvoiceDiscount() {
    return copyWith(invoiceDiscount: 0);
  }

  PosSaleDraft resetAfterHold() {
    return copyWith(
      cart: const [],
      selectedCustomer: null,
      invoiceDiscount: 0,
      discountType: 'fixed',
      paymentMethod: 'cash',
      paymentSplits: null,
    );
  }

  PosSaleDraft resetAfterComplete() {
    return copyWith(
      cart: const [],
      selectedCustomer: null,
      invoiceDiscount: 0,
      paymentSplits: null,
      paymentMethod: 'cash',
    );
  }
}

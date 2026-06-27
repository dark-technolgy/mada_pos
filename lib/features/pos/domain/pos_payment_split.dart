/// One leg of a split payment at checkout.
class PosPaymentSplit {
  const PosPaymentSplit({
    required this.method,
    required this.amount,
  });

  /// `cash`, `card`, or `transfer`.
  final String method;
  final double amount;
}

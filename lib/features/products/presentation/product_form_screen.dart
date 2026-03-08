import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/database/database.dart';
import '../../../shared/providers/app_providers.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final int? productId;
  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameArCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  final _nameKuCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _purchasePriceCtrl = TextEditingController(text: '0');
  final _sellingPriceCtrl = TextEditingController(text: '0');
  final _wholesalePriceCtrl = TextEditingController();
  final _minPriceCtrl = TextEditingController();
  final _minStockCtrl = TextEditingController(text: '0');
  final _maxStockCtrl = TextEditingController();
  final _initialStockCtrl = TextEditingController(text: '0');

  int? _selectedCategoryId;
  int? _selectedUnitId;
  bool _isActive = true;
  bool _isSaving = false;
  bool _isEditing = false;

  List<Category> _categories = [];
  List<Unit> _units = [];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.productId != null;
    _loadData();
  }

  @override
  void dispose() {
    _nameArCtrl.dispose();
    _nameEnCtrl.dispose();
    _nameKuCtrl.dispose();
    _barcodeCtrl.dispose();
    _skuCtrl.dispose();
    _descriptionCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _wholesalePriceCtrl.dispose();
    _minPriceCtrl.dispose();
    _minStockCtrl.dispose();
    _maxStockCtrl.dispose();
    _initialStockCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = ref.read(databaseProvider);
    final categories = await (db.select(
      db.categories,
    )..where((c) => c.isActive.equals(true))).get();
    final units = await db.select(db.units).get();

    setState(() {
      _categories = categories;
      _units = units;
    });

    if (_isEditing) {
      final product = await (db.select(
        db.products,
      )..where((p) => p.id.equals(widget.productId!))).getSingleOrNull();
      if (product != null) {
        _nameArCtrl.text = product.nameAr;
        _nameEnCtrl.text = product.nameEn ?? '';
        _nameKuCtrl.text = product.nameKu ?? '';
        _barcodeCtrl.text = product.barcode ?? '';
        _skuCtrl.text = product.sku ?? '';
        _descriptionCtrl.text = product.description ?? '';
        _purchasePriceCtrl.text = product.purchasePrice.toString();
        _sellingPriceCtrl.text = product.sellingPrice.toString();
        _minStockCtrl.text = product.minStockLevel.toString();
        setState(() {
          _selectedCategoryId = product.categoryId;
          _selectedUnitId = product.unitId;
          _isActive = product.isActive;
        });
      }
    }
  }

  Future<void> _saveProduct() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);

      if (_isEditing) {
        await (db.update(
          db.products,
        )..where((p) => p.id.equals(widget.productId!))).write(
          ProductsCompanion(
            nameAr: Value(_nameArCtrl.text.trim()),
            nameEn: Value(
              _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
            ),
            nameKu: Value(
              _nameKuCtrl.text.trim().isEmpty ? null : _nameKuCtrl.text.trim(),
            ),
            barcode: Value(
              _barcodeCtrl.text.trim().isEmpty
                  ? null
                  : _barcodeCtrl.text.trim(),
            ),
            sku: Value(
              _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
            ),
            description: Value(
              _descriptionCtrl.text.trim().isEmpty
                  ? null
                  : _descriptionCtrl.text.trim(),
            ),
            categoryId: Value(_selectedCategoryId),
            unitId: Value(_selectedUnitId),
            purchasePrice: Value(double.tryParse(_purchasePriceCtrl.text) ?? 0),
            sellingPrice: Value(double.tryParse(_sellingPriceCtrl.text) ?? 0),
            minStockLevel: Value(double.tryParse(_minStockCtrl.text) ?? 0),
            isActive: Value(_isActive),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } else {
        final productId = await db
            .into(db.products)
            .insert(
              ProductsCompanion.insert(
                nameAr: _nameArCtrl.text.trim(),
                nameEn: Value(
                  _nameEnCtrl.text.trim().isEmpty
                      ? null
                      : _nameEnCtrl.text.trim(),
                ),
                nameKu: Value(
                  _nameKuCtrl.text.trim().isEmpty
                      ? null
                      : _nameKuCtrl.text.trim(),
                ),
                barcode: Value(
                  _barcodeCtrl.text.trim().isEmpty
                      ? null
                      : _barcodeCtrl.text.trim(),
                ),
                sku: Value(
                  _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
                ),
                description: Value(
                  _descriptionCtrl.text.trim().isEmpty
                      ? null
                      : _descriptionCtrl.text.trim(),
                ),
                categoryId: Value(_selectedCategoryId),
                unitId: Value(_selectedUnitId),
                purchasePrice: Value(
                  double.tryParse(_purchasePriceCtrl.text) ?? 0,
                ),
                sellingPrice: Value(
                  double.tryParse(_sellingPriceCtrl.text) ?? 0,
                ),
                minStockLevel: Value(double.tryParse(_minStockCtrl.text) ?? 0),
                isActive: const Value(true),
              ),
            );

        // Create initial stock entry
        final initialStock = double.tryParse(_initialStockCtrl.text) ?? 0;
        if (initialStock > 0) {
          final warehouse = await (db.select(
            db.warehouses,
          )..limit(1)).getSingleOrNull();
          if (warehouse != null) {
            await db
                .into(db.stock)
                .insert(
                  StockCompanion.insert(
                    productId: productId,
                    warehouseId: warehouse.id,
                    quantity: Value(initialStock),
                  ),
                );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? l10n.productUpdatedSuccessfully
                  : l10n.productAddedSuccessfully,
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/products');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorOccurred}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/products'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 12),
                Text(
                  _isEditing ? l10n.editProduct : l10n.newProduct,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => context.go('/products'),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveProduct,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_isSaving ? l10n.saving : l10n.save),
                ),
              ],
            ),
          ),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSection(l10n.basicInformation, [
                            _buildTextField(
                              '${l10n.productNameArabic} *',
                              _nameArCtrl,
                              requiredMessage: l10n.fieldRequired,
                              required: true,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    l10n.productNameEnglish,
                                    _nameEnCtrl,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    l10n.productNameKurdish,
                                    _nameKuCtrl,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              l10n.notes,
                              _descriptionCtrl,
                              maxLines: 3,
                            ),
                          ], isDark),
                          const SizedBox(height: 20),
                          _buildSection(l10n.categoryAndUnit, [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int?>(
                                    initialValue: _selectedCategoryId,
                                    decoration: InputDecoration(
                                      labelText: l10n.category,
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text(l10n.withoutCategory),
                                      ),
                                      ..._categories.map(
                                        (c) => DropdownMenuItem(
                                          value: c.id,
                                          child: Text(c.nameAr),
                                        ),
                                      ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _selectedCategoryId = v),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<int?>(
                                    initialValue: _selectedUnitId,
                                    decoration: InputDecoration(
                                      labelText: l10n.unit,
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text(l10n.withoutUnit),
                                      ),
                                      ..._units.map(
                                        (u) => DropdownMenuItem(
                                          value: u.id,
                                          child: Text(u.nameAr),
                                        ),
                                      ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _selectedUnitId = v),
                                  ),
                                ),
                              ],
                            ),
                          ], isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSection(l10n.pricing, [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    '${l10n.purchasePrice} *',
                                    _purchasePriceCtrl,
                                    keyboardType: TextInputType.number,
                                    requiredMessage: l10n.fieldRequired,
                                    required: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    '${l10n.sellingPrice} *',
                                    _sellingPriceCtrl,
                                    keyboardType: TextInputType.number,
                                    requiredMessage: l10n.fieldRequired,
                                    required: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    l10n.wholesalePrice,
                                    _wholesalePriceCtrl,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    l10n.minimumSellingPrice,
                                    _minPriceCtrl,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                          ], isDark),
                          const SizedBox(height: 20),
                          _buildSection(l10n.barcodeAndCode, [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    l10n.barcode,
                                    _barcodeCtrl,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    l10n.productCodeSku,
                                    _skuCtrl,
                                  ),
                                ),
                              ],
                            ),
                          ], isDark),
                          const SizedBox(height: 20),
                          _buildSection(l10n.stock, [
                            Row(
                              children: [
                                if (!_isEditing)
                                  Expanded(
                                    child: _buildTextField(
                                      l10n.initialQuantity,
                                      _initialStockCtrl,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                if (!_isEditing) const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    l10n.minimumLimit,
                                    _minStockCtrl,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    l10n.maximumLimit,
                                    _maxStockCtrl,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              title: Text(l10n.productIsActive),
                              value: _isActive,
                              onChanged: (v) => setState(() => _isActive = v),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ], isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool required = false,
    String? requiredMessage,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (v) {
              if (v == null || v.trim().isEmpty) {
                return requiredMessage ?? '';
              }
              return null;
            }
          : null,
    );
  }
}

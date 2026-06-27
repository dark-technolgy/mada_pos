import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/database.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../application/product_form_service.dart';
import 'widgets/product_form_sections.dart';

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
  final ProductFormService _productFormService = const ProductFormService();

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
    final result = await _productFormService.loadFormData(
      db,
      productId: widget.productId,
    );

    setState(() {
      _categories = result.categories;
      _units = result.units;
    });

    final product = result.product;
    if (product == null) return;

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

  Future<void> _saveProduct() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final payload = ProductFormPayload(
        nameAr: _nameArCtrl.text.trim(),
        nameEn: _nameEnCtrl.text.trim().isEmpty
            ? null
            : _nameEnCtrl.text.trim(),
        nameKu: _nameKuCtrl.text.trim().isEmpty
            ? null
            : _nameKuCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim().isEmpty
            ? null
            : _barcodeCtrl.text.trim(),
        sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        purchasePrice: double.tryParse(_purchasePriceCtrl.text) ?? 0,
        sellingPrice: double.tryParse(_sellingPriceCtrl.text) ?? 0,
        minStockLevel: double.tryParse(_minStockCtrl.text) ?? 0,
        initialStock: double.tryParse(_initialStockCtrl.text) ?? 0,
        categoryId: _selectedCategoryId,
        unitId: _selectedUnitId,
        isActive: _isActive,
      );

      await _productFormService.saveProduct(
        db,
        payload: payload,
        productId: widget.productId,
      );

      if (mounted) {
        AppFeedback.success(
          context,
          _isEditing
              ? l10n.productUpdatedSuccessfully
              : l10n.productAddedSuccessfully,
        );
        context.go('/products');
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.error(context, '${l10n.errorOccurred}: $e');
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
          ProductFormHeader(
            isDark: isDark,
            title: _isEditing ? l10n.editProduct : l10n.newProduct,
            cancelLabel: l10n.cancel,
            saveLabel: l10n.save,
            savingLabel: l10n.saving,
            isSaving: _isSaving,
            onCancel: () => context.go('/products'),
            onSave: _saveProduct,
          ),
          Expanded(
            child: ProductFormContent(
              formKey: _formKey,
              isDark: isDark,
              basicTitle: l10n.basicInformation,
              categoryUnitTitle: l10n.categoryAndUnit,
              pricingTitle: l10n.pricing,
              barcodeTitle: l10n.barcodeAndCode,
              stockTitle: l10n.stock,
              nameArLabel: '${l10n.productNameArabic} *',
              nameEnLabel: l10n.productNameEnglish,
              nameKuLabel: l10n.productNameKurdish,
              notesLabel: l10n.notes,
              categoryLabel: l10n.category,
              withoutCategoryLabel: l10n.withoutCategory,
              unitLabel: l10n.unit,
              withoutUnitLabel: l10n.withoutUnit,
              purchasePriceLabel: '${l10n.purchasePrice} *',
              sellingPriceLabel: '${l10n.sellingPrice} *',
              wholesalePriceLabel: l10n.wholesalePrice,
              minSellingPriceLabel: l10n.minimumSellingPrice,
              barcodeLabel: l10n.barcode,
              skuLabel: l10n.productCodeSku,
              initialQuantityLabel: l10n.initialQuantity,
              minimumLimitLabel: l10n.minimumLimit,
              maximumLimitLabel: l10n.maximumLimit,
              productIsActiveLabel: l10n.productIsActive,
              fieldRequiredLabel: l10n.fieldRequired,
              nameArCtrl: _nameArCtrl,
              nameEnCtrl: _nameEnCtrl,
              nameKuCtrl: _nameKuCtrl,
              descriptionCtrl: _descriptionCtrl,
              purchasePriceCtrl: _purchasePriceCtrl,
              sellingPriceCtrl: _sellingPriceCtrl,
              wholesalePriceCtrl: _wholesalePriceCtrl,
              minPriceCtrl: _minPriceCtrl,
              barcodeCtrl: _barcodeCtrl,
              skuCtrl: _skuCtrl,
              initialStockCtrl: _initialStockCtrl,
              minStockCtrl: _minStockCtrl,
              maxStockCtrl: _maxStockCtrl,
              categories: _categories,
              units: _units,
              selectedCategoryId: _selectedCategoryId,
              selectedUnitId: _selectedUnitId,
              isActive: _isActive,
              isEditing: _isEditing,
              onCategoryChanged: (value) =>
                  setState(() => _selectedCategoryId = value),
              onUnitChanged: (value) => setState(() => _selectedUnitId = value),
              onActiveChanged: (value) => setState(() => _isActive = value),
            ),
          ),
        ],
      ),
    );
  }
}

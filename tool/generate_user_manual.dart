// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates user manual PDFs for Mada POS (ar, en, ku).
/// Run: dart run tool/generate_user_manual.dart [ar|en|ku|all]
Future<void> main(List<String> args) async {
  final outDir = Directory('dist');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  final target = args.isEmpty ? 'all' : args.first.toLowerCase();
  final locales = switch (target) {
    'ar' => ['ar'],
    'en' => ['en'],
    'ku' => ['ku'],
    _ => ['ar', 'en', 'ku'],
  };

  for (final locale in locales) {
    await _generateManual(locale);
  }
}

Future<void> _generateManual(String locale) async {
  final isRtl = locale != 'en';
  final font = locale == 'en'
      ? pw.Font.helvetica()
      : await _loadArabicFont();
  final bold = locale == 'en'
      ? pw.Font.helveticaBold()
      : pw.Font.ttf(
          (await _loadFontBytes(
            'Amiri-Bold.ttf',
            'https://raw.githubusercontent.com/google/fonts/main/ofl/amiri/Amiri-Bold.ttf',
          ))
              .buffer
              .asByteData(),
        );

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: bold),
  );

  final meta = _localeMeta(locale);
  final sections = _manualSections(locale);

  pw.TextStyle textStyle({
    double fontSize = 11,
    PdfColor? color,
    double? lineSpacing,
    pw.FontWeight fontWeight = pw.FontWeight.normal,
  }) {
    final f = fontWeight == pw.FontWeight.bold ? bold : font;
    return pw.TextStyle(
      font: f,
      fontSize: fontSize,
      color: color,
      lineSpacing: lineSpacing,
    );
  }

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(height: 120),
          pw.Text(
            'Mada POS',
            style: textStyle(fontSize: 32, fontWeight: pw.FontWeight.bold),
            textDirection: pw.TextDirection.ltr,
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            meta.title,
            style: textStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
            textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          ),
          pw.SizedBox(height: 8),
          pw.Text(meta.version, style: textStyle(fontSize: 14)),
          pw.SizedBox(height: 24),
          pw.Text(
            meta.subtitle,
            style: textStyle(fontSize: 13),
            textAlign: pw.TextAlign.center,
          ),
          pw.Spacer(),
          pw.Text(
            'Mada — ${DateTime.now().year}',
            style: textStyle(fontSize: 12),
            textDirection: pw.TextDirection.ltr,
          ),
        ],
      ),
    ),
  );

  for (final section in sections) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        header: (context) => pw.Container(
          alignment:
              isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          margin: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Text(
            meta.header,
            style: textStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            meta.pageOf(context.pageNumber, context.pagesCount),
            style: textStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Text(
            section.title,
            style: textStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          for (final block in section.blocks) ...[
            if (block is _ManualParagraph)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  block.text,
                  style: textStyle(fontSize: 11, lineSpacing: 4),
                  textAlign: isRtl ? pw.TextAlign.right : pw.TextAlign.left,
                ),
              ),
            if (block is _ManualBullets)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (final item in block.items)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 6, right: 8),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('• ', style: textStyle(fontSize: 11)),
                          pw.Expanded(
                            child: pw.Text(
                              item,
                              style: textStyle(fontSize: 11, lineSpacing: 3),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            pw.SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  final outFile = File('dist/${meta.fileName}');
  await outFile.writeAsBytes(await doc.save());
  print('Created ${outFile.path} (${await outFile.length()} bytes)');
}

class _LocaleMeta {
  const _LocaleMeta({
    required this.fileName,
    required this.title,
    required this.version,
    required this.subtitle,
    required this.header,
    required this.pageOf,
  });

  final String fileName;
  final String title;
  final String version;
  final String subtitle;
  final String header;
  final String Function(int page, int total) pageOf;
}

_LocaleMeta _localeMeta(String locale) {
  return switch (locale) {
    'en' => _LocaleMeta(
        fileName: 'Mada_POS_User_Manual_EN.pdf',
        title: 'User Manual',
        version: 'Version 1.0.0',
        subtitle: 'Sales and inventory management for shops and offices',
        header: 'Mada POS — User Manual',
        pageOf: (p, t) => 'Page $p of $t',
      ),
    'ku' => _LocaleMeta(
        fileName: 'Mada_POS_User_Manual_KU.pdf',
        title: 'ڕێنمایی بەکارهێنەر',
        version: 'وەشان 1.0.0',
        subtitle: 'بەڕێوەبردنی فرۆشتن و کۆگا بۆ فرۆشگا و ئۆفیس',
        header: 'Mada POS — ڕێنمایی بەکارهێنەر',
        pageOf: (p, t) => 'لاپەڕە $p لە $t',
      ),
    _ => _LocaleMeta(
        fileName: 'Mada_POS_User_Manual_AR.pdf',
        title: 'دليل المستخدم',
        version: 'الإصدار 1.0.0',
        subtitle: 'نظام إدارة المبيعات والمخزون للمكاتب والمحلات',
        header: 'Mada POS — دليل المستخدم',
        pageOf: (p, t) => 'صفحة $p من $t',
      ),
  };
}

class _ManualSection {
  const _ManualSection(this.title, this.blocks);
  final String title;
  final List<_ManualBlock> blocks;
}

sealed class _ManualBlock {}

class _ManualParagraph extends _ManualBlock {
  _ManualParagraph(this.text);
  final String text;
}

class _ManualBullets extends _ManualBlock {
  _ManualBullets(this.items);
  final List<String> items;
}

List<_ManualSection> _manualSections(String locale) {
  if (locale == 'en') return _manualSectionsEn();
  if (locale == 'ku') return _manualSectionsKu();
  return [
    _ManualSection('مقدمة', [
      _ManualParagraph(
        'Mada POS نظام مكتبي لإدارة المبيعات، المشتريات، المخزون، العملاء، الموردين، الديون، المصروفات، والتقارير. '
        'يعمل بدون إنترنت ويحفظ البيانات محلياً على جهازك.',
      ),
      _ManualParagraph(
        'يدعم النظام العربية والإنجليزية والكردية، والدينار العراقي والدولار، مع صلاحيات متعددة للمستخدمين.',
      ),
    ]),
    _ManualSection('متطلبات التشغيل', [
      _ManualBullets([
        'Windows 10 أو أحدث (64-bit).',
        '4 GB ذاكرة RAM كحد أدنى (8 GB موصى به).',
        '500 MB مساحة قرص فارغة.',
        'شاشة بدقة 1280×720 كحد أدنى.',
        'طابعة (اختياري) لفواتير PDF.',
      ]),
    ]),
    _ManualSection('التثبيت', [
      _ManualBullets([
        'شغّل ملف Mada_POS_Setup_1.0.0.exe.',
        'اتبع معالج التثبيت واختر مجلد التثبيت (الافتراضي: Program Files\\Mada POS).',
        'اختر إنشاء اختصار سطح المكتب إن رغبت.',
        'بعد الانتهاء، شغّل البرنامج من قائمة ابدأ أو الاختصار.',
        'دليل المستخدم PDF يُثبَّت في مجلد docs داخل مجلد البرنامج.',
      ]),
    ]),
    _ManualSection('أول تسجيل دخول', [
      _ManualBullets([
        'المستخدم الافتراضي: admin',
        'كلمة المرور الافتراضية: admin123',
        'يُطلب من المدير تغيير كلمة المرور عند أول دخول — اختر كلمة مرور قوية.',
        'غيّر كلمة المرور فوراً قبل استخدام النظام في بيئة الإنتاج.',
      ]),
    ]),
    _ManualSection('لوحة التحكم', [
      _ManualParagraph(
        'تعرض ملخص مبيعات اليوم، الديون، المبيعات الشهرية، آخر الفواتير، والمنتجات منخفضة المخزون.',
      ),
      _ManualBullets([
        'المدير والمشرف يرون ربح اليوم؛ الكاشير لا يرى الأرباح.',
        'إجراءات سريعة: بيع جديد، إضافة عميل، إضافة منتج.',
      ]),
    ]),
    _ManualSection('نقطة البيع (POS)', [
      _ManualBullets([
        'امسح الباركود أو ابحث عن المنتج وأضفه للسلة.',
        'اختر العميل (اختياري) والعملة وطريقة الدفع.',
        'طبّق خصماً على الفاتورة أو على صنف معيّن.',
        'الضريبة تُحسب تلقائياً حسب إعدادات النظام.',
        'F2 لإتمام البيع، F3 للبحث عن منتج.',
        'تعليق الفاتورة: احفظ السلة واسترجعها لاحقاً.',
        'بعد البيع يمكن طباعة الفاتورة PDF.',
      ]),
    ]),
    _ManualSection('المنتجات والمخزون', [
      _ManualBullets([
        'المنتجات: إضافة، تعديل، باركود، أسعار شراء وبيع، تصنيف، وحدة.',
        'الأصناف والوحدات: إدارة من القوائم الجانبية.',
        'المخزون: عرض الكميات، تعديل يدوي، تنبيه انخفاض المخزون.',
        'المخازن: إنشاء مخازن متعددة وتحديد المخزن الافتراضي.',
        'نقل المخزون: من شاشة المخزون استخدم أيقونة ↔ لنقل كمية بين مخزنين.',
      ]),
    ]),
    _ManualSection('العملاء والموردين', [
      _ManualBullets([
        'العملاء: بيانات الاتصال، حد ائتمان، رصيد ديون.',
        'الموردين: بيانات الشركة والرصيد.',
        'ربط العميل بفاتورة البيع لتتبع الديون.',
      ]),
    ]),
    _ManualSection('الفواتير والعروض', [
      _ManualBullets([
        'فواتير المبيعات والمشتريات والمرتجعات من شاشة الفواتير.',
        'فاتورة شراء جديدة من تبويب المشتريات.',
        'إلغاء فاتورة (للمدير/المشرف): من تفاصيل الفاتورة — يعكس المخزون.',
        'تصدير PDF أو Excel للفواتير المفلترة.',
        'عروض الأسعار: إنشاء عرض، تعديله، ثم تحويله إلى بيع عند الموافقة.',
      ]),
    ]),
    _ManualSection('الديون والمصروفات والصندوق', [
      _ManualBullets([
        'الديون: متابعة مدين/دائن وتسجيل دفعات.',
        'المصروفات: تسجيل مصروفات يومية مع تصنيف.',
        'الصندوق: فتح وردية بمبلغ افتتاحي وإغلاقها بجرد نقدي.',
      ]),
    ]),
    _ManualSection('التقارير', [
      _ManualBullets([
        'اختر الفترة الزمنية من أعلى الشاشة.',
        'تبويبات: المبيعات، المنتجات، المالية.',
        'تصدير Excel للملخص (للمدير/المشرف مع الأرباح).',
      ]),
    ]),
    _ManualSection('المستخدمون والصلاحيات', [
      _ManualParagraph('الأدوار: مدير (admin)، مشرف (manager)، كاشير (cashier)، مشاهد (viewer).'),
      _ManualBullets([
        'المدير: كل الصلاحيات + المستخدمون + النسخ الاحتياطي + سجل المراجعة.',
        'المشرف: تقارير وأرباح، موردين، مصروفات، إلغاء فواتير.',
        'الكاشير: بيع وفواتير بدون إدارة منتجات حساسة.',
        'المشاهد: عرض فقط.',
      ]),
    ]),
    _ManualSection('الإعدادات', [
      _ManualBullets([
        'بيانات الشركة: الاسم، الهاتف، العنوان (تظهر على الطباعة).',
        'إعدادات الضريبة: النسبة % وهل الأسعار تشمل الضريبة.',
        'العملات: العملة الافتراضية وسعر صرف الدولار.',
        'المظهر: الوضع الداكن/الفاتح واللغة.',
      ]),
    ]),
    _ManualSection('النسخ الاحتياطي', [
      _ManualBullets([
        'إنشاء نسخة يدوية من شاشة النسخ الاحتياطي.',
        'النسخ التلقائي: تفعيله وتحديد الفترة بالساعات.',
        'الاستعادة: اختر نسخة قديمة — يُعاد تشغيل البرنامج بعد الاستعادة.',
        'مجلد النسخ: Mada_Backups في مجلد المستخدم.',
      ]),
    ]),
    _ManualSection('حل المشاكل الشائعة', [
      _ManualBullets([
        'لا يمكن البيع: تحقق من وجود كمية في المخزن الافتراضي.',
        'نسيت كلمة المرور: يحتاج المدير لإعادة تعيينها من إدارة المستخدمين.',
        'الطباعة لا تعمل: تحقق من تعريف الطابعة الافتراضية في Windows.',
        'بطء الأداء: أنشئ نسخة احتياطية ونظّف البيانات القديمة أو حدّث الجهاز.',
        'للدعم: احتفظ بنسخة احتياطية قبل أي تحديث للبرنامج.',
      ]),
    ]),
  ];
}

List<_ManualSection> _manualSectionsEn() {
  return [
    _ManualSection('Introduction', [
      _ManualParagraph(
        'Mada POS is a desktop system for sales, purchases, inventory, customers, '
        'suppliers, debts, expenses, and reports. It works offline with local data storage.',
      ),
    ]),
    _ManualSection('Requirements', [
      _ManualBullets([
        'Windows 10 or later (64-bit).',
        '4 GB RAM minimum (8 GB recommended).',
        '500 MB free disk space.',
        '1280×720 display minimum.',
        'Printer optional for PDF invoices.',
      ]),
    ]),
    _ManualSection('Installation', [
      _ManualBullets([
        'Run Mada_POS_Setup_1.0.0.exe or extract the portable ZIP.',
        'Follow the wizard; default folder: Program Files\\Mada POS.',
        'User manuals are installed under the docs folder.',
        'On first run, Windows runtimes may install silently.',
      ]),
    ]),
    _ManualSection('First login', [
      _ManualBullets([
        'Default user: admin',
        'Default password: admin123',
        'Change the admin password on first login.',
      ]),
    ]),
    _ManualSection('POS', [
      _ManualBullets([
        'Scan barcode or search products and add to cart.',
        'Select customer, currency, and payment method.',
        'F2 to complete sale, F3 to search products.',
        'Print invoice PDF after sale.',
      ]),
    ]),
    _ManualSection('Settings & backup', [
      _ManualBullets([
        'Company info and logo appear on printed invoices.',
        'Tax rate and default currency in Settings.',
        'Backup and restore from the Backup screen.',
        'About screen: open user manual and error logs.',
      ]),
    ]),
    _ManualSection('License', [
      _ManualBullets([
        '30-day trial on first install.',
        'Copy Device ID from activation screen and request a license key.',
        'Vendor generates key: dart run tool/generate_license_key.dart <DEVICE_ID>',
      ]),
    ]),
  ];
}

List<_ManualSection> _manualSectionsKu() {
  return [
    _ManualSection('پێشەکی', [
      _ManualParagraph(
        'Mada POS سیستەمێکی مێزگەییە بۆ فرۆشتن، کڕین، کۆگا، کڕیار، دابینکەر، قەرز و ڕاپۆرت. '
        'بێ ئینتەرنێت کاردەکات و داتا لەسەر ئامێرەکەت دەپارێزێت.',
      ),
    ]),
    _ManualSection('دامەزراندن', [
      _ManualBullets([
        'فایلی Mada_POS_Setup_1.0.0.exe یان ZIP بەکاربهێنە.',
        'ڕێنمایی PDF لە بوخچەی docs دەبینرێت.',
      ]),
    ]),
    _ManualSection('چوونەژوورەوە', [
      _ManualBullets([
        'بەکارهێنەر: admin',
        'وشەی نهێنی: admin123',
        'وشەی نهێنی بگۆڕە لە یەکەم چوونەژوورەوە.',
      ]),
    ]),
    _ManualSection('فرۆشتن (POS)', [
      _ManualBullets([
        'بارکۆد بخوێنەوە یان بگەڕێ بۆ بەرهەم.',
        'F2 تەواوکردنی فرۆشتن، F3 گەڕان.',
      ]),
    ]),
    _ManualSection('ڕێکخستن و پاشەکەوت', [
      _ManualBullets([
        'زانیاری کۆمپانیا و لۆگۆ لە ڕێکخستنەکان.',
        'پاشەکەوتی داتا لە شاشەی پاشەکەوت.',
      ]),
    ]),
  ];
}

Future<pw.Font> _loadArabicFont() async {
  final bytes = await _loadFontBytes(
    'Amiri-Regular.ttf',
    'https://raw.githubusercontent.com/google/fonts/main/ofl/amiri/Amiri-Regular.ttf',
  );
  return pw.Font.ttf(bytes.buffer.asByteData());
}

Future<Uint8List> _loadFontBytes(String fileName, String url) async {
  final cacheDir = Directory('tool/.cache');
  if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);
  final cacheFile = File('tool/.cache/$fileName');
  if (!cacheFile.existsSync()) {
    print('Downloading $fileName...');
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('Failed to download font: ${response.statusCode}');
      }
      final bytes = await consolidateHttpClientResponseBytes(response);
      await cacheFile.writeAsBytes(bytes);
    } finally {
      client.close();
    }
  }
  return cacheFile.readAsBytes();
}

Future<Uint8List> consolidateHttpClientResponseBytes(HttpClientResponse response) async {
  final chunks = <List<int>>[];
  var length = 0;
  await for (final chunk in response) {
    chunks.add(chunk);
    length += chunk.length;
  }
  final result = Uint8List(length);
  var offset = 0;
  for (final chunk in chunks) {
    result.setRange(offset, offset + chunk.length, chunk);
    offset += chunk.length;
  }
  return result;
}

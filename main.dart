
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDb.instance.init();
  runApp(const SriKesarApp());
}

class SriKesarApp extends StatefulWidget {
  const SriKesarApp({super.key});
  @override
  State<SriKesarApp> createState() => _SriKesarAppState();
}

class _SriKesarAppState extends State<SriKesarApp> {
  bool darkMode = false;

  @override
  void initState() {
    super.initState();
    AppDb.instance.getSetting('darkMode').then((v) => setState(() => darkMode = v == 'true'));
  }

  Future<void> setDark(bool value) async {
    await AppDb.instance.setSetting('darkMode', value.toString());
    setState(() => darkMode = value);
  }

  @override
  Widget build(BuildContext context) {
    return ThemeController(
      darkMode: darkMode,
      setDarkMode: setDark,
      child: MaterialApp(
        title: 'Sri Kesar Billing',
        debugShowCheckedModeBanner: false,
        themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
          scaffoldBackgroundColor: const Color(0xFFF5F7FB),
          cardTheme: CardThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF64B5F6), brightness: Brightness.dark),
        ),
        home: const LoginScreen(),
      ),
    );
  }
}

class ThemeController extends InheritedWidget {
  final bool darkMode;
  final Future<void> Function(bool value) setDarkMode;
  const ThemeController({super.key, required this.darkMode, required this.setDarkMode, required super.child});

  static ThemeController of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeController>()!;
  }

  @override
  bool updateShouldNotify(ThemeController oldWidget) => oldWidget.darkMode != darkMode;
}

/* =========================
   MODELS
========================= */

class CompanySettings {
  final String name, address, mobile, pinCode, gstin, email, pan;
  const CompanySettings({
    required this.name,
    required this.address,
    required this.mobile,
    required this.pinCode,
    required this.gstin,
    required this.email,
    required this.pan,
  });

  static const defaults = CompanySettings(
    name: 'SRI KESAR ENTERPRISES',
    address: 'Plot No.:2 Abhyudaya Nagar, Prashant Nagar Colony, kismatpur road, Bandlaguda Jagir, Telangana, Ghousepura Darussalam Road, Hyderabad. 500086',
    mobile: '+91 9347539805',
    pinCode: '500086',
    gstin: '36FSXPD2019G1ZL',
    email: 'kesar.bandlaguda2001@gmail.com',
    pan: '',
  );

  Map<String, dynamic> toJson() => {'name': name, 'address': address, 'mobile': mobile, 'pinCode': pinCode, 'gstin': gstin, 'email': email, 'pan': pan};

  factory CompanySettings.fromJson(Map<String, dynamic> j) => CompanySettings(
    name: j['name'] ?? defaults.name,
    address: j['address'] ?? defaults.address,
    mobile: j['mobile'] ?? defaults.mobile,
    pinCode: j['pinCode'] ?? defaults.pinCode,
    gstin: j['gstin'] ?? defaults.gstin,
    email: j['email'] ?? defaults.email,
    pan: j['pan'] ?? '',
  );
}

class Product {
  final int? id;
  final String name, hsn, unit, category;
  final double rate, gstPercent;

  const Product({this.id, required this.name, required this.hsn, required this.rate, required this.unit, required this.gstPercent, required this.category});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'hsn': hsn, 'rate': rate, 'unit': unit, 'gstPercent': gstPercent, 'category': category};

  factory Product.fromMap(Map<String, dynamic> m) => Product(
    id: m['id'],
    name: m['name'] ?? '',
    hsn: m['hsn'] ?? '',
    rate: (m['rate'] as num?)?.toDouble() ?? 0,
    unit: m['unit'] ?? 'Nos',
    gstPercent: (m['gstPercent'] as num?)?.toDouble() ?? 18,
    category: m['category'] ?? '',
  );
}

class Customer {
  final int? id;
  final String name, address, gstin, phone, email, pinCode, placeOfSupply;

  const Customer({this.id, required this.name, required this.address, required this.gstin, required this.phone, required this.email, required this.pinCode, required this.placeOfSupply});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'address': address, 'gstin': gstin, 'phone': phone, 'email': email, 'pinCode': pinCode, 'placeOfSupply': placeOfSupply};

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
    id: m['id'],
    name: m['name'] ?? '',
    address: m['address'] ?? '',
    gstin: m['gstin'] ?? '',
    phone: m['phone'] ?? '',
    email: m['email'] ?? '',
    pinCode: m['pinCode'] ?? '',
    placeOfSupply: m['placeOfSupply'] ?? 'Telangana',
  );
}

class InvoiceItem {
  String productName, hsn, unit;
  double quantity, rate, discountPercent, gstPercent;

  InvoiceItem({required this.productName, required this.hsn, required this.quantity, required this.unit, required this.rate, required this.discountPercent, required this.gstPercent});

  double get taxableAmount => quantity * rate * (1 - discountPercent / 100);
  double get taxAmount => taxableAmount * gstPercent / 100;

  Map<String, dynamic> toJson() => {'productName': productName, 'hsn': hsn, 'quantity': quantity, 'unit': unit, 'rate': rate, 'discountPercent': discountPercent, 'gstPercent': gstPercent};

  factory InvoiceItem.fromJson(Map<String, dynamic> j) => InvoiceItem(
    productName: j['productName'] ?? '',
    hsn: j['hsn'] ?? '',
    quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
    unit: j['unit'] ?? 'Nos',
    rate: (j['rate'] as num?)?.toDouble() ?? 0,
    discountPercent: (j['discountPercent'] as num?)?.toDouble() ?? 0,
    gstPercent: (j['gstPercent'] as num?)?.toDouble() ?? 18,
  );
}

class Invoice {
  final int? id;
  final String invoiceNo, supplierRef, buyerName, buyerAddress, buyerGstin, buyerPhone, buyerEmail, buyerPinCode, placeOfSupply, contactName;
  final String consigneeName, consigneeAddress, consigneeGstin, consigneePhone, consigneePinCode;
  final DateTime invoiceDate;
  final List<InvoiceItem> items;
  final String pdfPath;

  Invoice({
    this.id,
    required this.invoiceNo,
    required this.invoiceDate,
    required this.supplierRef,
    required this.buyerName,
    required this.buyerAddress,
    required this.buyerGstin,
    required this.buyerPhone,
    required this.buyerEmail,
    required this.buyerPinCode,
    required this.placeOfSupply,
    required this.contactName,
    required this.consigneeName,
    required this.consigneeAddress,
    required this.consigneeGstin,
    required this.consigneePhone,
    required this.consigneePinCode,
    required this.items,
    this.pdfPath = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'invoiceNo': invoiceNo,
    'invoiceDate': invoiceDate.toIso8601String(),
    'supplierRef': supplierRef,
    'buyerName': buyerName,
    'buyerAddress': buyerAddress,
    'buyerGstin': buyerGstin,
    'buyerPhone': buyerPhone,
    'buyerEmail': buyerEmail,
    'buyerPinCode': buyerPinCode,
    'placeOfSupply': placeOfSupply,
    'contactName': contactName,
    'consigneeName': consigneeName,
    'consigneeAddress': consigneeAddress,
    'consigneeGstin': consigneeGstin,
    'consigneePhone': consigneePhone,
    'consigneePinCode': consigneePinCode,
    'itemsJson': jsonEncode(items.map((e) => e.toJson()).toList()),
    'pdfPath': pdfPath,
    'updatedAt': DateTime.now().toIso8601String(),
  };

  factory Invoice.fromMap(Map<String, dynamic> m) {
    final raw = jsonDecode(m['itemsJson'] ?? '[]') as List;
    return Invoice(
      id: m['id'],
      invoiceNo: m['invoiceNo'] ?? '',
      invoiceDate: DateTime.tryParse(m['invoiceDate'] ?? '') ?? DateTime.now(),
      supplierRef: m['supplierRef'] ?? '',
      buyerName: m['buyerName'] ?? '',
      buyerAddress: m['buyerAddress'] ?? '',
      buyerGstin: m['buyerGstin'] ?? '',
      buyerPhone: m['buyerPhone'] ?? '',
      buyerEmail: m['buyerEmail'] ?? '',
      buyerPinCode: m['buyerPinCode'] ?? '',
      placeOfSupply: m['placeOfSupply'] ?? 'Telangana',
      contactName: m['contactName'] ?? '',
      consigneeName: m['consigneeName'] ?? '',
      consigneeAddress: m['consigneeAddress'] ?? '',
      consigneeGstin: m['consigneeGstin'] ?? '',
      consigneePhone: m['consigneePhone'] ?? '',
      consigneePinCode: m['consigneePinCode'] ?? '',
      items: raw.map((e) => InvoiceItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      pdfPath: m['pdfPath'] ?? '',
    );
  }
}

class InvoiceTotals {
  final double taxable, cgst, sgst, igst, roundOff, grandTotal;
  final List<HsnTax> hsn;
  const InvoiceTotals({required this.taxable, required this.cgst, required this.sgst, required this.igst, required this.roundOff, required this.grandTotal, required this.hsn});
  double get totalTax => cgst + sgst + igst;
}

class HsnTax {
  final String hsn;
  final double taxable, gst, cgst, sgst, igst;
  const HsnTax({required this.hsn, required this.taxable, required this.gst, required this.cgst, required this.sgst, required this.igst});
  double get totalTax => cgst + sgst + igst;
}

enum InvoiceOrientation { auto, portrait, landscape }
enum InvoicePageSize { a4, letter, legal }

class PrintSettings {
  final InvoiceOrientation orientation;
  final InvoicePageSize pageSize;
  final double marginMm;
  const PrintSettings({this.orientation = InvoiceOrientation.auto, this.pageSize = InvoicePageSize.a4, this.marginMm = 8});

  PdfPageFormat get baseFormat {
    switch (pageSize) {
      case InvoicePageSize.letter:
        return PdfPageFormat.letter;
      case InvoicePageSize.legal:
        return PdfPageFormat.legal;
      case InvoicePageSize.a4:
        return PdfPageFormat.a4;
    }
  }
}

/* =========================
   DATABASE + SERVICES
========================= */

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();
  late Database db;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    db = await openDatabase(p.join(dbPath, 'sri_kesar_enterprise_billing.db'), version: 1, onCreate: _create);
    await _seed();
  }

  Future<void> _create(Database db, int v) async {
    await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await db.execute('CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, hsn TEXT NOT NULL, rate REAL NOT NULL, unit TEXT NOT NULL, gstPercent REAL NOT NULL, category TEXT)');
    await db.execute('CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, address TEXT, gstin TEXT, phone TEXT, email TEXT, pinCode TEXT, placeOfSupply TEXT)');
    await db.execute('CREATE TABLE invoices(id INTEGER PRIMARY KEY AUTOINCREMENT, invoiceNo TEXT NOT NULL UNIQUE, invoiceDate TEXT NOT NULL, supplierRef TEXT, buyerName TEXT, buyerAddress TEXT, buyerGstin TEXT, buyerPhone TEXT, buyerEmail TEXT, buyerPinCode TEXT, placeOfSupply TEXT, contactName TEXT, consigneeName TEXT, consigneeAddress TEXT, consigneeGstin TEXT, consigneePhone TEXT, consigneePinCode TEXT, itemsJson TEXT NOT NULL, pdfPath TEXT, updatedAt TEXT)');
    await db.execute('CREATE TABLE drafts(id INTEGER PRIMARY KEY, invoiceJson TEXT NOT NULL, updatedAt TEXT NOT NULL)');
  }

  Future<void> _seed() async {
    if (await getSetting('invoiceSeq') == null) await setSetting('invoiceSeq', '165');
    if (await getSetting('company') == null) await setSetting('company', jsonEncode(CompanySettings.defaults.toJson()));
    final pc = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products')) ?? 0;
    if (pc == 0) {
      final data = [
        Product(name: 'D-Link CAT-6 cable', hsn: '8544', rate: 10000, unit: 'Nos', gstPercent: 18, category: 'Networking'),
        Product(name: '6M plate / 6 module plate, Roma type', hsn: '8538', rate: 170, unit: 'Nos', gstPercent: 18, category: 'Electrical'),
        Product(name: '6A switch', hsn: '8536', rate: 35, unit: 'Nos', gstPercent: 18, category: 'Electrical'),
        Product(name: '6A socket', hsn: '8536', rate: 93, unit: 'Nos', gstPercent: 18, category: 'Electrical'),
        Product(name: '1M plate / 1 module plate', hsn: '8538', rate: 82, unit: 'Nos', gstPercent: 18, category: 'Electrical'),
        Product(name: 'Self thread screws', hsn: '7318', rate: 700, unit: 'Box', gstPercent: 18, category: 'Hardware'),
        Product(name: 'Dowel numbers / rawl plug packet', hsn: '3926', rate: 460, unit: 'Pkt', gstPercent: 18, category: 'Hardware'),
        Product(name: 'PVC casing 150/50 mm', hsn: '3917', rate: 1350, unit: 'Nos', gstPercent: 18, category: 'Electrical'),
        Product(name: '2.5 sq.mm wire - Red', hsn: '8544', rate: 4010, unit: 'Bdl', gstPercent: 18, category: 'Wire'),
        Product(name: '2.5 sq.mm wire - Black', hsn: '8544', rate: 4010, unit: 'Bdl', gstPercent: 18, category: 'Wire'),
        Product(name: '1.5 sq.mm wire - Green', hsn: '8544', rate: 2630, unit: 'Bdl', gstPercent: 18, category: 'Wire'),
      ];
      for (final item in data) {
        await saveProduct(item);
      }
    }
    final cc = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM customers')) ?? 0;
    if (cc == 0) {
      await saveCustomer(const Customer(
        name: "St Joseph's Degree & Pg College",
        address: '5-9-1106, King Kothi, Gunfoundary, Hyd',
        gstin: 'URP',
        phone: '',
        email: '',
        pinCode: '500029',
        placeOfSupply: 'Telangana',
      ));
    }
  }

  Future<String?> getSetting(String key) async {
    final rows = await db.query('settings', where: 'key=?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<CompanySettings> company() async {
    final raw = await getSetting('company');
    if (raw == null) return CompanySettings.defaults;
    return CompanySettings.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
  }

  Future<void> saveCompany(CompanySettings company) => setSetting('company', jsonEncode(company.toJson()));

  Future<String> nextInvoiceNo() async {
    final seq = int.tryParse(await getSetting('invoiceSeq') ?? '165') ?? 165;
    return 'K/${seq + 1}';
  }

  Future<void> _updateSeq(String invoiceNo) async {
    final n = int.tryParse(invoiceNo.split('/').last) ?? 0;
    final old = int.tryParse(await getSetting('invoiceSeq') ?? '165') ?? 165;
    if (n > old) await setSetting('invoiceSeq', n.toString());
  }

  Future<List<Product>> products({String q = ''}) async {
    final maps = await db.query('products', where: q.isEmpty ? null : 'name LIKE ? OR hsn LIKE ? OR category LIKE ?', whereArgs: q.isEmpty ? null : ['%$q%', '%$q%', '%$q%'], orderBy: 'name ASC');
    return maps.map(Product.fromMap).toList();
  }

  Future<void> saveProduct(Product product) async => db.insert('products', product.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> deleteProduct(int id) async => db.delete('products', where: 'id=?', whereArgs: [id]);

  Future<List<Customer>> customers({String q = ''}) async {
    final maps = await db.query('customers', where: q.isEmpty ? null : 'name LIKE ? OR gstin LIKE ? OR phone LIKE ?', whereArgs: q.isEmpty ? null : ['%$q%', '%$q%', '%$q%'], orderBy: 'name ASC');
    return maps.map(Customer.fromMap).toList();
  }

  Future<void> saveCustomer(Customer c) async => db.insert('customers', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> deleteCustomer(int id) async => db.delete('customers', where: 'id=?', whereArgs: [id]);

  Future<List<Invoice>> invoices({String q = ''}) async {
    final maps = await db.query('invoices', where: q.isEmpty ? null : 'invoiceNo LIKE ? OR buyerName LIKE ? OR buyerGstin LIKE ?', whereArgs: q.isEmpty ? null : ['%$q%', '%$q%', '%$q%'], orderBy: 'invoiceDate DESC, id DESC');
    return maps.map(Invoice.fromMap).toList();
  }

  Future<void> saveInvoice(Invoice invoice) async {
    await db.insert('invoices', invoice.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await _updateSeq(invoice.invoiceNo);
    if (invoice.buyerName.trim().isNotEmpty) {
      await saveCustomer(Customer(name: invoice.buyerName, address: invoice.buyerAddress, gstin: invoice.buyerGstin, phone: invoice.buyerPhone, email: invoice.buyerEmail, pinCode: invoice.buyerPinCode, placeOfSupply: invoice.placeOfSupply));
    }
  }

  Future<void> deleteInvoice(int id) async => db.delete('invoices', where: 'id=?', whereArgs: [id]);

  Future<void> saveDraft(Invoice invoice) async {
    await db.insert('drafts', {'id': 1, 'invoiceJson': jsonEncode(invoice.toMap()), 'updatedAt': DateTime.now().toIso8601String()}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Invoice?> loadDraft() async {
    final rows = await db.query('drafts', where: 'id=?', whereArgs: [1], limit: 1);
    if (rows.isEmpty) return null;
    return Invoice.fromMap(Map<String, dynamic>.from(jsonDecode(rows.first['invoiceJson'] as String)));
  }

  Future<String> backupJson() async {
    final data = {
      'settings': await db.query('settings'),
      'products': await db.query('products'),
      'customers': await db.query('customers'),
      'invoices': await db.query('invoices'),
      'exportedAt': DateTime.now().toIso8601String(),
    };
    return jsonEncode(data);
  }
}

class AuthService {
  static const storage = FlutterSecureStorage();
  static final localAuth = LocalAuthentication();

  static Future<void> ensureDefaults() async {
    await storage.write(key: 'adminPassword', value: await storage.read(key: 'adminPassword') ?? 'admin123');
    await storage.write(key: 'pin', value: await storage.read(key: 'pin') ?? '1234');
  }

  static Future<bool> password(String pass) async {
    await ensureDefaults();
    return pass == await storage.read(key: 'adminPassword');
  }

  static Future<bool> pin(String pin) async {
    await ensureDefaults();
    return pin == await storage.read(key: 'pin');
  }

  static Future<bool> biometrics() async {
    final ok = await localAuth.canCheckBiometrics || await localAuth.isDeviceSupported();
    if (!ok) return false;
    return localAuth.authenticate(localizedReason: 'Unlock Sri Kesar Billing App', options: const AuthenticationOptions(stickyAuth: true));
  }
}

class GstEngine {
  static InvoiceTotals calculate(Invoice invoice) {
    final intra = invoice.placeOfSupply.toLowerCase().contains('telangana');
    var taxable = 0.0, cgst = 0.0, sgst = 0.0, igst = 0.0;
    final map = <String, _Agg>{};

    for (final item in invoice.items) {
      final amount = item.taxableAmount;
      final tax = amount * item.gstPercent / 100;
      taxable += amount;

      if (intra) {
        cgst += tax / 2;
        sgst += tax / 2;
      } else {
        igst += tax;
      }

      final key = '${item.hsn}|${item.gstPercent}';
      map.putIfAbsent(key, () => _Agg(item.hsn, item.gstPercent));
      final a = map[key]!;
      a.taxable += amount;
      if (intra) {
        a.cgst += tax / 2;
        a.sgst += tax / 2;
      } else {
        a.igst += tax;
      }
    }

    final gross = taxable + cgst + sgst + igst;
    final total = gross.roundToDouble();
    return InvoiceTotals(
      taxable: taxable,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      roundOff: total - gross,
      grandTotal: total,
      hsn: map.values.map((e) => HsnTax(hsn: e.hsn, taxable: e.taxable, gst: e.gst, cgst: e.cgst, sgst: e.sgst, igst: e.igst)).toList()..sort((a, b) => a.hsn.compareTo(b.hsn)),
    );
  }
}

class _Agg {
  final String hsn;
  final double gst;
  double taxable = 0, cgst = 0, sgst = 0, igst = 0;
  _Agg(this.hsn, this.gst);
}

class NumberWords {
  static const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
  static const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

  static String rupees(num v) {
    var n = v.round();
    if (n == 0) return 'Zero';
    String two(int x) => x < 20 ? ones[x] : '${tens[x ~/ 10]}${x % 10 > 0 ? ' ${ones[x % 10]}' : ''}';
    String three(int x) => '${x ~/ 100 > 0 ? '${ones[x ~/ 100]} Hundred ' : ''}${x % 100 > 0 ? two(x % 100) : ''}';
    final crore = n ~/ 10000000; n %= 10000000;
    final lakh = n ~/ 100000; n %= 100000;
    final thousand = n ~/ 1000; n %= 1000;
    final parts = <String>[];
    if (crore > 0) parts.add('${three(crore)} Crore');
    if (lakh > 0) parts.add('${three(lakh)} Lakh');
    if (thousand > 0) parts.add('${three(thousand)} Thousand');
    if (n > 0) parts.add(three(n));
    return parts.join(' ').trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}

class PdfEngine {
  static Future<Uint8List> invoicePdf(Invoice invoice, CompanySettings company, PrintSettings settings) async {
    final pdf = pw.Document();
    final logoBytes = await rootBundle.load('assets/images/sri_kesar_logo.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
    final totals = GstEngine.calculate(invoice);
    var format = settings.baseFormat;
    final resolved = _orientation(invoice, settings);
    if (resolved == InvoiceOrientation.landscape) format = format.landscape;
    final margin = settings.marginMm * PdfPageFormat.mm;
    final tableFont = resolved == InvoiceOrientation.landscape ? 7.8 : 7.0;

    pdf.addPage(pw.MultiPage(
      pageFormat: format,
      margin: pw.EdgeInsets.all(margin),
      header: (context) => _invoiceHeader(invoice, company, logo),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
      ),
      build: (_) => [
        _parties(invoice),
        pw.SizedBox(height: 5),
        _items(invoice, tableFont),
        pw.SizedBox(height: 6),
        _totals(totals),
        pw.SizedBox(height: 4),
        _words(totals),
        pw.SizedBox(height: 6),
        _taxSummary(totals),
        pw.SizedBox(height: 4),
        pw.Text('Tax Amount (in words)', style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Indian Rupee ${NumberWords.rupees(totals.totalTax)} Only', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        _line("Company's GST No. : ${company.gstin}"),
        _line("Company's PAN : ${company.pan}"),
        _declaration(company),
        pw.Center(child: pw.Text('This is a Computer Generated Invoice', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 8))),
      ],
    ));

    return pdf.save();
  }

  static InvoiceOrientation _orientation(Invoice invoice, PrintSettings settings) {
    if (settings.orientation != InvoiceOrientation.auto) return settings.orientation;
    final maxName = invoice.items.fold<int>(0, (m, e) => e.productName.length > m ? e.productName.length : m);
    return maxName > 55 ? InvoiceOrientation.landscape : InvoiceOrientation.portrait;
  }

  static String fileName(Invoice invoice) {
    final buyer = invoice.buyerName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final inv = invoice.invoiceNo.replaceAll('/', '');
    final date = DateFormat('ddMMMyyyy').format(invoice.invoiceDate);
    return '${buyer.isEmpty ? 'Invoice' : buyer}_${inv}_$date.pdf';
  }

  static pw.Widget _invoiceHeader(Invoice invoice, CompanySettings c, pw.ImageProvider logo) {
    final meta = [
      ['Invoice No.', invoice.invoiceNo],
      ['Dated', DateFormat('dd MMM yy').format(invoice.invoiceDate).toUpperCase()],
      ['Delivery Note', ''],
      ['Mode/Terms of Payment', ''],
      ["Supplier's Ref", invoice.supplierRef],
      ['Other Reference(s)', ''],
      ['Buyers Order No.', ''],
      ['Dated', ''],
      ['Despatch Doc No.', ''],
      ['Delivery Note Date', ''],
      ['Despatched through', ''],
      ['Destination', ''],
      ['Terms of Delivery', ''],
    ];
    return pw.Column(children: [
      pw.Center(child: pw.Text('TAX INVOICE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15))),
      pw.SizedBox(height: 3),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Container(
          height: 116,
          padding: const pw.EdgeInsets.all(5),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: .8)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Image(logo, width: 120, height: 30, fit: pw.BoxFit.contain),
            pw.Text(c.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
            pw.Text(c.address, style: const pw.TextStyle(fontSize: 7.2)),
            pw.Text('Mobile no. : ${c.mobile}', style: const pw.TextStyle(fontSize: 7.2)),
            pw.Text('Pin code : ${c.pinCode}', style: const pw.TextStyle(fontSize: 7.2)),
            pw.Text('GSTIN : ${c.gstin}', style: const pw.TextStyle(fontSize: 7.2)),
            pw.Text('E-Mail : ${c.email}', style: const pw.TextStyle(fontSize: 7.2)),
          ]),
        )),
        pw.Expanded(child: pw.Table(
          border: pw.TableBorder.all(width: .8),
          children: meta.map((r) => pw.TableRow(children: [_cell(r[0], bold: true), _cell(r[1], bold: true)])).toList(),
        )),
      ]),
    ]);
  }

  static pw.Widget _parties(Invoice i) => pw.Table(border: pw.TableBorder.all(width: .8), children: [
    pw.TableRow(children: [
      pw.Column(children: [
        _party('Consignee', i.consigneeName, i.consigneeAddress, i.consigneePinCode, i.consigneeGstin),
        _party('Buyer', i.buyerName, i.buyerAddress, i.buyerPinCode, i.buyerGstin, extra: 'Place of supply : ${i.placeOfSupply}\nContact Name : ${i.contactName}'),
      ]),
      pw.Container(height: 120),
    ]),
  ]);

  static pw.Widget _party(String title, String name, String address, String pin, String gst, {String extra = ''}) => pw.Container(
    height: 60,
    width: double.infinity,
    padding: const pw.EdgeInsets.all(5),
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: .8))),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
      pw.Text(name, style: const pw.TextStyle(fontSize: 7.3)),
      pw.Text(address, style: const pw.TextStyle(fontSize: 7.3)),
      if (pin.isNotEmpty) pw.Text('Pincode : $pin', style: const pw.TextStyle(fontSize: 7.3)),
      pw.Text('GSTIN/UIN : $gst', style: const pw.TextStyle(fontSize: 7.3)),
      if (extra.isNotEmpty) pw.Text(extra, style: const pw.TextStyle(fontSize: 7.3)),
    ]),
  );

  static pw.Widget _items(Invoice invoice, double fontSize) {
    final data = invoice.items.asMap().entries.map((e) {
      final i = e.key;
      final item = e.value;
      return ['${i + 1}', item.productName, item.hsn, item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2), item.rate.toStringAsFixed(0), item.unit, item.discountPercent == 0 ? '' : item.discountPercent.toStringAsFixed(2), item.taxableAmount.toStringAsFixed(2)];
    }).toList();

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(width: .7),
      headers: const ['S.No.', 'Description of Goods/Services', 'HSN/SAC', 'Qty', 'Rate', 'per', 'Disc. %', 'Amount'],
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fontSize),
      cellStyle: pw.TextStyle(fontSize: fontSize),
      headerAlignment: pw.Alignment.center,
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: const {
        0: pw.FixedColumnWidth(30),
        1: pw.FlexColumnWidth(3),
        2: pw.FixedColumnWidth(50),
        3: pw.FixedColumnWidth(36),
        4: pw.FixedColumnWidth(48),
        5: pw.FixedColumnWidth(35),
        6: pw.FixedColumnWidth(42),
        7: pw.FixedColumnWidth(58),
      },
    );
  }

  static pw.Widget _totals(InvoiceTotals t) {
    final rows = [
      ['Subtotal', t.taxable],
      ['CGST', t.cgst],
      ['SGST', t.sgst],
      if (t.igst > 0) ['IGST', t.igst],
      ['Rounding Off', t.roundOff],
      ['Total', t.grandTotal],
    ];
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(width: 220, child: pw.Table(
        border: pw.TableBorder.all(width: .7),
        children: rows.map((r) => pw.TableRow(children: [
          _cell(r[0] as String, bold: true, align: pw.TextAlign.right),
          _cell((r[1] as double).toStringAsFixed(r[0] == 'Total' ? 0 : 2), bold: true, align: pw.TextAlign.right),
        ])).toList(),
      )),
    );
  }

  static pw.Widget _words(InvoiceTotals t) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(5),
    decoration: pw.BoxDecoration(border: pw.Border.all(width: .7)),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('Amount Chargeable (in words)', style: const pw.TextStyle(fontSize: 8)),
      pw.Text('Indian Rupee ${NumberWords.rupees(t.grandTotal)} Only', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
    ]),
  );

  static pw.Widget _taxSummary(InvoiceTotals t) {
    final data = t.hsn.map((e) => [e.hsn, e.taxable.toStringAsFixed(2), '${(e.gst / 2).toStringAsFixed(0)}%', e.cgst.toStringAsFixed(2), '${(e.gst / 2).toStringAsFixed(0)}%', e.sgst.toStringAsFixed(2), e.totalTax.toStringAsFixed(2)]).toList();
    data.add(['Total', t.taxable.toStringAsFixed(2), '', t.cgst.toStringAsFixed(2), '', t.sgst.toStringAsFixed(2), t.totalTax.toStringAsFixed(2)]);
    return pw.Column(children: [
      pw.Container(width: double.infinity, alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(4), decoration: pw.BoxDecoration(border: pw.Border.all(width: .7)), child: pw.Text('HSN TAX SUMMARY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
      pw.TableHelper.fromTextArray(
        border: pw.TableBorder.all(width: .7),
        headers: const ['HSN/SAC', 'Taxable Value', 'Central Tax Rate', 'Central Tax Amount', 'State Tax Rate', 'State Tax Amount', 'Total Tax Amount'],
        data: data,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.6),
        cellStyle: const pw.TextStyle(fontSize: 6.6),
        headerAlignment: pw.Alignment.center,
      ),
    ]);
  }

  static pw.Widget _declaration(CompanySettings c) => pw.Table(
    border: pw.TableBorder.all(width: .8),
    children: [pw.TableRow(children: [
      pw.Container(height: 70, padding: const pw.EdgeInsets.all(5), child: pw.Text('Declaration\nWe declare that this invoice shows the actual price of the goods described and that all particulars are true and correct', style: const pw.TextStyle(fontSize: 8))),
      pw.Container(height: 70, padding: const pw.EdgeInsets.all(5), alignment: pw.Alignment.centerRight, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Text('for ${c.name}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
        pw.Spacer(),
        pw.Text('Authorised Signatory', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
      ])),
    ])],
  );

  static pw.Widget _line(String text) => pw.Container(width: double.infinity, padding: const pw.EdgeInsets.all(4), decoration: pw.BoxDecoration(border: pw.Border.all(width: .7)), child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)));

  static pw.Widget _cell(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
    padding: const pw.EdgeInsets.all(3),
    child: pw.Text(text, textAlign: align, style: pw.TextStyle(fontSize: 7.2, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
  );
}

class FileService {
  static Future<File> savePdf(Uint8List bytes, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/Sri Kesar Enterprises/Invoices');
    if (!await folder.exists()) await folder.create(recursive: true);
    final file = File('${folder.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> open(File file) => OpenFilex.open(file.path);
  static Future<void> sharePdf(Uint8List bytes, String fileName) => Printing.sharePdf(bytes: bytes, filename: fileName);
}

class GoogleDriveService {
  final signIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);

  Future<drive.DriveApi?> api() async {
    final acc = signIn.currentUser ?? await signIn.signInSilently() ?? await signIn.signIn();
    if (acc == null) return null;
    return drive.DriveApi(_AuthClient(await acc.authHeaders));
  }

  Future<String?> upload(File file, DateTime date) async {
    final d = await api();
    if (d == null) return null;
    final root = await _folder(d, 'Sri Kesar Enterprises', null);
    final year = await _folder(d, '${date.year}', root);
    final month = await _folder(d, DateFormat('MMMM').format(date), year);
    final invoices = await _folder(d, 'Invoices', month);
    final media = drive.Media(file.openRead(), await file.length());
    final f = drive.File()..name = p.basename(file.path)..parents = [invoices];
    final uploaded = await d.files.create(f, uploadMedia: media);
    return uploaded.id;
  }

  Future<String> _folder(drive.DriveApi api, String name, String? parent) async {
    final parentQ = parent == null ? '' : " and '$parent' in parents";
    final res = await api.files.list(q: "mimeType='application/vnd.google-apps.folder' and name='$name' and trashed=false$parentQ");
    if ((res.files ?? []).isNotEmpty) return res.files!.first.id!;
    final f = drive.File()..name = name..mimeType = 'application/vnd.google-apps.folder'..parents = parent == null ? null : [parent];
    return (await api.files.create(f)).id!;
  }
}

class _AuthClient extends http.BaseClient {
  final Map<String, String> headers;
  final http.Client inner = http.Client();
  _AuthClient(this.headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(headers);
    return inner.send(request);
  }
}

/* =========================
   SCREENS
========================= */

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final password = TextEditingController();
  final pin = TextEditingController();

  Future<void> _goIf(bool ok) async {
    if (ok && mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login failed')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: Card(child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/images/sri_kesar_logo.png', height: 72),
          const SizedBox(height: 14),
          Text('SRI KESAR ENTERPRISES', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const Text('Smart Billing & Invoice Management App'),
          const SizedBox(height: 22),
          TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Admin Password')),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () async => _goIf(await AuthService.password(password.text.trim())), icon: const Icon(Icons.lock_open), label: const Text('Login'))),
          const Divider(height: 30),
          TextField(controller: pin, maxLength: 4, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN')),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () async => _goIf(await AuthService.pin(pin.text.trim())), icon: const Icon(Icons.pin), label: const Text('PIN'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: () async => _goIf(await AuthService.biometrics()), icon: const Icon(Icons.fingerprint), label: const Text('Biometric'))),
          ]),
          const SizedBox(height: 8),
          const Text('Default Password: admin123 | Default PIN: 1234', style: TextStyle(fontSize: 11)),
        ]),
      ))),
    ))));
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double today = 0, month = 0;
  int invoiceCount = 0;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final invoices = await AppDb.instance.invoices();
    final now = DateTime.now();
    today = 0; month = 0; invoiceCount = invoices.length;
    for (final inv in invoices) {
      final total = GstEngine.calculate(inv).grandTotal;
      if (DateUtils.isSameDay(inv.invoiceDate, now)) today += total;
      if (inv.invoiceDate.year == now.year && inv.invoiceDate.month == now.month) month += total;
    }
    setState(() {});
  }

  void open(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w)).then((_) => load());

  @override
  Widget build(BuildContext context) {
    final items = [
      _Dash('Start Billing', Icons.receipt_long, () => open(const BillingScreen())),
      _Dash('Invoice History', Icons.history, () => open(const HistoryScreen())),
      _Dash('Customers', Icons.people, () => open(const CustomersScreen())),
      _Dash('Products', Icons.inventory_2, () => open(const ProductsScreen())),
      _Dash('Reports', Icons.bar_chart, () => open(const ReportsScreen())),
      _Dash('Settings', Icons.settings, () => open(const SettingsScreen())),
    ];
    return Scaffold(appBar: AppBar(title: const Text('Sri Kesar Billing')), body: RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Image.asset('assets/images/sri_kesar_logo.png', height: 54),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SRI KESAR ENTERPRISES', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Text('Professional Mobile Billing System'),
          ])),
        ]))),
        Row(children: [Expanded(child: _Metric('Today', today)), const SizedBox(width: 8), Expanded(child: _Metric('Month', month))]),
        Row(children: [Expanded(child: _Metric('Invoices', invoiceCount.toDouble(), money: false)), const SizedBox(width: 8), const Expanded(child: _StatusMetric())]),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.of(context).size.width > 650 ? 3 : 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: items.map((e) => Card(child: InkWell(borderRadius: BorderRadius.circular(18), onTap: e.onTap, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(e.icon, size: 38),
            const SizedBox(height: 10),
            Text(e.label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ])))).toList(),
        ),
      ]),
    ));
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final double value;
  final bool money;
  const _Metric(this.label, this.value, {this.money = true});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label),
    Text(money ? '₹${value.toStringAsFixed(0)}' : value.toStringAsFixed(0), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
  ])));
}

class _StatusMetric extends StatelessWidget {
  const _StatusMetric();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Drive Status'),
    Text('Ready', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
  ])));
}

class _Dash {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _Dash(this.label, this.icon, this.onTap);
}

class BillingScreen extends StatefulWidget {
  final Invoice? invoice;
  const BillingScreen({super.key, this.invoice});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final invoiceNo = TextEditingController();
  final supplierRef = TextEditingController();
  final buyerName = TextEditingController();
  final buyerAddress = TextEditingController();
  final buyerGstin = TextEditingController();
  final buyerPhone = TextEditingController();
  final buyerEmail = TextEditingController();
  final buyerPin = TextEditingController();
  final place = TextEditingController(text: 'Telangana');
  final contact = TextEditingController();
  final consigneeName = TextEditingController();
  final consigneeAddress = TextEditingController();
  final consigneeGstin = TextEditingController();
  final consigneePhone = TextEditingController();
  final consigneePin = TextEditingController();

  List<Product> products = [];
  List<Customer> customers = [];
  List<InvoiceItem> items = [];
  DateTime date = DateTime.now();
  CompanySettings company = CompanySettings.defaults;
  PrintSettings printSettings = const PrintSettings();
  Timer? draftTimer;

  @override
  void initState() { super.initState(); init(); }

  Future<void> init() async {
    products = await AppDb.instance.products();
    customers = await AppDb.instance.customers();
    company = await AppDb.instance.company();
    if (widget.invoice != null) {
      loadInvoice(widget.invoice!);
    } else {
      final draft = await AppDb.instance.loadDraft();
      if (draft != null) {
        loadInvoice(draft);
      } else {
        invoiceNo.text = await AppDb.instance.nextInvoiceNo();
        supplierRef.text = invoiceNo.text.split('/').last;
        items = [emptyItem()];
      }
    }
    setState(() {});
  }

  InvoiceItem emptyItem() => InvoiceItem(productName: '', hsn: '', quantity: 1, unit: 'Nos', rate: 0, discountPercent: 0, gstPercent: 18);

  void loadInvoice(Invoice inv) {
    invoiceNo.text = inv.invoiceNo; supplierRef.text = inv.supplierRef; date = inv.invoiceDate;
    buyerName.text = inv.buyerName; buyerAddress.text = inv.buyerAddress; buyerGstin.text = inv.buyerGstin; buyerPhone.text = inv.buyerPhone; buyerEmail.text = inv.buyerEmail; buyerPin.text = inv.buyerPinCode; place.text = inv.placeOfSupply; contact.text = inv.contactName;
    consigneeName.text = inv.consigneeName; consigneeAddress.text = inv.consigneeAddress; consigneeGstin.text = inv.consigneeGstin; consigneePhone.text = inv.consigneePhone; consigneePin.text = inv.consigneePinCode;
    items = inv.items.isEmpty ? [emptyItem()] : List.of(inv.items);
  }

  Invoice invoice({String pdfPath = ''}) => Invoice(
    invoiceNo: invoiceNo.text.trim(),
    invoiceDate: date,
    supplierRef: supplierRef.text.trim(),
    buyerName: buyerName.text.trim(),
    buyerAddress: buyerAddress.text.trim(),
    buyerGstin: buyerGstin.text.trim(),
    buyerPhone: buyerPhone.text.trim(),
    buyerEmail: buyerEmail.text.trim(),
    buyerPinCode: buyerPin.text.trim(),
    placeOfSupply: place.text.trim(),
    contactName: contact.text.trim(),
    consigneeName: consigneeName.text.trim(),
    consigneeAddress: consigneeAddress.text.trim(),
    consigneeGstin: consigneeGstin.text.trim(),
    consigneePhone: consigneePhone.text.trim(),
    consigneePinCode: consigneePin.text.trim(),
    items: items.where((e) => e.productName.trim().isNotEmpty).toList(),
    pdfPath: pdfPath,
  );

  void changed() {
    setState(() {});
    draftTimer?.cancel();
    draftTimer = Timer(const Duration(milliseconds: 650), () => AppDb.instance.saveDraft(invoice()));
  }

  Future<void> save() async {
    final inv = invoice();
    if (inv.buyerName.isEmpty || inv.items.isEmpty) return snack('Enter buyer and product.');
    await AppDb.instance.saveInvoice(inv);
    snack('Invoice saved.');
  }

  Future<File?> makePdf({bool preview = false, bool share = false, bool upload = false}) async {
    final inv = invoice();
    if (inv.buyerName.isEmpty || inv.items.isEmpty) { snack('Enter buyer and product.'); return null; }
    final bytes = await PdfEngine.invoicePdf(inv, company, printSettings);
    final filename = PdfEngine.fileName(inv);
    if (preview) { await Printing.layoutPdf(onLayout: (_) async => bytes); return null; }
    final file = await FileService.savePdf(bytes, filename);
    await AppDb.instance.saveInvoice(invoice(pdfPath: file.path));
    if (share) await Share.shareXFiles([XFile(file.path)], text: 'Sri Kesar Enterprises Invoice ${inv.invoiceNo}');
    if (upload) {
      final id = await GoogleDriveService().upload(file, inv.invoiceDate);
      snack(id == null ? 'Google Drive upload cancelled or failed.' : 'Uploaded to Google Drive.');
    } else {
      snack('PDF saved: $filename');
    }
    return file;
  }

  void copyBuyer() {
    consigneeName.text = buyerName.text; consigneeAddress.text = buyerAddress.text; consigneeGstin.text = buyerGstin.text; consigneePhone.text = buyerPhone.text; consigneePin.text = buyerPin.text;
    changed();
  }

  void applyProduct(int i, Product p) {
    items[i].productName = p.name; items[i].hsn = p.hsn; items[i].rate = p.rate; items[i].unit = p.unit; items[i].gstPercent = p.gstPercent;
    changed();
  }

  Future<void> settingsSheet() async {
    var o = printSettings.orientation;
    var s = printSettings.pageSize;
    var m = printSettings.marginMm;
    final res = await showModalBottomSheet<PrintSettings>(context: context, showDragHandle: true, builder: (_) => StatefulBuilder(builder: (context, setSheet) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('PDF & Print Settings', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        DropdownButtonFormField(value: o, decoration: const InputDecoration(labelText: 'Orientation'), items: const [
          DropdownMenuItem(value: InvoiceOrientation.auto, child: Text('Auto Detect Best Layout')),
          DropdownMenuItem(value: InvoiceOrientation.portrait, child: Text('Portrait')),
          DropdownMenuItem(value: InvoiceOrientation.landscape, child: Text('Landscape')),
        ], onChanged: (v) => setSheet(() => o = v!)),
        const SizedBox(height: 10),
        DropdownButtonFormField(value: s, decoration: const InputDecoration(labelText: 'Page Size'), items: const [
          DropdownMenuItem(value: InvoicePageSize.a4, child: Text('A4')),
          DropdownMenuItem(value: InvoicePageSize.letter, child: Text('Letter')),
          DropdownMenuItem(value: InvoicePageSize.legal, child: Text('Legal')),
        ], onChanged: (v) => setSheet(() => s = v!)),
        const SizedBox(height: 10),
        Text('Margin: ${m.toStringAsFixed(0)} mm'),
        Slider(value: m, min: 4, max: 18, divisions: 14, onChanged: (v) => setSheet(() => m = v)),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, PrintSettings(orientation: o, pageSize: s, marginMm: m)), child: const Text('Apply'))),
      ]),
    )));
    if (res != null) setState(() => printSettings = res);
  }

  void snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final totals = GstEngine.calculate(invoice());
    return Scaffold(
      appBar: AppBar(title: const Text('Start Billing'), actions: [
        IconButton(onPressed: settingsSheet, icon: const Icon(Icons.tune)),
        IconButton(onPressed: () => makePdf(preview: true), icon: const Icon(Icons.preview)),
      ]),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        section('Invoice Details', [
          Row(children: [
            Expanded(child: TextField(controller: invoiceNo, decoration: const InputDecoration(labelText: 'Invoice No.'), onChanged: (_) => changed())),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: date); if (d != null) setState(() => date = d); }, icon: const Icon(Icons.calendar_month), label: Text(DateFormat('dd MMM yy').format(date)))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: supplierRef, decoration: const InputDecoration(labelText: 'Supplier Ref'), onChanged: (_) => changed()),
        ]),
        section('Buyer Details', [
          CustomerAuto(label: 'Buyer Name', controller: buyerName, customers: customers, onChanged: changed, onSelected: (c) { buyerName.text = c.name; buyerAddress.text = c.address; buyerGstin.text = c.gstin; buyerPhone.text = c.phone; buyerEmail.text = c.email; buyerPin.text = c.pinCode; place.text = c.placeOfSupply; contact.text = c.name; changed(); }),
          const SizedBox(height: 8),
          TextField(controller: buyerAddress, maxLines: 2, decoration: const InputDecoration(labelText: 'Address'), onChanged: (_) => changed()),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            field(buyerGstin, 'GST Number', 160),
            field(buyerPhone, 'Mobile', 150),
            field(buyerPin, 'Pincode', 130),
            field(place, 'Place of Supply', 180),
          ]),
        ]),
        section('Consignee Details', [
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: copyBuyer, child: const Text('Copy Buyer'))),
          CustomerAuto(label: 'Consignee Name', controller: consigneeName, customers: customers, onChanged: changed, onSelected: (c) { consigneeName.text = c.name; consigneeAddress.text = c.address; consigneeGstin.text = c.gstin; consigneePhone.text = c.phone; consigneePin.text = c.pinCode; changed(); }),
          const SizedBox(height: 8),
          TextField(controller: consigneeAddress, maxLines: 2, decoration: const InputDecoration(labelText: 'Address'), onChanged: (_) => changed()),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [field(consigneeGstin, 'GST Number', 160), field(consigneePhone, 'Mobile', 150), field(consigneePin, 'Pincode', 130)]),
        ]),
        section('Products / Items (${items.length})', [
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(onPressed: () => setState(() => items.add(emptyItem())), icon: const Icon(Icons.add), label: const Text('Add Row')),
            OutlinedButton.icon(onPressed: () => setState(() { for (var i = 0; i < 25; i++) { items.add(emptyItem()); } }), icon: const Icon(Icons.add_box), label: const Text('Add 25 Rows')),
          ]),
          const SizedBox(height: 8),
          ListView.builder(
            itemCount: items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_, i) => ItemCard(
              key: ValueKey(i),
              index: i,
              item: items[i],
              products: products,
              onChanged: changed,
              onProduct: (p) => applyProduct(i, p),
              onDelete: () => setState(() => items.removeAt(i)),
            ),
          ),
        ]),
        Card(color: Theme.of(context).colorScheme.primaryContainer, child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
          total('Taxable', totals.taxable),
          total('CGST', totals.cgst),
          total('SGST', totals.sgst),
          if (totals.igst > 0) total('IGST', totals.igst),
          total('Round Off', totals.roundOff),
          const Divider(),
          total('Grand Total', totals.grandTotal, bold: true),
        ]))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: save, icon: const Icon(Icons.save), label: const Text('Save')),
          FilledButton.icon(onPressed: () => makePdf(), icon: const Icon(Icons.picture_as_pdf), label: const Text('Generate PDF')),
          OutlinedButton.icon(onPressed: () => makePdf(preview: true), icon: const Icon(Icons.print), label: const Text('Print Preview')),
          OutlinedButton.icon(onPressed: () => makePdf(share: true), icon: const Icon(Icons.share), label: const Text('Share')),
          OutlinedButton.icon(onPressed: () => makePdf(upload: true), icon: const Icon(Icons.cloud_upload), label: const Text('Drive Upload')),
        ]),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget field(TextEditingController c, String label, double width) => SizedBox(width: width, child: TextField(controller: c, decoration: InputDecoration(labelText: label), onChanged: (_) => changed()));
  Widget total(String label, double value, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600))), Text('₹${value.toStringAsFixed(label == 'Grand Total' ? 0 : 2)}', style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, fontSize: bold ? 18 : null))]));
  Widget section(String title, List<Widget> children) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 10), ...children])));
}

class CustomerAuto extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final List<Customer> customers;
  final VoidCallback onChanged;
  final ValueChanged<Customer> onSelected;
  const CustomerAuto({super.key, required this.label, required this.controller, required this.customers, required this.onChanged, required this.onSelected});

  @override
  Widget build(BuildContext context) => Autocomplete<Customer>(
    displayStringForOption: (c) => c.name,
    optionsBuilder: (v) {
      final q = v.text.toLowerCase();
      return customers.where((c) => c.name.toLowerCase().contains(q) || c.gstin.toLowerCase().contains(q)).take(10);
    },
    onSelected: onSelected,
    fieldViewBuilder: (_, ctrl, focus, submit) {
      ctrl.text = controller.text;
      return TextField(controller: ctrl, focusNode: focus, decoration: InputDecoration(labelText: label), onChanged: (v) { controller.text = v; onChanged(); });
    },
  );
}

class ItemCard extends StatelessWidget {
  final int index;
  final InvoiceItem item;
  final List<Product> products;
  final VoidCallback onChanged;
  final ValueChanged<Product> onProduct;
  final VoidCallback onDelete;
  const ItemCard({super.key, required this.index, required this.item, required this.products, required this.onChanged, required this.onProduct, required this.onDelete});

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.45),
    child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Row(children: [
        CircleAvatar(radius: 14, child: Text('${index + 1}', style: const TextStyle(fontSize: 12))),
        const SizedBox(width: 8),
        Expanded(child: Text('Amount: ₹${item.taxableAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
        IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
      ]),
      Autocomplete<Product>(
        displayStringForOption: (p) => p.name,
        optionsBuilder: (v) {
          final q = v.text.toLowerCase();
          return products.where((p) => p.name.toLowerCase().contains(q) || p.hsn.contains(q)).take(12);
        },
        onSelected: onProduct,
        fieldViewBuilder: (_, ctrl, focus, submit) {
          ctrl.text = item.productName;
          return TextField(controller: ctrl, focusNode: focus, decoration: const InputDecoration(labelText: 'Product Name'), onChanged: (v) { item.productName = v; onChanged(); });
        },
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        mini('HSN/SAC', item.hsn, 115, (v) => item.hsn = v),
        mini('Qty', '${item.quantity}', 90, (v) => item.quantity = double.tryParse(v) ?? 0, number: true),
        mini('Unit', item.unit, 90, (v) => item.unit = v),
        mini('Rate', '${item.rate}', 110, (v) => item.rate = double.tryParse(v) ?? 0, number: true),
        mini('Disc %', '${item.discountPercent}', 95, (v) => item.discountPercent = double.tryParse(v) ?? 0, number: true),
        mini('GST %', '${item.gstPercent}', 90, (v) => item.gstPercent = double.tryParse(v) ?? 0, number: true),
      ]),
    ])),
  );

  Widget mini(String label, String value, double width, ValueChanged<String> set, {bool number = false}) => SizedBox(width: width, child: TextFormField(
    initialValue: value,
    keyboardType: number ? TextInputType.number : TextInputType.text,
    decoration: InputDecoration(labelText: label),
    onChanged: (v) { set(v); onChanged(); },
  ));
}

class ProductsScreen extends StatefulWidget { const ProductsScreen({super.key}); @override State<ProductsScreen> createState() => _ProductsScreenState(); }
class _ProductsScreenState extends State<ProductsScreen> {
  final search = TextEditingController();
  List<Product> products = [];
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { products = await AppDb.instance.products(q: search.text); setState(() {}); }

  Future<void> edit([Product? p]) async {
    final name = TextEditingController(text: p?.name ?? '');
    final hsn = TextEditingController(text: p?.hsn ?? '');
    final rate = TextEditingController(text: p?.rate.toString() ?? '');
    final unit = TextEditingController(text: p?.unit ?? 'Nos');
    final gst = TextEditingController(text: p?.gstPercent.toString() ?? '18');
    final cat = TextEditingController(text: p?.category ?? '');
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text(p == null ? 'Add Product' : 'Edit Product'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Product Name')), const SizedBox(height: 8),
      TextField(controller: hsn, decoration: const InputDecoration(labelText: 'HSN/SAC')), const SizedBox(height: 8),
      TextField(controller: rate, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rate')), const SizedBox(height: 8),
      TextField(controller: gst, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'GST %')), const SizedBox(height: 8),
      TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit')), const SizedBox(height: 8),
      TextField(controller: cat, decoration: const InputDecoration(labelText: 'Category')),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))]));
    if (ok == true) {
      await AppDb.instance.saveProduct(Product(id: p?.id, name: name.text.trim(), hsn: hsn.text.trim(), rate: double.tryParse(rate.text) ?? 0, unit: unit.text.trim(), gstPercent: double.tryParse(gst.text) ?? 18, category: cat.text.trim()));
      load();
    }
  }

  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Product Master'), actions: [IconButton(onPressed: () => edit(), icon: const Icon(Icons.add))]), body: Column(children: [
    Padding(padding: const EdgeInsets.all(14), child: TextField(controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search Products'), onChanged: (_) => load())),
    Expanded(child: ListView.builder(padding: const EdgeInsets.all(14), itemCount: products.length, itemBuilder: (_, i) {
      final p = products[i];
      return Card(child: ListTile(title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('HSN: ${p.hsn} | ₹${p.rate} | GST: ${p.gstPercent}% | Unit: ${p.unit}'), trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') edit(p); if (v == 'delete' && p.id != null) { await AppDb.instance.deleteProduct(p.id!); load(); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))])));
    })),
  ]));
}

class CustomersScreen extends StatefulWidget { const CustomersScreen({super.key}); @override State<CustomersScreen> createState() => _CustomersScreenState(); }
class _CustomersScreenState extends State<CustomersScreen> {
  final search = TextEditingController();
  List<Customer> customers = [];
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { customers = await AppDb.instance.customers(q: search.text); setState(() {}); }

  Future<void> edit([Customer? c]) async {
    final name = TextEditingController(text: c?.name ?? '');
    final address = TextEditingController(text: c?.address ?? '');
    final gstin = TextEditingController(text: c?.gstin ?? '');
    final phone = TextEditingController(text: c?.phone ?? '');
    final email = TextEditingController(text: c?.email ?? '');
    final pin = TextEditingController(text: c?.pinCode ?? '');
    final place = TextEditingController(text: c?.placeOfSupply ?? 'Telangana');
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text(c == null ? 'Add Customer' : 'Edit Customer'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Customer Name')), const SizedBox(height: 8),
      TextField(controller: address, maxLines: 3, decoration: const InputDecoration(labelText: 'Address')), const SizedBox(height: 8),
      TextField(controller: gstin, decoration: const InputDecoration(labelText: 'GST Number')), const SizedBox(height: 8),
      TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')), const SizedBox(height: 8),
      TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')), const SizedBox(height: 8),
      TextField(controller: pin, decoration: const InputDecoration(labelText: 'Pincode')), const SizedBox(height: 8),
      TextField(controller: place, decoration: const InputDecoration(labelText: 'Place of Supply')),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))]));
    if (ok == true) {
      await AppDb.instance.saveCustomer(Customer(id: c?.id, name: name.text.trim(), address: address.text.trim(), gstin: gstin.text.trim(), phone: phone.text.trim(), email: email.text.trim(), pinCode: pin.text.trim(), placeOfSupply: place.text.trim()));
      load();
    }
  }

  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Customer Management'), actions: [IconButton(onPressed: () => edit(), icon: const Icon(Icons.add))]), body: Column(children: [
    Padding(padding: const EdgeInsets.all(14), child: TextField(controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search Customers'), onChanged: (_) => load())),
    Expanded(child: ListView.builder(padding: const EdgeInsets.all(14), itemCount: customers.length, itemBuilder: (_, i) {
      final c = customers[i];
      return Card(child: ListTile(title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${c.address}\nGSTIN: ${c.gstin} | ${c.phone}'), isThreeLine: true, trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') edit(c); if (v == 'delete' && c.id != null) { await AppDb.instance.deleteCustomer(c.id!); load(); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))])));
    })),
  ]));
}

class HistoryScreen extends StatefulWidget { const HistoryScreen({super.key}); @override State<HistoryScreen> createState() => _HistoryScreenState(); }
class _HistoryScreenState extends State<HistoryScreen> {
  final search = TextEditingController();
  List<Invoice> invoices = [];
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { invoices = await AppDb.instance.invoices(q: search.text); setState(() {}); }

  Future<void> pdf(Invoice inv, {bool share = false}) async {
    final company = await AppDb.instance.company();
    final bytes = await PdfEngine.invoicePdf(inv, company, const PrintSettings());
    if (share) await FileService.sharePdf(bytes, PdfEngine.fileName(inv));
    else await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Invoice duplicate(Invoice inv) => Invoice(invoiceNo: 'K/${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}', invoiceDate: DateTime.now(), supplierRef: '', buyerName: inv.buyerName, buyerAddress: inv.buyerAddress, buyerGstin: inv.buyerGstin, buyerPhone: inv.buyerPhone, buyerEmail: inv.buyerEmail, buyerPinCode: inv.buyerPinCode, placeOfSupply: inv.placeOfSupply, contactName: inv.contactName, consigneeName: inv.consigneeName, consigneeAddress: inv.consigneeAddress, consigneeGstin: inv.consigneeGstin, consigneePhone: inv.consigneePhone, consigneePinCode: inv.consigneePinCode, items: inv.items.map((e) => InvoiceItem.fromJson(e.toJson())).toList());

  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Invoice History')), body: Column(children: [
    Padding(padding: const EdgeInsets.all(14), child: TextField(controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search invoice / buyer / GST'), onChanged: (_) => load())),
    Expanded(child: ListView.builder(padding: const EdgeInsets.all(14), itemCount: invoices.length, itemBuilder: (_, i) {
      final inv = invoices[i]; final t = GstEngine.calculate(inv);
      return Card(child: ListTile(title: Text('${inv.invoiceNo} • ${inv.buyerName}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${DateFormat('dd MMM yyyy').format(inv.invoiceDate)} | GSTIN: ${inv.buyerGstin} | ₹${t.grandTotal.toStringAsFixed(0)}'), trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') Navigator.push(context, MaterialPageRoute(builder: (_) => BillingScreen(invoice: inv))).then((_) => load()); if (v == 'print') pdf(inv); if (v == 'share') pdf(inv, share: true); if (v == 'duplicate') Navigator.push(context, MaterialPageRoute(builder: (_) => BillingScreen(invoice: duplicate(inv)))).then((_) => load()); if (v == 'delete' && inv.id != null) { await AppDb.instance.deleteInvoice(inv.id!); load(); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('View/Edit')), PopupMenuItem(value: 'print', child: Text('PDF Preview/Print')), PopupMenuItem(value: 'share', child: Text('Share PDF')), PopupMenuItem(value: 'duplicate', child: Text('Duplicate')), PopupMenuItem(value: 'delete', child: Text('Delete'))])));
    })),
  ]));
}

class ReportsScreen extends StatefulWidget { const ReportsScreen({super.key}); @override State<ReportsScreen> createState() => _ReportsScreenState(); }
class _ReportsScreenState extends State<ReportsScreen> {
  double today = 0, week = 0, month = 0, year = 0;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    final list = await AppDb.instance.invoices();
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    today = week = month = year = 0;
    for (final inv in list) {
      final v = GstEngine.calculate(inv).grandTotal;
      if (DateUtils.isSameDay(inv.invoiceDate, now)) today += v;
      if (inv.invoiceDate.isAfter(DateTime(start.year, start.month, start.day))) week += v;
      if (inv.invoiceDate.year == now.year && inv.invoiceDate.month == now.month) month += v;
      if (inv.invoiceDate.year == now.year) year += v;
    }
    setState(() {});
  }

  Future<void> exportCsv() async {
    final list = await AppDb.instance.invoices();
    final rows = [['Date','Invoice No','Buyer','GSTIN','Taxable','CGST','SGST','IGST','Total']];
    for (final inv in list) {
      final t = GstEngine.calculate(inv);
      rows.add([DateFormat('yyyy-MM-dd').format(inv.invoiceDate), inv.invoiceNo, inv.buyerName, inv.buyerGstin, '${t.taxable}', '${t.cgst}', '${t.sgst}', '${t.igst}', '${t.grandTotal}']);
    }
    await Share.share(const ListToCsvConverter().convert(rows), subject: 'Sri Kesar Invoice Report CSV');
  }

  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Reports')), body: ListView(padding: const EdgeInsets.all(14), children: [
    GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 1.35, crossAxisSpacing: 8, mainAxisSpacing: 8, children: [
      _Report('Today', today), _Report('This Week', week), _Report('This Month', month), _Report('This Year', year),
    ]),
    const SizedBox(height: 12),
    FilledButton.icon(onPressed: exportCsv, icon: const Icon(Icons.table_chart), label: const Text('Export Excel / CSV')),
  ]));
}

class _Report extends StatelessWidget {
  final String label; final double value;
  const _Report(this.label, this.value);
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(label), Text('₹${value.toStringAsFixed(0)}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))])));
}

class SettingsScreen extends StatefulWidget { const SettingsScreen({super.key}); @override State<SettingsScreen> createState() => _SettingsScreenState(); }
class _SettingsScreenState extends State<SettingsScreen> {
  final name = TextEditingController(); final address = TextEditingController(); final mobile = TextEditingController(); final pin = TextEditingController(); final gstin = TextEditingController(); final email = TextEditingController(); final pan = TextEditingController();

  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    final c = await AppDb.instance.company();
    name.text = c.name; address.text = c.address; mobile.text = c.mobile; pin.text = c.pinCode; gstin.text = c.gstin; email.text = c.email; pan.text = c.pan;
    setState(() {});
  }

  Future<void> save() async {
    await AppDb.instance.saveCompany(CompanySettings(name: name.text.trim(), address: address.text.trim(), mobile: mobile.text.trim(), pinCode: pin.text.trim(), gstin: gstin.text.trim(), email: email.text.trim(), pan: pan.text.trim()));
    snack('Company settings saved.');
  }

  Future<void> backup() async {
    final json = await AppDb.instance.backupJson();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/SriKesar_Backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)], text: 'Sri Kesar Enterprises Backup');
  }

  void snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override Widget build(BuildContext context) {
    final theme = ThemeController.of(context);
    return Scaffold(appBar: AppBar(title: const Text('Settings & Backup')), body: ListView(padding: const EdgeInsets.all(14), children: [
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Company Name')), const SizedBox(height: 8),
        TextField(controller: address, maxLines: 3, decoration: const InputDecoration(labelText: 'Address')), const SizedBox(height: 8),
        TextField(controller: mobile, decoration: const InputDecoration(labelText: 'Mobile')), const SizedBox(height: 8),
        TextField(controller: gstin, decoration: const InputDecoration(labelText: 'GSTIN')), const SizedBox(height: 8),
        TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')), const SizedBox(height: 8),
        TextField(controller: pin, decoration: const InputDecoration(labelText: 'Pin Code')), const SizedBox(height: 8),
        TextField(controller: pan, decoration: const InputDecoration(labelText: 'PAN')), const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: save, child: const Text('Save Company Settings'))),
      ]))),
      SwitchListTile(value: theme.darkMode, title: const Text('Dark Mode'), onChanged: theme.setDarkMode),
      Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.backup), title: const Text('Manual Backup'), subtitle: const Text('Export local database JSON'), onTap: backup),
        ListTile(leading: const Icon(Icons.cloud), title: const Text('Google Drive Sign-In'), subtitle: const Text('Sign-in is requested automatically during Drive upload'), onTap: () async { final api = await GoogleDriveService().api(); snack(api == null ? 'Google Drive cancelled.' : 'Google Drive connected.'); }),
        ListTile(leading: const Icon(Icons.qr_code_2), title: const Text('UPI QR Payment Preview'), subtitle: const Text('Enter production UPI ID before live use'), onTap: () => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('UPI QR Placeholder'), content: SizedBox(width: 220, height: 220, child: QrImageView(data: 'upi://pay?pa=yourupi@bank&pn=Sri%20Kesar%20Enterprises', size: 210)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]))),
      ])),
    ]));
  }
}

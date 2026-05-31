import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;

void main() {
  runApp(const EarlyBirdStockApp());
}

class StockItem {
  final String id;
  String barcode;
  String productName;
  double purchasePrice;
  int quantity;
  String dateTime;
  String category;

  StockItem({
    required this.barcode,
    required this.productName,
    required this.purchasePrice,
    required this.quantity,
    required this.dateTime,
    this.category = 'OTHERS',
  }) : id = DateTime.now().millisecondsSinceEpoch.toString() + barcode;

  double get totalValue => purchasePrice * quantity;

  Map<String, dynamic> toMap() => {
        'id': id,
        'barcode': barcode,
        'productName': productName,
        'purchasePrice': purchasePrice,
        'quantity': quantity,
        'dateTime': dateTime,
        'category': category,
      };

  factory StockItem.fromMap(Map<String, dynamic> map) => StockItem(
        barcode: map['barcode'] ?? '',
        productName: map['productName'] ?? '',
        purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
        quantity: map['quantity'] ?? 1,
        dateTime: map['dateTime'] ?? '',
        category: map['category'] ?? 'OTHERS',
      );
}

class EarlyBirdStockApp extends StatelessWidget {
  const EarlyBirdStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EARLY BIRD Stock Book',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFFD32F2F),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFD32F2F),
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        cardTheme: const CardTheme(color: Colors.white, elevation: 3),
      ),
      home: const StockHomeView(),
    );
  }
}

class StockHomeView extends StatefulWidget {
  const StockHomeView({super.key});
  @override
  State<StockHomeView> createState() => _StockHomeViewState();
}

class _StockHomeViewState extends State<StockHomeView> {
  List<StockItem> _stockList = [];
  List<StockItem> _filteredStockList = [];
  Map<String, Map<String, dynamic>> _posProductMaster = {};
  
  List<String> _originalHeaders = [];
  int _skuColumnIndex = -1;
  int _currentStockColumnIndex = -1;

  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController();
  final _searchController = TextEditingController();
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isContinuousScanMode = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _searchController.addListener(_filterStockList);
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stockString = prefs.getString('eb_saved_stock');
    if (stockString != null) {
      final List<dynamic> decodedList = jsonDecode(stockString);
      setState(() {
        _stockList = decodedList.map((item) => StockItem.fromMap(item)).toList();
        _filteredStockList = List.from(_stockList);
      });
    }

    final String? posMasterString = prefs.getString('eb_pos_master');
    if (posMasterString != null) {
      setState(() {
        _posProductMaster = Map<String, Map<String, dynamic>>.from(jsonDecode(posMasterString));
      });
    }
    
    final String? headersString = prefs.getString('eb_headers');
    if (headersString != null) {
      _originalHeaders = List<String>.from(jsonDecode(headersString));
      _skuColumnIndex = prefs.getInt('eb_sku_idx') ?? -1;
      _currentStockColumnIndex = prefs.getInt('eb_stock_idx') ?? -1;
    }
  }

  Future<void> _saveStockData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(_stockList.map((item) => item.toMap()).toList());
    await prefs.setString('eb_saved_stock', encodedData);
  }

  Future<void> _uploadPOSExcel() async {
    if (_stockList.isNotEmpty) {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Warning'),
          content: const Text('Active stock data found. Uploading a new master will replace settings. Proceed?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (confirm != true) return;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() { _isLoading = true; });
      try {
        var bytes = File(result.files.single.path!).readAsBytesSync();
        var excel = ex.Excel.decodeBytes(bytes);
        Map<String, Map<String, dynamic>> tempMaster = {};
        List<String> tempHeaders = [];

        for (var table in excel.tables.keys) {
          var rows = excel.tables[table]!.rows;
          if (rows.isEmpty) continue;

          int nameIdx = -1, skuIdx = -1, priceIdx = -1, catIdx = -1, stockIdx = -1;
          
          for (int i = 0; i < rows[0].length; i++) {
            String headerVal = rows[0][i]?.value?.toString().trim().toUpperCase() ?? '';
            tempHeaders.add(rows[0][i]?.value?.toString() ?? '');
            
            if (headerVal == 'NAME') nameIdx = i;
            if (headerVal.contains('SKU')) skuIdx = i;
            if (headerVal.contains('PURCHASE PRICE (INCLUDING TAX)')) priceIdx = i;
            if (headerVal == 'CATEGORY') catIdx = i;
            if (headerVal == 'CURRENT STOCK') stockIdx = i;
          }

          if (nameIdx == -1 || skuIdx == -1 || priceIdx == -1 || stockIdx == -1) {
            setState(() { _isLoading = false; });
            _showSnackBar('Columns missing in file.');
            return;
          }

          _skuColumnIndex = skuIdx;
          _currentStockColumnIndex = stockIdx;
          _originalHeaders = tempHeaders;

          for (int i = 1; i < rows.length; i++) {
            var rawRow = rows[i].map((e) => e?.value?.toString() ?? '').toList();
            var sku = rows[i][skuIdx]?.value?.toString().trim();
            var name = rows[i][nameIdx]?.value?.toString() ?? 'Unknown';
            var priceStr = rows[i][priceIdx]?.value?.toString() ?? '0.0';
            var cat = catIdx != -1 ? (rows[i][catIdx]?.value?.toString() ?? 'OTHERS') : 'OTHERS';
            double price = double.tryParse(priceStr) ?? 0.0;

            if (sku != null && sku.isNotEmpty) {
              tempMaster[sku] = {'name': name, 'price': price, 'category': cat, 'original_row': rawRow};
            }
          }
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('eb_pos_master', jsonEncode(tempMaster));
        await prefs.setString('eb_headers', jsonEncode(_originalHeaders));
        await prefs.setInt('eb_sku_idx', _skuColumnIndex);
        await prefs.setInt('eb_stock_idx', _currentStockColumnIndex);

        setState(() {
          _posProductMaster = tempMaster;
          _isLoading = false;
        });
        _showSnackBar('Loaded ${_posProductMaster.length} items.');
      } catch (e) {
        setState(() { _isLoading = false; });
        _showSnackBar('Error: $e');
      }
    }
  }

  Future<void> _playBeepSound() async {
    try {
      final List<int> beepBytes = [
        0x52, 0x49, 0x46, 0x46, 0x24, 0x01, 0x00, 0x00, 0x57, 0x41, 0x56, 0x45,
        0x66, 0x6d, 0x74, 0x20, 0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
        0x40, 0x1f, 0x00, 0x00, 0x40, 0x1f, 0x00, 0x00, 0x01, 0x00, 0x08, 0x00,
        0x64, 0x61, 0x74, 0x61, 0x00, 0x01, 0x00, 0x00
      ];
      for (int i = 0; i < 220; i++) {
        beepBytes.add((i % 12 < 6) ? 220 : 40);
      }
      await _audioPlayer.play(BytesSource(Uint8List.fromList(beepBytes)));
    } catch (e) {/**/}
  }

  void _onBarcodeChanged(String code) {
    if (_posProductMaster.containsKey(code)) {
      setState(() {
        _nameController.text = _posProductMaster[code]!['name'];
        _priceController.text = _posProductMaster[code]!['price'].toString();
        if (_qtyController.text.isEmpty) _qtyController.text = "1";
      });
    } else {
      setState(() {
        _nameController.text = "";
        _priceController.text = "";
      });
    }
  }

  void _addStockItem() {
    final String barcode = _barcodeController.text.trim();
    final String name = _nameController.text.trim();
    final double price = double.tryParse(_priceController.text) ?? 0.0;
    int qty = int.tryParse(_qtyController.text) ?? 1;

    if (barcode.isEmpty) return;

    String category = 'OTHERS';
    if (_posProductMaster.containsKey(barcode)) {
      category = _posProductMaster[barcode]!['category'];
    }

    setState(() {
      int existingIndex = _stockList.indexWhere((item) => item.barcode == barcode);
      if (existingIndex != -1) {
        _stockList[existingIndex].quantity += qty;
      } else {
        _stockList.add(StockItem(
          barcode: barcode,
          productName: name.isEmpty ? 'New Item ($barcode)' : name,
          purchasePrice: price,
          quantity: qty,
          dateTime: DateTime.now().toString().substring(0, 19),
          category: category,
        ));
      }
      _filteredStockList = List.from(_stockList);
    });
    
    _saveStockData();
    _barcodeController.clear();
    _nameController.clear();
    _priceController.clear();
    _qtyController.clear();
  }

  void _filterStockList() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStockList = _stockList.where((item) {
        return item.barcode.toLowerCase().contains(query) ||
            item.productName.toLowerCase().contains(query);
      }).toList();
    });
  }

  double get _grandTotalStockValue {
    return _stockList.fold(0, (sum, item) => sum + item.totalValue);
  }

  void _scanBarcode() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Continuous Scanner'),
              backgroundColor: const Color(0xFFD32F2F),
            ),
            body: MobileScanner(
              onDetect: (capture) async {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                  final String code = barcodes.first.rawValue!;
                  await _playBeepSound();

                  if (_isContinuousScanMode) {
                    String pName = _posProductMaster.containsKey(code) ? _posProductMaster[code]!['name'] : 'New Item ($code)';
                    double pPrice = _posProductMaster.containsKey(code) ? _posProductMaster[code]!['price'] : 0.0;
                    String pCat = _posProductMaster.containsKey(code) ? _posProductMaster[code]!['category'] : 'OTHERS';
                    
                    setState(() {
                      int existingIndex = _stockList.indexWhere((item) => item.barcode == code);
                      if (existingIndex != -1) {
                        _stockList[existingIndex].quantity += 1;
                      } else {
                        _stockList.add(StockItem(
                          barcode: code,
                          productName: pName,
                          purchasePrice: pPrice,
                          quantity: 1,
                          dateTime: DateTime.now().toString().substring(0, 19),
                          category: pCat,
                        ));
                      }
                      _filteredStockList = List.from(_stockList);
                    });
                    _saveStockData();
                  } else {
                    setState(() {
                      _barcodeController.text = code;
                      _onBarcodeChanged(code);
                    });
                    Navigator.pop(context);
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportPOSMasterExcel() async {
    if (_posProductMaster.isEmpty) {
      _showSnackBar('Upload POS Master first!');
      return;
    }
    setState(() { _isLoading = true; });

    var excel = ex.Excel.createExcel();
    var sheet = excel['Worksheet'];
    excel.updateCell('Worksheet', ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), 'Temp');
    sheet.clear();

    for (int col = 0; col < _originalHeaders.length; col++) {
      sheet.updateCell(ex.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0), ex.CellValue.withValue(_originalHeaders[col]));
    }

    Map<String, int> scannedMap = { for (var item in _stockList) item.barcode : item.quantity };
    int rowIndex = 1;
    
    _posProductMaster.forEach((sku, details) {
      List<dynamic> originalRow = details['original_row'];
      int currentScannedQty = scannedMap.containsKey(sku) ? scannedMap[sku]! : 0;

      for (int col = 0; col < originalRow.length; col++) {
        var cellValue = originalRow[col];
        if (col == _currentStockColumnIndex) {
          cellValue = currentScannedQty.toString();
        }
        sheet.updateCell(ex.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex), ex.CellValue.withValue(cellValue?.toString() ?? ''));
      }
      rowIndex++;
    });

    for (var item in _stockList) {
      if (!_posProductMaster.containsKey(item.barcode)) {
        for (int col = 0; col < _originalHeaders.length; col++) {
          var cellValue = '';
          if (col == _skuColumnIndex) cellValue = item.barcode;
          if (_originalHeaders[col].toUpperCase() == 'NAME') cellValue = item.productName;
          if (_originalHeaders[col].toUpperCase().contains('PURCHASE PRICE (INCLUDING TAX)')) cellValue = item.purchasePrice.toString();
          if (col == _currentStockColumnIndex) cellValue = item.quantity.toString();
          if (_originalHeaders[col].toUpperCase() == 'CATEGORY') cellValue = item.category;

          sheet.updateCell(ex.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex), ex.CellValue.withValue(cellValue));
        }
        rowIndex++;
      }
    }

    var fileBytes = excel.save();
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/Updated_POS_Master_Stock.xlsx');
    await file.writeAsBytes(fileBytes!);

    setState(() { _isLoading = false; });
    await Share.shareXFiles([XFile(file.path)], text: 'Updated POS Master');
  }

  Future<void> _exportStockOutputExcel() async {
    if (_stockList.isEmpty) return;

    var excel = ex.Excel.createExcel();
    var sheet = excel['Sheet1'];
    excel.updateCell('Sheet1', ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), 'Temp');
    sheet.clear();

    List<String> outputHeaders = ['Product Name', 'Product Code', 'Unit Price', 'Quantity', 'Total Price', 'Scanned Date Time'];
    for (int i = 0; i < outputHeaders.length; i++) {
      sheet.updateCell(ex.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0), ex.CellValue.withValue(outputHeaders[i]));
    }

    int rowIdx = 1;
    for (var item in _stockList) {
      sheet.updateCell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx), ex.CellValue.withValue(item.productName));
      sheet.updateCell(ex.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx), ex.CellValue.withValue(item.barcode));
      sheet.updateCell(ex.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx), ex.CellValue.withValue(item.purchasePrice));
      sheet.updateCell(ex.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx), ex.CellValue.withValue(item.quantity));
      sheet.updateCell(ex.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx), ex.CellValue.withValue(item.totalValue));
      sheet.updateCell(ex.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIdx), ex.CellValue.withValue(item.dateTime));
      rowIdx++;
    }

    sheet.updateCell(ex.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx + 1), ex.CellValue.withValue('Grand Total Investment:'));
    sheet.updateCell(ex.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx + 1), ex.CellValue.withValue(_grandTotalStockValue));

    var fileBytes = excel.save();
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/Early_Bird_Stock_Output.xlsx');
    await file.writeAsBytes(fileBytes!);

    await Share.shareXFiles([XFile(file.path)], text: 'Early Bird Stock Output');
  }

  void _clearAllStock() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Stock?'),
        content: const Text('This will delete current configuration values.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() { _stockList.clear(); _filteredStockList.clear(); });
              _saveStockData();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EARLY BIRD Stock Book', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.file_upload_outlined), onPressed: _uploadPOSExcel),
          IconButton(icon: const Icon(Icons.refresh_sharp), onPressed: _clearAllStock)
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Entry Configuration', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD32F2F))),
                            Row(
                              children: [
                                const Text('Continuous Scan', style: TextStyle(fontSize: 12)),
                                Switch(
                                  value: _isContinuousScanMode,
                                  onChanged: (val) { setState(() { _isContinuousScanMode = val; }); },
                                  activeColor: const Color(0xFFD32F2F),
                                ),
                              ],
                            )
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: _barcodeController, onChanged: _onBarcodeChanged, decoration: const InputDecoration(labelText: 'Barcode / SKU Input'))),
                            IconButton(icon: const Icon(Icons.qr_code_scanner_sharp, color: Color(0xFFD32F2F), size: 36), onPressed: _scanBarcode),
                          ],
                        ),
                        TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Product Name')),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: _priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Purchase Price'))),
                            const SizedBox(width: 15),
                            Expanded(child: TextField(controller: _qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity'))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _addStockItem, style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46)), child: const Text('ADD TO STOCK LIST')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: _searchController, decoration: InputDecoration(hintText: 'Search items...', prefixIcon: const Icon(Icons.search, color: Color(0xFFD32F2F)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(vertical: 0))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: ElevatedButton.icon(onPressed: _exportPOSMasterExcel, icon: const Icon(Icons.system_update_alt, size: 16), label: const Text('POS MASTER'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF212121)))),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton.icon(onPressed: _exportStockOutputExcel, icon: const Icon(Icons.assignment_turned_in, size: 16), label: const Text('STOCK OUTPUT'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700))),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFFD32F2F),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Investment Value:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('Rs. ${_grandTotalStockValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _filteredStockList.isEmpty
                    ? const Padding(padding: EdgeInsets.all(40), child: Text('No items found.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredStockList.length,
                        itemBuilder: (context, index) {
                          final item = _filteredStockList[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('SKU: ${item.barcode} | Price: Rs. ${item.purchasePrice} | Qty: ${item.quantity}\nTime: ${item.dateTime}', style: const TextStyle(fontSize: 11)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Rs. ${item.totalValue.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold, fontSize: 13)),
                                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20), onPressed: () { setState(() { _stockList.removeWhere((e) => e.id == item.id); _filteredStockList = List.from(_stockList); }); _saveStockData(); }),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
    );
  }
}

import 'package:flutter/material.dart';

void main() {
  runApp(const SimpleStockApp());
}

class Product {
  final String id;
  String code;
  double unitPrice;
  int quantity;

  Product({
    required this.code,
    required this.unitPrice,
    required this.quantity,
  }) : id = DateTime.now().toString();

  double get total => unitPrice * quantity;
}

class SimpleStockApp extends StatelessWidget {
  const SimpleStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Simple Stock App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ContentView(),
    );
  }
}

class ContentView extends StatefulWidget {
  const ContentView({super.key});

  @override
  State<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<ContentView> {
  final List<Product> _products = [];
  
  final _codeController = TextEditingController();
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController();

  double get _fullTotal {
    return _products.fold(0, (sum, item) => sum + item.total);
  }

  void _addProduct() {
    final String code = _codeController.text;
    final double price = double.tryParse(_priceController.text) ?? 0.0;
    final int qty = int.tryParse(_qtyController.text) ?? 0;

    if (code.isNotEmpty && price > 0 && qty > 0) {
      setState(() {
        _products.add(
          Product(code: code, unitPrice: price, quantity: qty),
        );
      });

      _codeController.clear();
      _priceController.clear();
      _qtyController.clear();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Stock App'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Add Product',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _codeController,
                      decoration: const InputDecoration(labelText: 'Product Code'),
                    ),
                    TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Unit Price'),
                    ),
                    TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: _addProduct,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      child: const Text('Add Product', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Products',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _products.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('No products added yet.'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Code: ${product.code}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Unit Price: Rs. ${product.unitPrice}'),
                              Text('Quantity: ${product.quantity}'),
                              Text('Total: Rs. ${product.total}', style: const TextStyle(color: Colors.blue)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 20),
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Full Total:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Rs. $_fullTotal',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

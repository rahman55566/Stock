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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show lerpDouble;

void main() {
  runApp(const SistemStockApp());
}

class SistemStockApp extends StatelessWidget {
  const SistemStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistem Stok Barang',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFFE84C3D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE84C3D),
          primary: const Color(0xFFE84C3D),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
      ),
      home: const StockHomePage(),
    );
  }
}

class ShiftData {
  String stokAwal;
  String ambilBarang;
  String sisaStok;

  ShiftData({
    this.stokAwal = '0',
    this.ambilBarang = '0',
    this.sisaStok = '0',
  });

  Map<String, dynamic> toJson() => {
        'stokAwal': stokAwal,
        'ambilBarang': ambilBarang,
        'sisaStok': sisaStok,
      };

  factory ShiftData.fromJson(Map<String, dynamic> json) {
    return ShiftData(
      stokAwal: json['stokAwal']?.toString() ?? '0',
      ambilBarang: json['ambilBarang']?.toString() ?? '0',
      sisaStok: json['sisaStok']?.toString() ?? '0',
    );
  }

  ShiftData copy() => ShiftData(
        stokAwal: stokAwal,
        ambilBarang: ambilBarang,
        sisaStok: sisaStok,
      );
}

int _itemIdCounter = 0;
String _generateItemId() => '${DateTime.now().microsecondsSinceEpoch}_${++_itemIdCounter}';

class ItemBarang {
  final String id;
  String nama;
  ShiftData pagi;
  ShiftData sore;

  ItemBarang({
    String? id,
    required this.nama,
    ShiftData? pagi,
    ShiftData? sore,
  })  : id = id ?? _generateItemId(),
        pagi = pagi ?? ShiftData(),
        sore = sore ?? ShiftData();

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'pagi': pagi.toJson(),
        'sore': sore.toJson(),
      };

  factory ItemBarang.fromJson(Map<String, dynamic> json) {
    return ItemBarang(
      id: json['id']?.toString() ?? _generateItemId(),
      nama: json['nama']?.toString() ?? '',
      pagi: json['pagi'] != null
          ? ShiftData.fromJson(json['pagi'])
          : ShiftData(
              stokAwal: json['stokAwal']?.toString() ?? '0',
              ambilBarang: json['ambilBarang']?.toString() ?? '0',
              sisaStok: json['sisaStok']?.toString() ?? '0',
            ),
      sore: json['sore'] != null ? ShiftData.fromJson(json['sore']) : ShiftData(),
    );
  }

  ItemBarang copy() => ItemBarang(
        id: id,
        nama: nama,
        pagi: pagi.copy(),
        sore: sore.copy(),
      );
}

class StockHomePage extends StatefulWidget {
  const StockHomePage({super.key});

  @override
  State<StockHomePage> createState() => _StockHomePageState();
}

class _StockHomePageState extends State<StockHomePage> {
  static List<ItemBarang> get _defaultInitialItems => [
    ItemBarang(
      id: 'default_1',
      nama: 'Gula Pasir 1kg',
      pagi: ShiftData(stokAwal: '10', ambilBarang: '2', sisaStok: '8'),
      sore: ShiftData(stokAwal: '8', ambilBarang: '1', sisaStok: '7'),
    ),
    ItemBarang(
      id: 'default_2',
      nama: 'Minyak Goreng 1L',
      pagi: ShiftData(stokAwal: '15', ambilBarang: '5', sisaStok: '10'),
      sore: ShiftData(stokAwal: '10', ambilBarang: '3', sisaStok: '7'),
    ),
    ItemBarang(
      id: 'default_3',
      nama: 'Kopi Bubuk',
      pagi: ShiftData(stokAwal: '20', ambilBarang: '4', sisaStok: '16'),
      sore: ShiftData(stokAwal: '16', ambilBarang: '2', sisaStok: '14'),
    ),
  ];

  int _selectedShift = 0; // 0 = Shift 1 (Pagi), 1 = Shift 2 (Sore)
  List<ItemBarang> _items = _defaultInitialItems;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Undo / Redo Stacks
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // --- Snapshot & Undo / Redo Management ---
  void _recordHistory() {
    final snapshot = jsonEncode(_items.map((e) => e.toJson()).toList());
    _undoStack.add(snapshot);
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _searchFocusNode.unfocus();
    final currentSnapshot = jsonEncode(_items.map((e) => e.toJson()).toList());
    _redoStack.add(currentSnapshot);

    final previousSnapshot = _undoStack.removeLast();
    try {
      final List decoded = jsonDecode(previousSnapshot);
      setState(() {
        _items = decoded.map((e) => ItemBarang.fromJson(e)).toList();
      });
      _saveData(skipHistory: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aksi berhasil dibatalkan (Undo)'),
          duration: Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {}
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _searchFocusNode.unfocus();
    final currentSnapshot = jsonEncode(_items.map((e) => e.toJson()).toList());
    _undoStack.add(currentSnapshot);

    final nextSnapshot = _redoStack.removeLast();
    try {
      final List decoded = jsonDecode(nextSnapshot);
      setState(() {
        _items = decoded.map((e) => ItemBarang.fromJson(e)).toList();
      });
      _saveData(skipHistory: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aksi berhasil diulang (Redo)'),
          duration: Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {}
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dataString = prefs.getString('stock_items_data_manual_v4');

    if (dataString != null) {
      try {
        final List decoded = jsonDecode(dataString);
        if (mounted) {
          setState(() {
            _items = decoded.map((e) => ItemBarang.fromJson(e)).toList();
          });
        }
        return;
      } catch (_) {
        // Fallback jika gagal decode
      }
    }

    // Data Default Awal
    if (mounted) {
      setState(() {
        _items = [
          ItemBarang(
            nama: 'Gula Pasir 1kg',
            pagi: ShiftData(stokAwal: '10', ambilBarang: '2', sisaStok: '8'),
            sore: ShiftData(stokAwal: '8', ambilBarang: '1', sisaStok: '7'),
          ),
          ItemBarang(
            nama: 'Minyak Goreng 1L',
            pagi: ShiftData(stokAwal: '15', ambilBarang: '5', sisaStok: '10'),
            sore: ShiftData(stokAwal: '10', ambilBarang: '3', sisaStok: '7'),
          ),
          ItemBarang(
            nama: 'Kopi Bubuk',
            pagi: ShiftData(stokAwal: '20', ambilBarang: '4', sisaStok: '16'),
            sore: ShiftData(stokAwal: '16', ambilBarang: '2', sisaStok: '14'),
          ),
        ];
      });
    }
    _saveData(skipHistory: true);
  }

  Future<void> _saveData({bool skipHistory = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString('stock_items_data_manual_v4', encoded);
  }

  // --- Reordering Rows (Requirement 2) ---
  void _onReorderItem(int oldIndex, int newIndex) {
    _recordHistory();
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
    _saveData(skipHistory: true);
  }

  // --- Dialog Tambah Barang Baru ---
  void _showAddBarangDialog() {
    _searchFocusNode.unfocus();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController stokAwalController = TextEditingController(text: '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_box_outlined, color: Color(0xFFE84C3D)),
              SizedBox(width: 8),
              Text('Tambah Barang Baru'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nama Barang / Satuan',
                  hintText: 'Contoh: Nuget 500gr',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stokAwalController,
                decoration: InputDecoration(
                  labelText: 'Stok Awal (${_selectedShift == 0 ? "Shift 1 Pagi" : "Shift 2 Sore"})',
                  hintText: '0 / bebas satuan (misal 5 pack)',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE84C3D)),
              onPressed: () {
                final name = nameController.text.trim();
                final awal = stokAwalController.text.trim().isEmpty ? '0' : stokAwalController.text.trim();
                if (name.isNotEmpty) {
                  _recordHistory();
                  setState(() {
                    final newItem = ItemBarang(
                      nama: name,
                      pagi: _selectedShift == 0
                          ? ShiftData(stokAwal: awal, ambilBarang: '0', sisaStok: '0')
                          : ShiftData(),
                      sore: _selectedShift == 1
                          ? ShiftData(stokAwal: awal, ambilBarang: '0', sisaStok: '0')
                          : ShiftData(),
                    );
                    _items.add(newItem);
                  });
                  _saveData(skipHistory: true);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Barang "$name" berhasil ditambahkan!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- Dialog Edit Data Lengkap via Modal berdasarkan Shift Aktif ---
  void _showEditBarangDialog(int index) {
    _searchFocusNode.unfocus();
    final ItemBarang item = _items[index];
    final ShiftData currentShiftData = _selectedShift == 0 ? item.pagi : item.sore;

    // Requirement 2: Jika nilainya '0', kosongkan di input agar user tidak repot hapus
    final String awalInitial = currentShiftData.stokAwal.trim() == '0' ? '' : currentShiftData.stokAwal;
    final String ambilInitial = currentShiftData.ambilBarang.trim() == '0' ? '' : currentShiftData.ambilBarang;
    final String sisaInitial = currentShiftData.sisaStok.trim() == '0' ? '' : currentShiftData.sisaStok;

    final TextEditingController nameController = TextEditingController(text: item.nama);
    final TextEditingController stokAwalController = TextEditingController(text: awalInitial);
    final TextEditingController ambilController = TextEditingController(text: ambilInitial);
    final TextEditingController sisaController = TextEditingController(text: sisaInitial);

    final FocusNode nameFocus = FocusNode();
    final FocusNode awalFocus = FocusNode();
    final FocusNode ambilFocus = FocusNode();
    final FocusNode sisaFocus = FocusNode();

    // UX: Saat awal modal dibuka, shortcut belum muncul (null).
    // Shortcut baru muncul di bawah input ketika input tersebut diklik.
    int? activeTargetIndex; // 0 = Awal, 1 = Ambil, 2 = Sisa, null = belum ada/nama

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void applyStatus(TextEditingController ctrl, String status) {
              ctrl.text = status;
              ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
              setModalState(() {});
            }

            void applyUnit(TextEditingController ctrl, String unit) {
              final current = ctrl.text.trim();
              // Mendukung angka bulat (10), desimal koma/titik (0,5 / 1.5),
              // pecahan biasa (1/2, 3/4), pecahan campuran (1 1/2), dan simbol pecahan unicode (½, ¼, ¾)
              final match = RegExp(
                r'^(\d+\s+\d+\s*\/\s*\d+|\d+\s*\/\s*\d+|\d+[\.,]\d+|\d+|[\.,]\d+|\d*\s*[½¼¾⅓⅔⅛⅜⅝⅞])',
              ).firstMatch(current);

              if (match != null) {
                ctrl.text = '${match.group(1)!.trim()} $unit';
              } else if (current.isNotEmpty) {
                String cleaned = current;
                for (final u in ['Thinwal', 'thinwal', 'botol', 'pack', 'pcs']) {
                  if (cleaned.toLowerCase().endsWith(u.toLowerCase())) {
                    cleaned = cleaned.substring(0, cleaned.length - u.length).trim();
                    break;
                  }
                }
                ctrl.text = cleaned.isNotEmpty ? '$cleaned $unit' : unit;
              } else {
                ctrl.text = unit;
              }
              ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
              setModalState(() {});
            }

            Widget buildInputField({
              required int index,
              required String label,
              required TextEditingController controller,
              required FocusNode focusNode,
            }) {
              final bool isActive = activeTargetIndex == index;
              final bool hasNumber = RegExp(r'[\d½¼¾⅓⅔⅛⅜⅝⅞]').hasMatch(controller.text);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onTap: () {
                      setModalState(() => activeTargetIndex = index);
                    },
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      labelText: label,
                      hintText: '0',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: isActive
                          ? const Icon(Icons.edit, size: 16, color: Color(0xFFE84C3D))
                          : null,
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: hasNumber
                          ? [
                              Expanded(child: _buildSimpleButton('Thinwal', Colors.deepPurple, () => applyUnit(controller, 'Thinwal'))),
                              const SizedBox(width: 5),
                              Expanded(child: _buildSimpleButton('botol', Colors.teal.shade700, () => applyUnit(controller, 'botol'))),
                              const SizedBox(width: 5),
                              Expanded(child: _buildSimpleButton('pack', Colors.indigo, () => applyUnit(controller, 'pack'))),
                              const SizedBox(width: 5),
                              Expanded(child: _buildSimpleButton('pcs', Colors.brown, () => applyUnit(controller, 'pcs'))),
                            ]
                          : [
                              Expanded(child: _buildSimpleButton('masih', Colors.green.shade700, () => applyStatus(controller, 'masih'))),
                              const SizedBox(width: 5),
                              Expanded(child: _buildSimpleButton('banyak', Colors.blue.shade700, () => applyStatus(controller, 'banyak'))),
                              const SizedBox(width: 5),
                              Expanded(child: _buildSimpleButton('sedikit', Colors.orange.shade800, () => applyStatus(controller, 'sedikit'))),
                              const SizedBox(width: 5),
                              Expanded(child: _buildSimpleButton('habis', Colors.red.shade700, () => applyStatus(controller, 'habis'))),
                            ],
                    ),
                  ],
                ],
              );
            }

            return AlertDialog(
              alignment: Alignment.topCenter,
              insetPadding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
              title: Row(
                children: [
                  const Icon(Icons.edit_note, color: Color(0xFFE84C3D)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit Data (${_selectedShift == 0 ? "Shift 1 Pagi" : "Shift 2 Sore"})',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      focusNode: nameFocus,
                      onTap: () {
                        setModalState(() => activeTargetIndex = null);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Nama Barang (Semua Shift)',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    buildInputField(
                      index: 0,
                      label: 'Stok Awal (${_selectedShift == 0 ? "Shift 1" : "Shift 2"})',
                      controller: stokAwalController,
                      focusNode: awalFocus,
                    ),
                    const SizedBox(height: 10),
                    buildInputField(
                      index: 1,
                      label: 'Ambil (${_selectedShift == 0 ? "Shift 1" : "Shift 2"})',
                      controller: ambilController,
                      focusNode: ambilFocus,
                    ),
                    const SizedBox(height: 10),
                    buildInputField(
                      index: 2,
                      label: 'Sisa (${_selectedShift == 0 ? "Shift 1" : "Shift 2"})',
                      controller: sisaController,
                      focusNode: sisaFocus,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE84C3D)),
                  onPressed: () {
                    _recordHistory();
                    setState(() {
                      item.nama = nameController.text.trim();
                      // Requirement 2: Jika kosong disimpan sebagai '0'
                      currentShiftData.stokAwal = stokAwalController.text.trim().isEmpty ? '0' : stokAwalController.text.trim();
                      currentShiftData.ambilBarang = ambilController.text.trim().isEmpty ? '0' : ambilController.text.trim();
                      currentShiftData.sisaStok = sisaController.text.trim().isEmpty ? '0' : sisaController.text.trim();
                    });
                    _saveData(skipHistory: true);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Perubahan data berhasil disimpan!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Simpan Perubahan', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Widget Bantu Tombol Shortcut Simpel & Kompak ---
  Widget _buildSimpleButton(String text, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  // --- Dialog Konfirmasi Hapus Baris ---
  void _confirmDeleteBarang(int index) {
    _searchFocusNode.unfocus();
    final ItemBarang item = _items[index];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Konfirmasi Hapus'),
            ],
          ),
          content: Text('Yakin ingin menghapus barang "${item.nama}" dari daftar stok?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                _recordHistory();
                setState(() {
                  _items.removeAt(index);
                });
                _saveData(skipHistory: true);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Barang berhasil dihapus.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- Fitur Reset Value (Requirement 4) ---
  void _confirmResetData(int shiftIndex) {
    _searchFocusNode.unfocus();
    final shiftName = shiftIndex == 0 ? 'Shift 1 (Pagi)' : 'Shift 2 (Sore)';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.restart_alt, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Reset Nilai $shiftName'),
            ],
          ),
          content: Text(
            'Nilai Stok Awal, Ambil, dan Sisa pada $shiftName akan dikembalikan menjadi 0.\n\n'
            'Daftar nama barang tidak akan terhapus. Lanjutkan?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                _executeShiftReset(shiftIndex);
              },
              child: const Text('Ya, Reset', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _executeShiftReset(int shiftIndex) {
    _recordHistory();
    setState(() {
      for (var item in _items) {
        if (shiftIndex == 0) {
          item.pagi = ShiftData(stokAwal: '0', ambilBarang: '0', sisaStok: '0');
        } else {
          item.sore = ShiftData(stokAwal: '0', ambilBarang: '0', sisaStok: '0');
        }
      }
    });
    _saveData(skipHistory: true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nilai ${shiftIndex == 0 ? "Shift 1 (Pagi)" : "Shift 2 (Sore)"} berhasil direset.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmResetAllShifts() {
    _searchFocusNode.unfocus();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Reset Semua Shift'),
            ],
          ),
          content: const Text(
            'Anda akan mereset nilai Stok Awal, Ambil, dan Sisa untuk KEDUA Shift (Pagi & Sore) menjadi 0.\n\n'
            'Nama barang tetap dipertahankan. Lanjutkan?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                _recordHistory();
                setState(() {
                  for (var item in _items) {
                    item.pagi = ShiftData(stokAwal: '0', ambilBarang: '0', sisaStok: '0');
                    item.sore = ShiftData(stokAwal: '0', ambilBarang: '0', sisaStok: '0');
                  }
                });
                _saveData(skipHistory: true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Semua nilai shift berhasil direset.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Reset Semua', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- Handover Shift 2 -> Shift 1 (Requirement 1) ---

  // Generate plain text handover dari Shift 2 (Sore)
  String _generateHandoverText() {
    final dateFormatted = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final buffer = StringBuffer();
    buffer.writeln('=== SISA STOK SHIFT 2 (HANDOVER) ===');
    buffer.writeln('Tanggal: $dateFormatted');
    buffer.writeln('Format: Nama Barang : Sisa Stok');
    buffer.writeln('');
    for (var item in _items) {
      buffer.writeln('${item.nama} : ${item.sore.sisaStok}');
    }
    return buffer.toString();
  }

  // Dialog Ekspor Plain Text Shift 2
  void _showExportHandoverDialog() {
    _searchFocusNode.unfocus();
    final text = _generateHandoverText();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.assignment_outlined, color: Color(0xFFE84C3D)),
              SizedBox(width: 8),
              Expanded(
                child: Text('Ekspor Sisa Shift 2 (Handover)', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Salin teks ini atau bagikan via WhatsApp. Besok pagi, petugas Shift 1 cukup mengimpornya sebagai Stok Awal:',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              Container(
                height: 180,
                width: double.maxFinite,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    text,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.share, size: 16),
              label: const Text('Bagikan'),
              onPressed: () {
                Share.share(text, subject: 'Handover Sisa Stok Shift 2');
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE84C3D)),
              icon: const Icon(Icons.copy, size: 16, color: Colors.white),
              label: const Text('Salin Teks', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Teks Sisa Stok berhasil disalin ke Clipboard!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Dialog Impor Stok Awal Shift 1 dari Plain Text
  void _showImportHandoverDialog() {
    _searchFocusNode.unfocus();
    final TextEditingController textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.assignment_returned, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Impor Stok Awal Shift 1', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tempelkan teks sisa stok Shift 2 kemarin di bawah ini. Nilai sisa kemarin akan otomatis dijadikan Stok Awal Shift 1:',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue.shade700,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.paste, size: 15),
                        label: const Text('Tempel dari Clipboard', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                          if (clipboardData != null && clipboardData.text != null) {
                            setDialogState(() {
                              textController.text = clipboardData.text!;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: textController,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: 'Gula Pasir 1kg : 7\nMinyak Goreng 1L : 7\nKopi Bubuk : 14',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Catatan: Hanya Stok Awal yang terisi. Nilai Ambil dan Sisa Shift 1 akan bernilai 0.',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE84C3D)),
                  onPressed: () {
                    final raw = textController.text.trim();
                    if (raw.isNotEmpty) {
                      _processHandoverImport(raw);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Terapkan Stok Awal', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Proses parser teks handover ke Shift 1
  void _processHandoverImport(String rawText) {
    if (rawText.trim().isEmpty) return;

    _recordHistory();
    final lines = rawText.split('\n');
    int updatedCount = 0;
    int addedCount = 0;

    setState(() {
      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (trimmed.startsWith('=') ||
            trimmed.startsWith('#') ||
            trimmed.toLowerCase().startsWith('tanggal') ||
            trimmed.toLowerCase().startsWith('format') ||
            trimmed.toLowerCase().startsWith('no,') ||
            trimmed.toLowerCase().startsWith('nama barang')) {
          continue;
        }

        String nama = '';
        String sisaVal = '0';

        if (trimmed.contains(':')) {
          final parts = trimmed.split(':');
          nama = parts[0].trim();
          sisaVal = parts.sublist(1).join(':').trim();
        } else if (trimmed.contains(',')) {
          final parts = trimmed.split(',');
          if (parts.length >= 2) {
            nama = parts[0].trim();
            sisaVal = parts[1].trim();
          }
        } else if (trimmed.contains('\t')) {
          final parts = trimmed.split('\t');
          if (parts.length >= 2) {
            nama = parts[0].trim();
            sisaVal = parts[1].trim();
          }
        } else if (trimmed.contains(' - ')) {
          final parts = trimmed.split(' - ');
          if (parts.length >= 2) {
            nama = parts[0].trim();
            sisaVal = parts[1].trim();
          }
        }

        if (nama.isEmpty) continue;
        if (sisaVal.isEmpty) sisaVal = '0';

        bool found = false;
        for (var item in _items) {
          if (item.nama.trim().toLowerCase() == nama.toLowerCase()) {
            found = true;
            item.pagi.stokAwal = sisaVal;
            item.pagi.ambilBarang = '0';
            item.pagi.sisaStok = '0';
            updatedCount++;
            break;
          }
        }

        if (!found) {
          _items.add(
            ItemBarang(
              nama: nama,
              pagi: ShiftData(
                stokAwal: sisaVal,
                ambilBarang: '0',
                sisaStok: '0',
              ),
              sore: ShiftData(
                stokAwal: '0',
                ambilBarang: '0',
                sisaStok: '0',
              ),
            ),
          );
          addedCount++;
        }
      }
    });

    _saveData(skipHistory: true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Berhasil impor Stok Awal Shift 1: $updatedCount diperbarui, $addedCount item baru.'),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Pintasan Salin Langsung Shift 2 ke Shift 1 (Jika perangkat yang sama)
  void _copySoreToPagiDirect() {
    _searchFocusNode.unfocus();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.sync_alt, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text('Salin Sisa Shift 2 Langsung', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
          content: const Text(
            'Apakah Anda ingin menerapkan seluruh sisa stok Shift 2 saat ini langsung sebagai Stok Awal Shift 1?\n\n'
            'Hanya Stok Awal Shift 1 yang akan terisi. Nilai Ambil dan Sisa Shift 1 akan bernilai 0.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE84C3D)),
              onPressed: () {
                Navigator.pop(context);
                _recordHistory();
                setState(() {
                  for (var item in _items) {
                    item.pagi.stokAwal = item.sore.sisaStok;
                    item.pagi.ambilBarang = '0';
                    item.pagi.sisaStok = '0';
                  }
                });
                _saveData(skipHistory: true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sisa Shift 2 berhasil dijadikan Stok Awal Shift 1!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Terapkan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- Ekspor Excel & Impor CSV (Format .xlsx Rapi & Bertanggal) ---

  // Ekspor Excel ke File Fisik .xlsx dengan Format Kolom Rapi & Tanggal
  Future<void> _exportExcelFile(int targetShift) async {
    _searchFocusNode.unfocus();
    final shiftTag = targetShift == 0 ? 'Pagi' : 'Sore';
    final shiftLabel = targetShift == 0 ? 'Shift 1 (Pagi)' : 'Shift 2 (Sore)';
    final dateFormatted = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final timeFormatted = DateFormat('HHmm').format(DateTime.now());
    final fileName = 'Stok_Shift_${shiftTag}_${dateFormatted}_$timeFormatted.xlsx';

    try {
      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      final sheetName = 'Stok Shift $shiftTag';
      excel.rename(defaultSheet, sheetName);
      final sheet = excel[sheetName];

      // Styling Sel
      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
      );

      final centerStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final leftStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

      // Judul Kolom Header
      final headers = ['NO', 'NAMA BARANG', 'STOK AWAL', 'AMBIL', 'SISA ($shiftLabel)'];
      for (int col = 0; col < headers.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        cell.value = TextCellValue(headers[col]);
        cell.cellStyle = headerStyle;
      }

      // Baris Data
      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];
        final shiftData = targetShift == 0 ? item.pagi : item.sore;

        // Kolom NO (Rata Tengah)
        final cellNo = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1));
        cellNo.value = IntCellValue(i + 1);
        cellNo.cellStyle = centerStyle;

        // Kolom Nama Barang (Rata Kiri)
        final cellNama = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1));
        cellNama.value = TextCellValue(item.nama);
        cellNama.cellStyle = leftStyle;

        // Kolom Stok Awal (Rata Tengah)
        final cellAwal = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1));
        cellAwal.value = TextCellValue(shiftData.stokAwal);
        cellAwal.cellStyle = centerStyle;

        // Kolom Ambil (Rata Tengah)
        final cellAmbil = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1));
        cellAmbil.value = TextCellValue(shiftData.ambilBarang);
        cellAmbil.cellStyle = centerStyle;

        // Kolom Sisa (Rata Tengah)
        final cellSisa = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1));
        cellSisa.value = TextCellValue(shiftData.sisaStok);
        cellSisa.cellStyle = centerStyle;
      }

      // Lebar Kolom Otomatis yang Proporsional
      sheet.setColumnWidth(0, 8.0);
      sheet.setColumnWidth(1, 30.0);
      sheet.setColumnWidth(2, 14.0);
      sheet.setColumnWidth(3, 14.0);
      sheet.setColumnWidth(4, 20.0);

      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Gagal membuat byte data Excel.');

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final String path = '${directory!.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(fileBytes);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.table_chart, color: Colors.green),
                const SizedBox(width: 8),
                Text('Ekspor Excel $shiftTag Berhasil!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('File Excel (.xlsx) dengan tabel rapi telah tersimpan:'),
                const SizedBox(height: 8),
                SelectableText(
                  fileName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFE84C3D)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Lokasi: $path',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                const Text(
                  'File .xlsx ini otomatis memiliki kolom rapi, perataan tengah yang sejajar, dan siap dibuka di Microsoft Excel, WPS Office, atau Google Sheets.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              OutlinedButton.icon(
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Bagikan File'),
                onPressed: () {
                  Navigator.pop(context);
                  Share.shareXFiles([XFile(path)], text: 'Laporan Stok $shiftLabel ($dateFormatted)');
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE84C3D)),
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan file Excel: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Ekspor CSV via Clipboard
  void _exportCsvClipboard(int targetShift) {
    _searchFocusNode.unfocus();
    final shiftTag = targetShift == 0 ? 'Pagi' : 'Sore';
    final shiftLabel = targetShift == 0 ? 'Shift 1 (Pagi)' : 'Shift 2 (Sore)';
    final StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln('No,Nama Barang,Stok Awal,Ambil,Sisa ($shiftLabel)');
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final shiftData = targetShift == 0 ? item.pagi : item.sore;
      csvBuffer.writeln('${i + 1},${item.nama},${shiftData.stokAwal},${shiftData.ambilBarang},${shiftData.sisaStok}');
    }

    final text = csvBuffer.toString();
    Clipboard.setData(ClipboardData(text: text));
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('CSV $shiftTag Disalin ke Clipboard'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Format CSV telah disalin ke clipboard perangkat Anda.'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.grey.shade200,
                height: 120,
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Text(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE84C3D)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Impor CSV ke Shift Target
  void _showImportCsvDialog(int targetShift) {
    _searchFocusNode.unfocus();
    final shiftName = targetShift == 0 ? 'Shift 1 (Pagi)' : 'Shift 2 (Sore)';
    final TextEditingController textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Impor CSV ke $shiftName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tempelkan teks format .csv untuk $shiftName di bawah ini:',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'No,Nama Barang,Stok Awal,Ambil,Sisa\n1,Gula Pasir 1kg,10,2,8',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE84C3D)),
              onPressed: () {
                final rawData = textController.text.trim();
                if (rawData.isNotEmpty) {
                  _processCsvData(rawData, targetShift);
                  Navigator.pop(context);
                }
              },
              child: const Text('Terapkan Impor', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _processCsvData(String csvString, int targetShift) {
    try {
      _recordHistory();
      final lines = csvString.split('\n');
      int updatedCount = 0;
      int addedCount = 0;

      setState(() {
        for (int i = 1; i < lines.length; i++) {
          final row = lines[i].split(',');
          if (row.length >= 5) {
            final nama = row[1].trim();
            final valAwal = row[2].trim();
            final valAmbil = row[3].trim();
            final valSisa = row[4].trim();

            if (nama.isEmpty) continue;

            bool found = false;
            for (var item in _items) {
              if (item.nama.toLowerCase() == nama.toLowerCase()) {
                found = true;
                if (targetShift == 0) {
                  item.pagi.stokAwal = valAwal;
                  item.pagi.ambilBarang = valAmbil;
                  item.pagi.sisaStok = valSisa;
                } else {
                  item.sore.stokAwal = valAwal;
                  item.sore.ambilBarang = valAmbil;
                  item.sore.sisaStok = valSisa;
                }
                updatedCount++;
                break;
              }
            }

            if (!found) {
              final newItem = ItemBarang(nama: nama);
              if (targetShift == 0) {
                newItem.pagi = ShiftData(stokAwal: valAwal, ambilBarang: valAmbil, sisaStok: valSisa);
              } else {
                newItem.sore = ShiftData(stokAwal: valAwal, ambilBarang: valAmbil, sisaStok: valSisa);
              }
              _items.add(newItem);
              addedCount++;
            }
          }
        }
      });
      _saveData(skipHistory: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil memperbarui $updatedCount item dan menambah $addedCount item baru!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format CSV tidak valid! Periksa kembali teks Anda.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // --- Menu Handler Titik 3 AppBar (Requirement 4) ---
  void _handleAppBarMenu(String value) {
    switch (value) {
      case 'reset_active':
        _confirmResetData(_selectedShift);
        break;
      case 'reset_all':
        _confirmResetAllShifts();
        break;
      case 'help':
        _showHelpDialog();
        break;
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFFE84C3D)),
              SizedBox(width: 8),
              Text('Petunjuk Alur Shift'),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '1. Handover Shift 2 ke Shift 1:\n'
                  '• Saat Shift 2 selesai, buka menu titik 3 di Shift 2 lalu pilih "Ekspor Sisa Stok".\n'
                  '• Kirim/salin teks sisa stok tersebut.\n'
                  '• Besok pagi di Shift 1, buka menu titik 3 Shift 1 lalu pilih "Impor Stok Awal". Sisa kemarin langsung jadi stok awal hari ini!\n\n'
                  '2. Menggeser Urutan Baris:\n'
                  '• Tahan (long-press) baris barang beberapa saat hingga baris terangkat (elevasi berwarna merah), lalu geser ke atas atau ke bawah.\n\n'
                  '3. Undo & Redo:\n'
                  '• Gunakan ikon panah kiri (Undo) atau panah kanan (Redo) di AppBar atas untuk membatalkan atau mengulang aksi.\n\n'
                  '4. Ekspor CSV Bertanggal:\n'
                  '• Pilih menu titik 3 di tiap shift untuk mengekspor file .csv dengan nama bertanggal otomatis.',
                  style: TextStyle(fontSize: 12.5, height: 1.45),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE84C3D)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- Menu Handler Titik 3 Shift 1 (Pagi) ---
  void _handleShift1Menu(String value) {
    switch (value) {
      case 'import_handover':
        _showImportHandoverDialog();
        break;
      case 'copy_sore_direct':
        _copySoreToPagiDirect();
        break;
      case 'export_excel_file':
        _exportExcelFile(0);
        break;
      case 'export_csv_clipboard':
        _exportCsvClipboard(0);
        break;
      case 'import_csv':
        _showImportCsvDialog(0);
        break;
    }
  }

  // --- Menu Handler Titik 3 Shift 2 (Sore) ---
  void _handleShift2Menu(String value) {
    switch (value) {
      case 'export_handover':
        _showExportHandoverDialog();
        break;
      case 'export_excel_file':
        _exportExcelFile(1);
        break;
      case 'export_csv_clipboard':
        _exportCsvClipboard(1);
        break;
      case 'import_csv':
        _showImportCsvDialog(1);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ItemBarang> filteredItems = _searchQuery.isEmpty
        ? _items
        : _items
            .where((item) => item.nama.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFE84C3D),
          elevation: 2,
          title: const Text(
            'Sistem Stok Barang',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.undo,
                color: _undoStack.isNotEmpty ? Colors.white : Colors.white38,
              ),
              tooltip: 'Undo (Batal)',
              onPressed: _undoStack.isNotEmpty ? _undo : null,
            ),
            IconButton(
              icon: Icon(
                Icons.redo,
                color: _redoStack.isNotEmpty ? Colors.white : Colors.white38,
              ),
              tooltip: 'Redo (Ulangi)',
              onPressed: _redoStack.isNotEmpty ? _redo : null,
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: 'Tambah Barang',
              onPressed: _showAddBarangDialog,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              tooltip: 'Menu Lainnya',
              onSelected: _handleAppBarMenu,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'reset_active',
                  child: Row(
                    children: [
                      const Icon(Icons.refresh, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Reset Nilai ${_selectedShift == 0 ? "Shift 1" : "Shift 2"}'),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset_all',
                  child: Row(
                    children: [
                      Icon(Icons.restart_alt, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Expanded(child: Text('Reset Nilai Semua Shift')),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'help',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 18),
                      SizedBox(width: 8),
                      Expanded(child: Text('Petunjuk Alur Shift')),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Header Tab Shift Selector dengan Menu Titik 3 di Tiap Shift (Requirement 1 & Clean UI)
            Container(
              color: const Color(0xFFE84C3D),
              padding: const EdgeInsets.only(bottom: 10, left: 12, right: 12),
              child: Row(
                children: [
                  // Tab Shift 1 (Pagi)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedShift == 0 ? Colors.white : Colors.red.shade700,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _selectedShift == 0
                            ? [const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                              onTap: () {
                                _searchFocusNode.unfocus();
                                setState(() => _selectedShift = 0);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.wb_sunny_outlined,
                                      size: 16,
                                      color: _selectedShift == 0 ? const Color(0xFFE84C3D) : Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Shift 1 (Pagi)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: _selectedShift == 0 ? const Color(0xFFE84C3D) : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Titik 3 Menu Shift 1
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              size: 18,
                              color: _selectedShift == 0 ? const Color(0xFFE84C3D) : Colors.white,
                            ),
                            tooltip: 'Menu Aksi Shift 1',
                            onSelected: _handleShift1Menu,
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'import_handover',
                                child: Row(
                                  children: [
                                    Icon(Icons.assignment_returned, color: Colors.green, size: 18),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Impor Stok Awal (dari Sisa Kemarin)',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'copy_sore_direct',
                                child: Row(
                                  children: [
                                    Icon(Icons.sync_alt, color: Colors.blue, size: 18),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Salin Langsung Sisa Shift 2',
                                        style: TextStyle(fontSize: 12.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'export_excel_file',
                                child: Row(
                                  children: [
                                    Icon(Icons.table_chart, color: Colors.green, size: 18),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Simpan File Excel (.xlsx)',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'export_csv_clipboard',
                                child: Row(
                                  children: [
                                    Icon(Icons.copy, color: Colors.black87, size: 18),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Salin CSV ke Clipboard',
                                        style: TextStyle(fontSize: 12.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'import_csv',
                                child: Row(
                                  children: [
                                    Icon(Icons.upload, color: Colors.deepPurple, size: 18),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Impor CSV Shift 1',
                                        style: TextStyle(fontSize: 12.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Tab Shift 2 (Sore)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedShift == 1 ? Colors.white : Colors.red.shade700,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _selectedShift == 1
                            ? [const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                              onTap: () {
                                _searchFocusNode.unfocus();
                                setState(() => _selectedShift = 1);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.nightlight_round,
                                      size: 16,
                                      color: _selectedShift == 1 ? const Color(0xFFE84C3D) : Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Shift 2 (Sore)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: _selectedShift == 1 ? const Color(0xFFE84C3D) : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Titik 3 Menu Shift 2
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              size: 18,
                              color: _selectedShift == 1 ? const Color(0xFFE84C3D) : Colors.white,
                            ),
                            tooltip: 'Menu Aksi Shift 2',
                            onSelected: _handleShift2Menu,
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'export_handover',
                                child: Row(
                                  children: [
                                    Icon(Icons.assignment_outlined, color: Colors.orange, size: 18),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Ekspor Sisa Stok (Handover)',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'export_excel_file',
                                child: Row(
                                  children: [
                                    Icon(Icons.table_chart, color: Colors.green, size: 18),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Simpan File Excel (.xlsx)',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'export_csv_clipboard',
                                child: Row(
                                  children: [
                                    Icon(Icons.copy, color: Colors.black87, size: 18),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Salin CSV ke Clipboard',
                                        style: TextStyle(fontSize: 12.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'import_csv',
                                child: Row(
                                  children: [
                                    Icon(Icons.upload, color: Colors.deepPurple, size: 18),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Impor CSV Shift 2',
                                        style: TextStyle(fontSize: 12.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Baris Pencarian Bersih (Tanpa Tombol Berdesakan)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari nama barang...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        isDense: true,
                        fillColor: Colors.white,
                        filled: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Petunjuk Geser / Pencarian
            if (_searchQuery.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                color: Colors.amber.shade50,
                child: const Text(
                  '💡 Urutan dinonaktifkan saat pencarian aktif. Hapus teks cari untuk menggeser baris.',
                  style: TextStyle(fontSize: 11, color: Colors.brown),
                ),
              ),

            // Tabel Data Utama
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          const Text(
                            'Tidak ada data barang yang ditemukan.',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          // Header Kolom Tabel
                          Container(
                            color: Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 38,
                                  child: Text(
                                    'NO',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Nama Barang',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                                SizedBox(width: 4),
                                SizedBox(
                                  width: 42,
                                  child: Text(
                                    'Awal',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                                SizedBox(width: 4),
                                SizedBox(
                                  width: 42,
                                  child: Text(
                                    'Ambil',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                                SizedBox(width: 4),
                                SizedBox(
                                  width: 42,
                                  child: Text(
                                    'Sisa',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                                SizedBox(width: 2),
                                SizedBox(
                                  width: 56,
                                  child: Text(
                                    'Aksi',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // List Baris Data (Reorderable ListView saat tidak mencari - Requirement 2)
                          Expanded(
                            child: _searchQuery.isNotEmpty
                                ? ListView.builder(
                                    itemCount: filteredItems.length,
                                    itemExtent: 44.0,
                                    itemBuilder: (context, index) {
                                      final item = filteredItems[index];
                                      return _buildTableRow(item, index, isReorderable: false);
                                    },
                                  )
                                : ReorderableListView.builder(
                                    itemCount: _items.length,
                                    itemExtent: 44.0,
                                    buildDefaultDragHandles: false,
                                    onReorderItem: _onReorderItem,
                                    proxyDecorator: (Widget child, int index, Animation<double> animation) {
                                      return AnimatedBuilder(
                                        animation: animation,
                                        builder: (context, _) {
                                          final double elevation = lerpDouble(0, 8, animation.value) ?? 0;
                                          return Material(
                                            elevation: elevation,
                                            shadowColor: Colors.black54,
                                            color: Colors.red.shade50.withValues(alpha: 0.95),
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                border: Border.all(color: const Color(0xFFE84C3D), width: 1.8),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: child,
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    itemBuilder: (context, index) {
                                      final item = _items[index];
                                      return _buildTableRow(item, index, isReorderable: true);
                                    },
                                  ),
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

  // Builder Baris Tabel dengan Indikator Geser (Threshold / Long-press Drag)
  Widget _buildTableRow(ItemBarang item, int index, {required bool isReorderable}) {
    final shiftData = _selectedShift == 0 ? item.pagi : item.sore;
    final int realIndex = isReorderable ? index : _items.indexOf(item);

    final Widget rowContent = Container(
      height: 44.0,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : const Color(0xFFF9FAFB),
        border: const Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: Row(
        children: [
          // Kolom NO + Ikon Drag Indicator
          SizedBox(
            width: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isReorderable)
                  const Icon(Icons.drag_indicator, size: 14, color: Colors.black26)
                else
                  const SizedBox(width: 4),
                const SizedBox(width: 2),
                Text(
                  '${index + 1}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),

          // Nama Barang
          Expanded(
            flex: 3,
            child: Text(
              item.nama,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 4),

          // Stok Awal Shift
          SizedBox(
            width: 42,
            child: Text(
              shiftData.stokAwal,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 4),

          // Ambil Shift
          SizedBox(
            width: 42,
            child: Text(
              shiftData.ambilBarang,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 4),

          // Sisa Shift
          SizedBox(
            width: 42,
            child: Text(
              shiftData.sisaStok,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 2),

          // Kolom Aksi (Edit & Hapus)
          SizedBox(
            width: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () => _showEditBarangDialog(realIndex),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.edit, size: 15, color: Colors.blue),
                  ),
                ),
                InkWell(
                  onTap: () => _confirmDeleteBarang(realIndex),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.delete, size: 15, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isReorderable) {
      // Long-press delayed drag start listener agar ditahan dulu sebelum menggeser
      return ReorderableDelayedDragStartListener(
        key: ValueKey(item.id),
        index: index,
        child: rowContent,
      );
    }

    return Container(
      key: ValueKey(item.id),
      child: rowContent,
    );
  }
}

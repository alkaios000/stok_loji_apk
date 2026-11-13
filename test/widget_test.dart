import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sistem_stock_barang/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SistemStockApp smoke test and Shift tabs verification', (WidgetTester tester) async {
    await tester.pumpWidget(const SistemStockApp());
    await tester.pumpAndSettle();

    // Verify Title in AppBar
    expect(find.text('Sistem Stok Barang'), findsOneWidget);

    // Verify Shift 1 and Shift 2 Tabs exist
    expect(find.text('Shift 1 (Pagi)'), findsOneWidget);
    expect(find.text('Shift 2 (Sore)'), findsOneWidget);

    // Verify Default items rendered
    expect(find.text('Gula Pasir 1kg'), findsOneWidget);
    expect(find.text('Minyak Goreng 1L'), findsOneWidget);
    expect(find.text('Kopi Bubuk'), findsOneWidget);

    // Verify Undo/Redo icons in AppBar
    expect(find.byIcon(Icons.undo), findsOneWidget);
    expect(find.byIcon(Icons.redo), findsOneWidget);

    // Switch to Shift 2
    await tester.tap(find.text('Shift 2 (Sore)'));
    await tester.pumpAndSettle();

    // Verify Shift 2 is selected
    expect(find.text('Shift 2 (Sore)'), findsOneWidget);
  });

  testWidgets('Test Handover Shift 2 to Shift 1 Menu and Import Dialog', (WidgetTester tester) async {
    await tester.pumpWidget(const SistemStockApp());
    await tester.pumpAndSettle();

    // Tap 3-dots menu on Shift 1
    final shift1MenuButton = find.byTooltip('Menu Aksi Shift 1');
    expect(shift1MenuButton, findsOneWidget);
    await tester.tap(shift1MenuButton);
    await tester.pumpAndSettle();

    // Verify popup menu items exist
    expect(find.text('Impor Stok Awal (dari Sisa Kemarin)'), findsOneWidget);
    expect(find.text('Salin Langsung Sisa Shift 2'), findsOneWidget);
    expect(find.text('Simpan File Excel (.xlsx)'), findsOneWidget);

    // Tap Impor Stok Awal
    await tester.tap(find.text('Impor Stok Awal (dari Sisa Kemarin)'));
    await tester.pumpAndSettle();

    // Verify Dialog opened
    expect(find.text('Impor Stok Awal Shift 1'), findsOneWidget);
    expect(find.text('Tempel dari Clipboard'), findsOneWidget);
    expect(find.text('Terapkan Stok Awal'), findsOneWidget);

    // Enter test handover text in dialog TextField
    final dialogTextField = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(dialogTextField, 'Gula Pasir 1kg : 25');
    await tester.tap(find.text('Terapkan Stok Awal'));
    await tester.pumpAndSettle();

    // Verify Stok Awal is 25, while Sisa is 0
    expect(find.text('25'), findsOneWidget);
  });

  testWidgets('Test AppBar 3-Dots Menu has Reset and Help options', (WidgetTester tester) async {
    await tester.pumpWidget(const SistemStockApp());
    await tester.pumpAndSettle();

    // Tap AppBar 3-dots menu
    final appBarMenu = find.byTooltip('Menu Lainnya');
    expect(appBarMenu, findsOneWidget);
    await tester.tap(appBarMenu);
    await tester.pumpAndSettle();

    // Verify Reset and Help options
    expect(find.text('Reset Nilai Shift 1'), findsOneWidget);
    expect(find.text('Reset Nilai Semua Shift'), findsOneWidget);
    expect(find.text('Petunjuk Alur Shift'), findsOneWidget);

    // Tap Petunjuk Alur Shift item to check dialog
    await tester.tap(find.text('Petunjuk Alur Shift'));
    await tester.pumpAndSettle();

    expect(find.text('Petunjuk Alur Shift'), findsWidgets);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
  });

  testWidgets('Test Add Item, Undo, and Redo flow', (WidgetTester tester) async {
    await tester.pumpWidget(const SistemStockApp());
    await tester.pumpAndSettle();

    // Find Undo and Redo IconButtons
    final undoBtn = find.ancestor(of: find.byIcon(Icons.undo), matching: find.byType(IconButton));
    final redoBtn = find.ancestor(of: find.byIcon(Icons.redo), matching: find.byType(IconButton));
    expect(tester.widget<IconButton>(undoBtn).onPressed, isNull);
    expect(tester.widget<IconButton>(redoBtn).onPressed, isNull);

    // Tap Add Button
    await tester.tap(find.byTooltip('Tambah Barang'));
    await tester.pumpAndSettle();

    // Enter name
    await tester.enterText(find.widgetWithText(TextField, 'Nama Barang / Satuan'), 'Nuget Crispy 500g');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // Nuget Crispy should now exist in list
    expect(find.text('Nuget Crispy 500g'), findsOneWidget);

    // Now Undo should be enabled!
    expect(tester.widget<IconButton>(undoBtn).onPressed, isNotNull);

    // Tap Undo
    await tester.tap(undoBtn);
    await tester.pumpAndSettle();

    // Nuget Crispy should be undone!
    expect(find.text('Nuget Crispy 500g'), findsNothing);

    // Redo should now be enabled!
    expect(tester.widget<IconButton>(redoBtn).onPressed, isNotNull);

    // Tap Redo
    await tester.tap(redoBtn);
    await tester.pumpAndSettle();

    // Nuget Crispy should be back!
    expect(find.text('Nuget Crispy 500g'), findsOneWidget);
  });

  testWidgets('Test Edit Modal Shortcuts and Zero Suppression UX', (WidgetTester tester) async {
    await tester.pumpWidget(const SistemStockApp());
    await tester.pumpAndSettle();

    // Tap Edit on first item (Gula Pasir 1kg)
    final editIcons = find.byIcon(Icons.edit);
    expect(editIcons, findsWidgets);
    await tester.tap(editIcons.first);
    await tester.pumpAndSettle();

    // Verify modal is shown
    expect(find.text('Edit Data (Shift 1 Pagi)'), findsOneWidget);

    // Initial state UX: shortcuts are NOT shown yet (user hasn't tapped any input)
    expect(find.text('masih'), findsNothing);
    expect(find.text('banyak'), findsNothing);
    expect(find.text('sedikit'), findsNothing);
    expect(find.text('habis'), findsNothing);
    expect(find.text('Thinwal'), findsNothing);
    expect(find.text('botol'), findsNothing);
    expect(find.text('pack'), findsNothing);
    expect(find.text('pcs'), findsNothing);

    // Find TextFields in the dialog
    final dialogTextFields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    // Index 3 corresponds to Sisa TextField (has initial value '8')
    await tester.tap(dialogTextFields.at(3));
    await tester.pumpAndSettle();

    // Since Sisa has initial number '8', unit shortcuts appear under it!
    expect(find.text('Thinwal'), findsOneWidget);
    expect(find.text('botol'), findsOneWidget);
    expect(find.text('pack'), findsOneWidget);
    expect(find.text('pcs'), findsOneWidget);
    expect(find.text('masih'), findsNothing);

    // Clear the text so it has no digits
    final sisaInput = dialogTextFields.at(3);
    await tester.enterText(sisaInput, '');
    await tester.pumpAndSettle();

    // Without numbers, status shortcuts appear!
    expect(find.text('masih'), findsOneWidget);
    expect(find.text('banyak'), findsOneWidget);
    expect(find.text('sedikit'), findsOneWidget);
    expect(find.text('habis'), findsOneWidget);
    expect(find.text('Thinwal'), findsNothing);

    // Tap "masih" shortcut -> Sisa becomes "masih"
    await tester.tap(find.text('masih'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'masih'), findsOneWidget);

    // Now type a number into Sisa: '5'
    await tester.enterText(sisaInput, '5');
    await tester.pumpAndSettle();

    // Status shortcuts should disappear and be replaced by unit shortcuts!
    expect(find.text('masih'), findsNothing);
    expect(find.text('Thinwal'), findsOneWidget);
    expect(find.text('botol'), findsOneWidget);
    expect(find.text('pack'), findsOneWidget);
    expect(find.text('pcs'), findsOneWidget);

    // Tap "pack" shortcut -> should auto-combine to "5 pack"
    await tester.tap(find.text('pack'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '5 pack'), findsOneWidget);

    // Tap "botol" shortcut -> should auto-switch unit to "5 botol"
    await tester.tap(find.text('botol'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '5 botol'), findsOneWidget);

    // Save changes
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    // Verify updated value in table row
    expect(find.text('5 botol'), findsOneWidget);
  });

  testWidgets('Test Edit Modal field switching and zero suppression', (WidgetTester tester) async {
    await tester.pumpWidget(const SistemStockApp());
    await tester.pumpAndSettle();

    // Add a new item with 0 values
    await tester.tap(find.byTooltip('Tambah Barang'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Nama Barang / Satuan'), 'Kecap Manis');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // Tap edit on the newly added item
    final editIcons = find.byIcon(Icons.edit);
    await tester.tap(editIcons.last);
    await tester.pumpAndSettle();

    // Check that inputs for 0 values are empty (suppressed)
    final dialogTextFields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    // Index 1 = Stok Awal, Index 2 = Ambil, Index 3 = Sisa
    expect(tester.widget<TextField>(dialogTextFields.at(1)).controller?.text, '');
    expect(tester.widget<TextField>(dialogTextFields.at(2)).controller?.text, '');
    expect(tester.widget<TextField>(dialogTextFields.at(3)).controller?.text, '');

    // Tap Stok Awal -> status buttons appear
    await tester.tap(dialogTextFields.at(1));
    await tester.pumpAndSettle();
    expect(find.text('masih'), findsOneWidget);

    // Enter number '12' in Stok Awal -> switches to units
    await tester.enterText(dialogTextFields.at(1), '12');
    await tester.pumpAndSettle();
    expect(find.text('Thinwal'), findsOneWidget);

    // Tap Thinwal -> becomes '12 Thinwal'
    await tester.tap(find.text('Thinwal'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '12 Thinwal'), findsOneWidget);

    // Tap Ambil (empty) -> status buttons appear for Ambil
    await tester.tap(dialogTextFields.at(2));
    await tester.pumpAndSettle();
    expect(find.text('habis'), findsOneWidget);

    // Tap habis -> Ambil becomes 'habis'
    await tester.tap(find.text('habis'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'habis'), findsOneWidget);

    // Save and verify table row has '12 Thinwal' and 'habis'
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(find.text('12 Thinwal'), findsOneWidget);
    expect(find.text('habis'), findsOneWidget);
  });
}

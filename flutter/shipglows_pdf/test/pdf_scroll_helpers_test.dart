import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_pdf/src/pdf_document_viewer.dart';

void main() {
  group('pdfWidthStep', () {
    test('is zero for a zero-width tile', () {
      expect(pdfWidthStep(0), 0);
    });

    test('rounds to the nearest 32 px step', () {
      expect(pdfWidthStep(15), 0);
      expect(pdfWidthStep(16), 1);
      expect(pdfWidthStep(31), 1);
      expect(pdfWidthStep(111), 3);
      expect(pdfWidthStep(112), 4);
    });

    test('keeps the same bucket for small resizes', () {
      expect(pdfWidthStep(600), pdfWidthStep(605));
    });

    test('changes bucket when a 32 px step is crossed', () {
      expect(pdfWidthStep(600), isNot(pdfWidthStep(632)));
    });
  });
}

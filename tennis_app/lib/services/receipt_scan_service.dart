import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:tennis_app/models/receipt_scan_model.dart';

// อ่านราคาจากรูปหลักฐานการจอง กันผู้ขายกรอกราคาที่จองมาสูงเกินจริง
// แยกเป็น abstract ไว้ ถ้าวันหลังเปลี่ยนไปอ่านที่ server ก็เขียนคลาสใหม่แล้วสลับตัวเดียว
abstract class ReceiptScanService {
  // คืนราคาที่อ่านได้ หรือ null ถ้าหาราคาในรูปไม่เจอ
  Future<int?> scanPrice(String imagePath);

  Future<void> close();
}

// อ่านตัวอักษรในรูปด้วย Google ML Kit บนเครื่อง (ไม่ต้องใช้เน็ต, ใช้ได้เฉพาะ Android / iOS)
// ใช้ชุดอักษรละติน: อ่านตัวเลขและภาษาอังกฤษได้ แต่อ่านภาษาไทยไม่ได้
class ReceiptScanMlKitService implements ReceiptScanService {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  @override
  Future<int?> scanPrice(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText result = await _recognizer.processImage(inputImage);
    ReceiptText receipt = ReceiptText.fromText(result.text);
    // ตอน debug พิมพ์ข้อความที่ ML Kit อ่านได้ ไว้ดูว่าทำไมได้ราคานี้
    if (kDebugMode) {
      debugPrint('OCR text:\n${result.text}\nOCR price: ${receipt.price}');
    }
    return receipt.price;
  }

  // ML Kit จองหน่วยความจำฝั่ง native ไว้ ต้องปิดเมื่อเลิกใช้
  @override
  Future<void> close() async {
    await _recognizer.close();
  }
}

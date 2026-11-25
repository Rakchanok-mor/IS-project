// ข้อความที่ OCR อ่านได้จากรูปหลักฐานการจอง แล้วหาว่าตัวเลขไหนคือ "ราคาที่จ่ายไป"
// แยกไว้ใน model (ไม่ผูกกับ ML Kit) จะได้ทดสอบกับข้อความตัวอย่างได้โดยไม่ต้องใช้รูป

// ราคาที่ถือว่าสมเหตุสมผล (ตัดตัวเลขเล็ก ๆ อย่างจำนวนชั่วโมง/คอร์ท และเลขยาว ๆ อย่างเบอร์โทร)
const int kMinReceiptPrice = 10;
const int kMaxReceiptPrice = 100000;

class ReceiptText {
  List<String> lines;

  ReceiptText(this.lines);

  // แตกข้อความทั้งก้อนเป็นบรรทัด ตัดบรรทัดว่างทิ้ง
  factory ReceiptText.fromText(String text) {
    List<String> lines;
    lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return ReceiptText(lines);
  }

  // คำที่บอกว่าเป็น "ยอดสุดท้าย" (subtotal ไม่นับ เพราะยังไม่หักส่วนลด)
  // ML Kit บน iOS อ่านอักษรไทยไม่ได้ คำไทยจึงช่วยได้เฉพาะบางเครื่อง
  static final RegExp _totalWord = RegExp(
    r'\btotal\b|\bpaid\b|\bgrand\b|\bnet\b|ยอดชำระ|ยอดรวม|รวม',
    caseSensitive: false,
  );

  // คำที่บอกว่าเป็นราคา แต่อาจไม่ใช่ยอดสุดท้าย
  // (ไม่ใช้คำว่า payment เพราะเจอใน "Proof of payment uploaded" ที่บรรทัดถัดไปเป็นวันที่)
  static final RegExp _priceWord = RegExp(
    r'\bamount\b|\bprice\b|\bfee\b|\bcharge\b|ราคา|ค่า',
    caseSensitive: false,
  );

  // รูปแบบตัวเลขราคา: 1200, 1,200, 1.200 (OCR อ่านลูกน้ำเป็นจุด), 1,200.00
  static const String _number =
      r'(\d{1,3}(?:[,.]\d{3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)';

  // สัญลักษณ์เงินบาทหน้าหรือหลังตัวเลข
  // (OCR บางทีอ่าน ฿ เป็นตัว B จึงรับ B ด้วย แต่ต้องมีตัวคั่นหลักพันหรือ .00 กันสับสนกับรหัส)
  static final RegExp _currencyAmount = RegExp(
    '(?:฿|THB|Baht)\\s*$_number'
    '|$_number\\s*(?:฿|THB|Baht|บาท)'
    r'|\bB\s?(\d{1,3}(?:[,.]\d{3})+(?:\.\d{2})?|\d+\.\d{2})\b',
    caseSensitive: false,
  );

  // ตัวเลขเดี่ยว ๆ ที่ไม่ติดกับตัวอักษรหรือขีด (ไม่เอา CS-00017, A12)
  static final RegExp _bareAmount = RegExp(
    '(?<![\\w\\-.,])$_number(?![\\w\\-,]|\\.\\d)',
  );

  static const String _month =
      r'(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?';

  // ส่วนที่ไม่ใช่ราคาแน่ ๆ ลบทิ้งก่อนหาตัวเลข: เวลา วันที่ และตัวเลขที่มีหน่วยอื่นต่อท้าย
  static final List<RegExp> _notPrice = [
    RegExp(r'\b\d{1,2}[:.]\d{2}\s*[-–]\s*\d{1,2}[:.]\d{2}\b'), // 18.00-20.00
    RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\b'), // 18:00
    RegExp(
      r'\b\d{1,2}(?::\d{2})?\s*(?:am|pm)\b',
      caseSensitive: false,
    ), // 6 AM, 5:29 PM
    RegExp(r'\b\d{1,4}[/-]\d{1,2}[/-]\d{1,4}\b'), // 24/11/2026
    RegExp(
      '\\b$_month\\s+\\d{1,2}(?:st|nd|rd|th)?,?(?:\\s+\\d{4})?\\b',
      caseSensitive: false,
    ), // Jun 2, 2026
    RegExp(
      '\\b\\d{1,2}(?:st|nd|rd|th)?\\s+$_month,?(?:\\s+\\d{4})?\\b',
      caseSensitive: false,
    ), // 7 June 2026
    RegExp(
      r'\b\d+\s*(?:min|mins|minutes?|hrs?|hours?|courts?|persons?|people|ชม|ชั่วโมง|นาที|คน)\b',
      caseSensitive: false,
    ),
  ];

  String _cleanLine(String line) {
    String cleaned = line;
    for (final pattern in _notPrice) {
      cleaned = cleaned.replaceAll(pattern, ' ');
    }
    return cleaned;
  }

  // "1,200.50" → 1200 (ปัดเศษสตางค์ทิ้ง ไม่ให้ราคาสูงกว่าที่จ่ายจริง)
  // "1.200" (จุดตามด้วยเลข 3 หลัก) = OCR อ่านลูกน้ำเป็นจุด → 1200
  int? _toPrice(String text) {
    String digits = text.replaceAll(',', '');
    if (RegExp(r'^\d{1,3}(?:\.\d{3})+(?:\.\d{1,2})?$').hasMatch(text)) {
      final parts = text.split('.');
      final hasCents = parts.last.length < 3;
      final whole = hasCents ? parts.sublist(0, parts.length - 1) : parts;
      digits = whole.join();
    }
    final number = double.tryParse(digits);
    if (number == null) return null;
    final price = number.floor();
    if (price < kMinReceiptPrice || price > kMaxReceiptPrice) return null;
    return price;
  }

  // ราคาที่มีสัญลักษณ์เงินกำกับ
  List<int> _currencyAmountsIn(String line) {
    final List<int> amounts = [];
    for (final match in _currencyAmount.allMatches(_cleanLine(line))) {
      final text = match.group(1) ?? match.group(2) ?? match.group(3);
      final price = text == null ? null : _toPrice(text);
      if (price != null) amounts.add(price);
    }
    return amounts;
  }

  // ตัวเลขทุกตัวในบรรทัด (ใช้เฉพาะบรรทัดที่มีคำว่า total/price อยู่แล้ว)
  List<int> _allAmountsIn(String line) {
    final List<int> amounts = _currencyAmountsIn(line);
    for (final match in _bareAmount.allMatches(_cleanLine(line))) {
      final price = _toPrice(match.group(0)!);
      if (price != null) amounts.add(price);
    }
    return amounts;
  }

  // บรรทัดนี้ (หรือบรรทัดก่อนหน้าที่เป็นหัวข้อเฉย ๆ เช่น "Total amount" แล้วราคาอยู่บรรทัดล่าง)
  // มีคำที่ต้องการไหม
  bool _isUnder(RegExp word, int index) {
    final line = lines[index];
    if (word.hasMatch(line) && !line.toLowerCase().contains('sub')) {
      return true;
    }
    if (index == 0) return false;
    final previous = lines[index - 1];
    return word.hasMatch(previous) &&
        !previous.toLowerCase().contains('sub') &&
        _allAmountsIn(previous).isEmpty;
  }

  // ราคาที่อ่านได้ (null = หาไม่เจอ)
  // 1. มีบรรทัดยอดรวม (Total / Paid) → เอาตัวล่างสุด เพราะยอดสุดท้ายมักอยู่ท้ายใบ
  // 2. ไม่มี → เอาตัวมากสุดจากบรรทัดที่มีคำว่าราคาหรือมีสัญลักษณ์เงิน
  // ไม่มีทั้งสองแบบ → ไม่เดา ให้ผู้ขายแนบรูปใหม่
  int? get price {
    final List<int> totals = [];
    final List<int> others = [];

    for (int i = 0; i < lines.length; i++) {
      if (_isUnder(_totalWord, i)) {
        totals.addAll(_allAmountsIn(lines[i]));
      } else if (_isUnder(_priceWord, i)) {
        others.addAll(_allAmountsIn(lines[i]));
      } else {
        others.addAll(_currencyAmountsIn(lines[i]));
      }
    }

    if (totals.isNotEmpty) return totals.last;
    if (others.isNotEmpty) {
      return others.reduce((a, b) => a > b ? a : b);
    }
    return null;
  }
}

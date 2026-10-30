class PunPunLogic {
  // ลอจิกที่ 1: ตรวจสอบรูปแบบอีเมล
  static bool isValidEmail(String email) {
    if (email.trim().isEmpty) return false;
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  // ลอจิกที่ 2: ตรวจสอบความปลอดภัยรหัสผ่าน (ต้อง 6 ตัวขึ้นไป)
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  // ลอจิกที่ 3: ตรวจสอบชื่อสิ่งของ (ต้องไม่เป็นค่าว่าง และไม่เกิน 50 ตัวอักษร)
  static bool isValidItemName(String name) {
    return name.trim().isNotEmpty && name.length <= 50;
  }

  // ลอจิกที่ 4: คำนวณ Trust Score (ให้ของสำเร็จ +10, ผิดนัดลด 5)
  static int calculateTrustScore(int currentScore, bool isSuccess) {
    if (isSuccess) return currentScore + 10;
    return (currentScore - 5 < 0) ? 0 : currentScore - 5;
  }

  // ลอจิกที่ 5: ตรวจสอบว่าโพสต์หมดอายุหรือยัง
  static bool isExpired(DateTime expiryDate, DateTime currentDate) {
    return currentDate.isAfter(expiryDate);
  }
}
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/utils/punpun_logic.dart'; // ตรวจสอบชื่อ flutter_application_1 ให้ตรงกับใน pubspec.yaml
void main() {
  group('PunPun App Unit Tests (Week 5)', () {
    
    // ==========================================
    // ชุดที่ 1: ทดสอบการตรวจสอบอีเมล (Email Validation)
    // ==========================================
    test('Case 1: อีเมลรูปแบบถูกต้อง ต้องคืนค่า true', () {
      expect(PunPunLogic.isValidEmail('mos@email.com'), true);
    });

    test('Case 2: อีเมลไม่มีเครื่องหมาย @ ต้องคืนค่า false', () {
      expect(PunPunLogic.isValidEmail('mosemail.com'), false);
    });

    test('Case 3: อีเมลเป็นค่าว่างเปล่า ต้องคืนค่า false', () {
      expect(PunPunLogic.isValidEmail('   '), false);
    });

    // ==========================================
    // ชุดที่ 2: ทดสอบรหัสผ่าน (Password Validation)
    // ==========================================
    test('Case 4: รหัสผ่าน 6 ตัวอักษรขึ้นไป ต้องผ่าน (true)', () {
      expect(PunPunLogic.isValidPassword('123456'), true);
    });

    test('Case 5: รหัสผ่านน้อยกว่า 6 ตัวอักษร ต้องไม่ผ่าน (false)', () {
      expect(PunPunLogic.isValidPassword('12345'), false);
    });

    // ==========================================
    // ชุดที่ 3: ทดสอบชื่อสิ่งของ (Item Name Validation)
    // ==========================================
    test('Case 6: ชื่อสิ่งของถูกต้อง (ไม่ว่างและไม่เกิน 50 ตัวอักษร)', () {
      expect(PunPunLogic.isValidItemName('เสื้อยืดมือสอง สภาพดี'), true);
    });

    test('Case 7: ชื่อสิ่งของเป็นค่าว่าง ต้องไม่ผ่าน (false)', () {
      expect(PunPunLogic.isValidItemName(''), false);
    });

    // ==========================================
    // ชุดที่ 4: ทดสอบระบบคะแนนความน่าเชื่อถือ (Trust Score)
    // ==========================================
    test('Case 8: ส่งมอบของสำเร็จ Trust Score ต้องเพิ่ม 10 คะแนน', () {
      expect(PunPunLogic.calculateTrustScore(100, true), 110);
    });

    test('Case 9: ผิดนัดการส่งมอบ Trust Score ต้องลด 5 คะแนน', () {
      expect(PunPunLogic.calculateTrustScore(100, false), 95);
    });

    // ==========================================
    // ชุดที่ 5: ทดสอบวันหมดอายุของโพสต์ (Expiry Date)
    // ==========================================
    test('Case 10: วันปัจจุบันเลยวันหมดอายุไปแล้ว ต้องคืนค่า true', () {
      final expiryDate = DateTime(2026, 10, 20);
      final currentDate = DateTime(2026, 10, 26);
      expect(PunPunLogic.isExpired(expiryDate, currentDate), true);
    });

  });
}
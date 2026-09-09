# Solutions

## Part A — Bug tickets


### RES-101 · Search shows results for the wrong query

**Root cause**:
<!-- 
    เกิดปัญหา Race Condition จากการเรียก Network request แบบ Asynchronous เมื่อผู้ใช้พิมพ์คำค้นหาอย่างรวดเร็ว เช่น "s", "su", "sush", "sushi" ระบบจะส่ง Request ออกไปหลายตัวติดๆกัน เนื่องจาก Network Latency ของ Fake API มีความหน่วงไม่เท่ากัน หาก Request ของคำเก่า เช่น "su" โหลดเสร็จและตอบกลับมาทีหลังคำล่าสุด "sushi" โค้ดเดิมจะนำผลลัพธ์ของ "su" ไปเขียนทับ Overwrite ข้อมูลล่าสุด ทำให้ UI แสดงผลลัพธ์ผิดจากคำที่อยู่ในช่องค้นหา 
-->

**Fix**:
<!-- 
    เพิ่มตัวแปร _latestSearchQuery ไว้ในระดับ Class เพื่อคอยจับว่าคำค้นหาล่าสุดคือคำว่าอะไร ทุกครั้งที่เริ่มฟังก์ชัน _search จะอัปเดตตัวแปรนี้ และเมื่อ API โหลดข้อมูลเสร็จหลัง await จะมีการสร้างเงื่อนไขตรวจสอบว่า currentQuery ของ Request นี้ยังตรงกับ _latestSearchQuery อยู่หรือไม่ ถ้ายืนยันว่าตรงกัน จึงจะอนุญาตให้อัปเดต results และปิด isLoading 
-->

**Alternative considered & rejected**:
<!-- 
    การใช้ Debounce หน่วงเวลา 300-500ms ค่อยยิง API ปฏิเสธไปแม้จะเป็นวิธีที่ดีในการลดภาระฝั่งเซิร์ฟเวอร์ แต่มัน ไม่ได้แก้ปัญหา Race condition ตรงๆ หาก Request แรกเจอ Network delay ที่นานผิดปกติจนตอบกลับหลัง Request ที่สอง ปัญหานี้ก็จะยังเกิดซ้ำอยู่ดี 
-->

**Edge cases**:
<!--    
        1. ช่องว่าง White-spaces จัดการโดยใช้ query.trim() ตั้งแต่ต้นฟังก์ชัน เพื่อป้องกันไม่ให้การเคาะ Spacebar รัวๆ ถูกนับเป็น Request ใหม่ที่ต่างออกไป
        2. การจัดการสถานะ Loading กระพริบ: ถ้า Request เก่ามีข้อผิดพลาดโยน Exception เข้า catch หรือโหลดเสร็จทีหลัง การสั่ง isLoading.value = false แบบสุ่มสี่สุ่มห้าอาจทำให้หน้าจอที่กำลังรอ Request ใหม่ปิดวงล้อโหลดไปก่อน จึงต้องเช็ค _latestSearchQuery == currentQuery ก่อนปิดสถานะโหลดในขั้นตอนสุดท้าย หรือ finally ด้วยเช่นกัน
        3. พิมพ์แล้วลบจนหมดอย่างรวดเร็ว: ดักจับด้วยเช็ค query.isEmpty ตั้งแต่แรก ถ้าพบว่าว่าง จะเคลียร์ค่าทั้งหมด รีเซ็ต hasSearched และ return ออกทันทีโดยไม่ส่ง Request ไปรบกวน API 
-->

---

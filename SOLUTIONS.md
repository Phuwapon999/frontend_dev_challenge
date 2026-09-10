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

### RES-102 · Crash after leaving My orders


**Root cause**:
<!--
        วิดเจ็ต PickupCountdown ใน pickup_countdown.dart มีการใช้ Timer.periodic เพื่อนับเวลาถอยหลังและเรียก setState() ทุกๆ 1 วินาที แต่ตัวคลาส State ขาดฟังก์ชัน dispose() เพื่อยกเลิกการทำงานของ Timer เมื่อผู้ใช้กดออกจากหน้าจอ สิ่งนี้ทำให้ Timer ยังคงทำงานอยู่เบื้องหลังและพยายามเรียกอัปเดต UI บนหน้าจอที่ถูกทำลายไปแล้ว จึงเกิด Error setState() called after dispose() และก่อให้เกิด Memory Leak
-->

**Fix**:
<!--
        เพิ่มฟังก์ชัน dispose() เข้าไปใน _PickupCountdownState และทำการสั่ง _timer?.cancel(); ก่อนเรียก super.dispose(); โดยต้องมั่นใจว่าตอนสร้าง Timer ใน initState ได้เอาตัวแปร _timer มารับค่าไว้แล้วเพื่อให้ Lifecycle ของ Timer จบลงพร้อมกับวิดเจ็ตอย่างถูกต้อง
-->

**Alternative considered & rejected**:
<!--
        การใช้ if (!mounted) return; ก่อนเรียก setState(): วิธีนี้ถูกปฏิเสธอย่างเด็ดขาด เพราะแม้จะป้องกันไม่ให้แอปแครชได้ แต่มันเป็นการแค่ซ่อนอาการตัว Timer จะยังคงแอบทำงานวนลูป 1 วินาทีไปเรื่อยๆ แบบไม่มีวันจบ กินทรัพยากร CPU และก่อให้เกิด Memory Leak ที่ร้ายแรงกว่าเดิมเมื่อเปิดหน้าต่างนี้ซ้ำๆ
-->

**Edge cases**:
<!--
        ผู้ใช้เข้าและออกหน้าจออย่างรวดเร็วป้องกันการแครชด้วยการใช้ _timer?.cancel() มีเครื่องหมาย ? เพื่อรองรับกรณีที่หน้าจอถูกปิด dispose ไปก่อนที่ฟังก์ชัน initState จะสร้าง Timer เสร็จ หรือกรณีที่ตัวแปรยังเป็น null อยู่
-->

---

### RES-103 · Requests pile up the longer you browse


**Root cause**:
<!--
        เกิด Memory Leak จาก Listener ข้าม Lifecycle ระหว่าง Controller ที่ DealController ไปผูกกับ Service ที่ cartService ด้วยคำสั่ง ever() เมื่อผู้ใช้ปิดหน้าจอ DealController ไม่สามารถถูก Garbage Collected ได้เพราะ cartService ยังถือ Reference ของฟังก์ชัน _recheckAvailability ไว้ทำให้เมื่อตะกร้าสินค้ามีการเปลี่ยนแปลงตัว Controller เก่าๆทั้งหมดจึงถูกปลุกขึ้นมายิง API โหลดข้อมูลซ้ำพร้อมๆกัน
-->

**Fix**:
<!--
       นำตัวแปร Worker มารับค่าจากคำสั่ง ever() และทำการสั่ง _cartWorker?.dispose() ภายในฟังก์ชัน onClose() ของ GetxController เพื่อถอด Listener ออกอย่างสมบูรณ์เมื่อผู้ใช้ปิดหน้านั้นๆ
-->

**Alternative considered & rejected**:
<!--
        การเช็ค if Get.isRegistered<DealController>() ภายใน ever ปฏิเสธไปเพราะเป็นการแก้ที่ปลายเหตุ ตัว Listener ก็ยังคงเกาะกิน Memory อยู่ดี
-->

---

### RES-104 · Duplicate deals in the home feed


**Root cause**:
<!--
        เกิดปัญหา Race Condition ระหว่างฟังก์ชันดึงรีเฟรชและฟังก์ชันโหลดหน้าถัดไป เมื่อผู้ใช้เลื่อนลงสุดจอจนระบบกำลังรอผลลัพธ์ของ loadMore แล้วผู้ใช้ทำการดึงจอเพื่อรีเฟรชทันที จะทำให้มี 2 Request ทำงานขนานกัน เมื่อ loadMore โหลดข้อมูลหน้า 2 เสร็จทีหลัง มันจะนำข้อมูลนั้นไปต่อท้ายข้อมูลหน้า 1 ที่เพิ่งถูกรีเฟรชมาใหม่ทำให้เกิดข้อมูลเบิ้ล ข้อมูลข้ามหน้าและจำนวนไอเทมเพี้ยนจากความเป็นจริง
-->

**Fix**:
<!--
       แก้ปัญหาด้วยเทคนิค Request ID Tracking โดยสร้างตัวแปร int _currentRequestId = 0 เมื่อมีการดึงรีเฟรชจะทำการบวกค่านี้ขึ้น 1 เสมอ ฟังก์ชันทั้งสองจะทำการจำค่า requestId ณ เวลาที่ถูกเรียกไว้ในตัวแปรโลคัล ก่อนทำการยิง API await เมื่อข้อมูลโหลดเสร็จ จะทำการตรวจสอบเงื่อนไข if (requestId != _currentRequestId) หากค่าไม่ตรงกันแปลว่ามีการรีเฟรชเกิดขึ้นระหว่างทาง ระบบจะทำการ Discard ข้อมูลชุดนั้นและ return ออกทันที เพื่อป้องกันการนำข้อมูลเก่ามาเขียนทับหรือต่อท้ายข้อมูลใหม่
-->

**Alternative considered & rejected**:
<!--
       การเช็ค if (_page == 1) ภายใน loadMore เพื่อดักจับการรีเซ็ตหน้าปฏิเสธไป เพราะถ้า Request ของ refreshDeals ทำงานเสร็จก่อน ค่า _page จะเป็น 1 อยู่ดี ทำให้ loadMore สามารถหลุดรอดเงื่อนไขมานำข้อมูลหน้า 2 ไปต่อท้ายหน้า 1 ได้เหมือนเดิม
-->

**Edge cases**:
<!--
        ภายใน loadMore มีการอัปเดต _isFetchingMore = false ก่อนที่จะ return ทิ้งเมื่อ Request ID ไม่ตรงกัน เพื่อป้องกันไม่ให้สถานะการโหลดค้างและทำให้ผู้ใช้ไม่สามารถโหลดหน้าถัดไปได้อีกในอนาคต
-->
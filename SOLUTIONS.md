## Part A — Bug tickets


### RES-101 · Search shows results for the wrong query

**Root cause**:

- เกิดปัญหา Race Condition จากการเรียก Network request แบบ Asynchronous เมื่อผู้ใช้พิมพ์คำค้นหาอย่างรวดเร็ว เช่น "s", "su", "sush", "sushi" ระบบจะส่ง Request ออกไปหลายตัวติดๆกัน เนื่องจาก Network Latency ของ Fake API มีความหน่วงไม่เท่ากัน หาก Request ของคำเก่า เช่น "su" โหลดเสร็จและตอบกลับมาทีหลังคำล่าสุด "sushi" โค้ดเดิมจะนำผลลัพธ์ของ "su" ไปเขียนทับ Overwrite ข้อมูลล่าสุด ทำให้ UI แสดงผลลัพธ์ผิดจากคำที่อยู่ในช่องค้นหา 

**Fix**:

- เพิ่มตัวแปร _latestSearchQuery ไว้ในระดับ Class เพื่อคอยจับว่าคำค้นหาล่าสุดคือคำว่าอะไร ทุกครั้งที่เริ่มฟังก์ชัน _search จะอัปเดตตัวแปรนี้ และเมื่อ API โหลดข้อมูลเสร็จหลัง await จะมีการสร้างเงื่อนไขตรวจสอบว่า currentQuery ของ Request นี้ยังตรงกับ _latestSearchQuery อยู่หรือไม่ ถ้ายืนยันว่าตรงกัน จึงจะอนุญาตให้อัปเดต results และปิด isLoading 

**Alternative considered & rejected**:

- การใช้ Debounce หน่วงเวลา 300-500ms ค่อยยิง API ปฏิเสธไปแม้จะเป็นวิธีที่ดีในการลดภาระฝั่งเซิร์ฟเวอร์ แต่มัน ไม่ได้แก้ปัญหา Race condition ตรงๆ หาก Request แรกเจอ Network delay ที่นานผิดปกติจนตอบกลับหลัง Request ที่สอง ปัญหานี้ก็จะยังเกิดซ้ำอยู่ดี 

**Edge cases**:

1. ช่องว่าง White-spaces จัดการโดยใช้ query.trim() ตั้งแต่ต้นฟังก์ชัน เพื่อป้องกันไม่ให้การเคาะ Spacebar รัวๆ ถูกนับเป็น Request ใหม่ที่ต่างออกไป
2. การจัดการสถานะ Loading กระพริบ: ถ้า Request เก่ามีข้อผิดพลาดโยน Exception เข้า catch หรือโหลดเสร็จทีหลัง การสั่ง isLoading.value = false แบบสุ่มสี่สุ่มห้าอาจทำให้หน้าจอที่กำลังรอ Request ใหม่ปิดวงล้อโหลดไปก่อน จึงต้องเช็ค _latestSearchQuery == currentQuery ก่อนปิดสถานะโหลดในขั้นตอนสุดท้าย หรือ finally ด้วยเช่นกัน
3. พิมพ์แล้วลบจนหมดอย่างรวดเร็ว: ดักจับด้วยเช็ค query.isEmpty ตั้งแต่แรก ถ้าพบว่าว่าง จะเคลียร์ค่าทั้งหมด รีเซ็ต hasSearched และ return ออกทันทีโดยไม่ส่ง Request ไปรบกวน API 

---

### RES-102 · Crash after leaving My orders

**Root cause**:

- วิดเจ็ต PickupCountdown ใน pickup_countdown.dart มีการใช้ Timer.periodic เพื่อนับเวลาถอยหลังและเรียก setState() ทุกๆ 1 วินาที แต่ตัวคลาส State ขาดฟังก์ชัน dispose() เพื่อยกเลิกการทำงานของ Timer เมื่อผู้ใช้กดออกจากหน้าจอ สิ่งนี้ทำให้ Timer ยังคงทำงานอยู่เบื้องหลังและพยายามเรียกอัปเดต UI บนหน้าจอที่ถูกทำลายไปแล้ว จึงเกิด Error setState() called after dispose() และก่อให้เกิด Memory Leak

**Fix**:

- เพิ่มฟังก์ชัน dispose() เข้าไปใน _PickupCountdownState และทำการสั่ง _timer?.cancel(); ก่อนเรียก super.dispose(); โดยต้องมั่นใจว่าตอนสร้าง Timer ใน initState ได้เอาตัวแปร _timer มารับค่าไว้แล้วเพื่อให้ Lifecycle ของ Timer จบลงพร้อมกับวิดเจ็ตอย่างถูกต้อง

**Alternative considered & rejected**:

- การใช้ if (!mounted) return; ก่อนเรียก setState(): วิธีนี้ถูกปฏิเสธอย่างเด็ดขาด เพราะแม้จะป้องกันไม่ให้แอปแครชได้ แต่มันเป็นการแค่ซ่อนอาการตัว Timer จะยังคงแอบทำงานวนลูป 1 วินาทีไปเรื่อยๆ แบบไม่มีวันจบ กินทรัพยากร CPU และก่อให้เกิด Memory Leak ที่ร้ายแรงกว่าเดิมเมื่อเปิดหน้าต่างนี้ซ้ำๆ

**Edge cases**:

- ผู้ใช้เข้าและออกหน้าจออย่างรวดเร็วป้องกันการแครชด้วยการใช้ _timer?.cancel() มีเครื่องหมาย ? เพื่อรองรับกรณีที่หน้าจอถูกปิด dispose ไปก่อนที่ฟังก์ชัน initState จะสร้าง Timer เสร็จ หรือกรณีที่ตัวแปรยังเป็น null อยู่

---

### RES-103 · Requests pile up the longer you browse

**Root cause**:

- เกิด Memory Leak จาก Listener ข้าม Lifecycle ระหว่าง Controller ที่ DealController ไปผูกกับ Service ที่ cartService ด้วยคำสั่ง ever() เมื่อผู้ใช้ปิดหน้าจอ DealController ไม่สามารถถูก Garbage Collected ได้เพราะ cartService ยังถือ Reference ของฟังก์ชัน _recheckAvailability ไว้ทำให้เมื่อตะกร้าสินค้ามีการเปลี่ยนแปลงตัว Controller เก่าๆทั้งหมดจึงถูกปลุกขึ้นมายิง API โหลดข้อมูลซ้ำพร้อมๆกัน

**Fix**:

- นำตัวแปร Worker มารับค่าจากคำสั่ง ever() และทำการสั่ง _cartWorker?.dispose() ภายในฟังก์ชัน onClose() ของ GetxController เพื่อถอด Listener ออกอย่างสมบูรณ์เมื่อผู้ใช้ปิดหน้านั้นๆ

**Alternative considered & rejected**:

- การเช็ค if Get.isRegistered<DealController>() ภายใน ever ปฏิเสธไปเพราะเป็นการแก้ที่ปลายเหตุ ตัว Listener ก็ยังคงเกาะกิน Memory อยู่ดี

**Edge cases**:

- หากผู้ใช้กดเพิ่มหรือลดสินค้าขณะที่ยังเปิดหน้ารายละเอียดสินค้านั้นค้างไว้ _cartWorker จะยังคงทำหน้าที่อัปเดตสถานะแบบเรียลไทม์ตามปกติ และจะถูกเคลียร์ทิ้งอย่างปลอดภัยเมื่อผู้ใช้กด Back (Pop) ออกจากหน้านั้นเรียบร้อยแล้วเท่านั้น

---

### RES-104 · Duplicate deals in the home feed

**Root cause**:

- เกิดปัญหา Race Condition ระหว่างฟังก์ชันดึงรีเฟรชและฟังก์ชันโหลดหน้าถัดไป เมื่อผู้ใช้เลื่อนลงสุดจอจนระบบกำลังรอผลลัพธ์ของ loadMore แล้วผู้ใช้ทำการดึงจอเพื่อรีเฟรชทันที จะทำให้มี 2 Request ทำงานขนานกัน เมื่อ loadMore โหลดข้อมูลหน้า 2 เสร็จทีหลัง มันจะนำข้อมูลนั้นไปต่อท้ายข้อมูลหน้า 1 ที่เพิ่งถูกรีเฟรชมาใหม่ทำให้เกิดข้อมูลเบิ้ล ข้อมูลข้ามหน้าและจำนวนไอเทมเพี้ยนจากความเป็นจริง

**Fix**:

- แก้ปัญหาด้วยเทคนิค Request ID Tracking โดยสร้างตัวแปร int _currentRequestId = 0 เมื่อมีการดึงรีเฟรชจะทำการบวกค่านี้ขึ้น 1 เสมอ ฟังก์ชันทั้งสองจะทำการจำค่า requestId ณ เวลาที่ถูกเรียกไว้ในตัวแปรโลคัล ก่อนทำการยิง API await เมื่อข้อมูลโหลดเสร็จ จะทำการตรวจสอบเงื่อนไข if (requestId != _currentRequestId) หากค่าไม่ตรงกันแปลว่ามีการรีเฟรชเกิดขึ้นระหว่างทาง ระบบจะทำการ Discard ข้อมูลชุดนั้นและ return ออกทันที เพื่อป้องกันการนำข้อมูลเก่ามาเขียนทับหรือต่อท้ายข้อมูลใหม่

**Alternative considered & rejected**:

- การเช็ค if (_page == 1) ภายใน loadMore เพื่อดักจับการรีเซ็ตหน้าปฏิเสธไป เพราะถ้า Request ของ refreshDeals ทำงานเสร็จก่อน ค่า _page จะเป็น 1 อยู่ดี ทำให้ loadMore สามารถหลุดรอดเงื่อนไขมานำข้อมูลหน้า 2 ไปต่อท้ายหน้า 1 ได้เหมือนเดิม

**Edge cases**:

- ภายใน loadMore มีการอัปเดต _isFetchingMore = false ก่อนที่จะ return ทิ้งเมื่อ Request ID ไม่ตรงกัน เพื่อป้องกันไม่ให้สถานะการโหลดค้างและทำให้ผู้ใช้ไม่สามารถโหลดหน้าถัดไปได้อีกในอนาคต

---

### RES-105 · Home feed is janky and memory keeps climbing

**Root cause**:

1. มีการใช้ Obx คลุมวิดเจ็ต ListView ทั้งก้อน ในขณะที่ตัว Controller มีการอัปเดตค่า offset ตลอดเวลาที่ผู้ใช้เลื่อนหน้าจอ ส่งผลให้ Flutter สั่ง Rebuild หน้าโฮมใหม่ทั้งหมด 60 ครั้งต่อวินาทีขณะไถจอ
2. การสร้างลิสต์สินค้าใช้วิธี ...controller.visibleDeals.map(...) ภายใน ListView ธรรมดา ทำให้ระบบต้องวาดการ์ดสินค้าทุกใบขึ้นมาใน Memory พร้อมกันตั้งแต่แรกแม้จะยังมองไม่เห็น
3. วิดเจ็ตโหลดรูปภาพใน the_network_image.dart ทำการแคชรูปภาพขนาดเต็มลงในหน่วยความจำโดยไม่มีการย่อสเกล ทำให้ RAM ถูกสูบจนหมดเมื่อเลื่อนดูรูปเยอะๆ

**Fix**:

- เปลี่ยนโครงสร้างจาก ListView ธรรมดาเป็น CustomScrollView และใช้ SliverList เพื่อให้การ์ดสินค้าถูก Render เฉพาะตอนที่เลื่อนมาอยู่ในหน้าจอพร้อมทั้งแยก Obx ออกเป็นจุดเล็กๆ เพื่อคลุมเฉพาะ FilterChip และ FloatingActionButton ทำให้การเลื่อนจอไม่ไปกระตุกการ Rebuild ของลิสต์อีกต่อไป

**Alternative considered & rejected**:

- การใช้ ListView.builder รวบทุกอย่างไว้ด้วยกัน ปฏิเสธไปเพราะหน้า Home มีส่วนหัว Flash Deals และ Filter ที่หน้าตาแตกต่างจากลิสต์สินค้า การพยายามเขียน if-else เช็ค index ภายใน ListView.builder จะทำให้โค้ดอ่านยากและดูแลรักษายาก การใช้ CustomScrollView ร่วมกับ Slivers เป็นวิธีที่ถูกต้องและคลีนกว่ามาก

**Edge cases**:

- การเลื่อนหน้าจออย่างรวดเร็ว แม้จะใช้ Slivers เพื่อวาดเฉพาะสิ่งที่อยู่ในจอแล้ว แต่การดึงรูปภาพผ่าน Network อย่างรวดเร็วอาจทำให้เกิด Blank space ชั่วคราวการออกแบบให้มี Placeholder ตัว Shimmer สีเทาระหว่างรอรูปภาพโหลดช่วยรักษาประสบการณ์ผู้ใช้ไม่ให้ดูสะดุดหรือขัดตา

**Performance Evidence (DevTools)**:
* **Before Fix:** เฟรมเรตตก เกิดอาการ Jank แท่งสีแดงจำนวนมากจากการที่วิดเจ็ตโดน Rebuild ซ้ำๆ
  ![Before Performance](PerformanceEvidence/res-105-before-performance.png)

* **After Fix:** การ Scroll ลื่นไหล ไม่กระตุก แท่งสีแดงหายไปอย่างชัดเจน เนื่องจากการ์ดถูก Rebuild เฉพาะใบที่โผล่เข้ามาในจอเท่านั้น
  ![After Performance](PerformanceEvidence/res-105-after-performance.png)

---

### RES-106 · Wrong pickup times; "Pickup today" filter misses deals

**Root cause**:

- แอปพลิเคชันนำข้อมูลเวลาที่ได้จาก API ซึ่งอยู่ในรูปแบบ ISO-8601 และเป็นเวลามาตรฐานสากล UTC มาแปลงเป็น DateTime object ผ่านคำสั่ง DateTime.parse() โดยตรง แต่ไม่ได้ทำการแปลงให้เป็นเวลา Local Time ของเครื่องผู้ใช้ ทำให้เวลาที่แสดงผลคลาดเคลื่อนไปจากความเป็นจริง เช่น ในประเทศไทยที่เวลาเร็วกว่า UTC 7 ชั่วโมง เวลารับของก็จะเพี้ยนไป 7 ชั่วโมง ความคลาดเคลื่อนนี้ยังส่งผลให้ฟิลเตอร์ Pickup today ทำงานผิดพลาดอย่างหนัก เนื่องจากเวลา UTC อาจจะยังตกอยู่ในวันเมื่อวาน เมื่อเทียบกับปฏิทินท้องถิ่นของเครื่องผู้ใช้

**Fix**:

- แก้ไขโดยการเติมคำสั่ง .toLocal() ต่อท้าย DateTime.parse(...) ภายในแฟคทอรี fromJson ของหน้า pickup_window_modle เพื่อให้ Dart ทำการคำนวณ Offset และแปลงเวลา UTC เป็นเวลาท้องถิ่นตาม Timezone ของอุปกรณ์ผู้ใช้อย่างถูกต้องก่อนนำไปจัดเก็บ แสดงผล หรือเปรียบเทียบวันที่

**Alternative considered & rejected**:

- การคำนวณบวกเวลาเพิ่มเองแบบ Manual เช่น add(Duration(hours: 7)) ปฏิเสธแนวทางนี้ไป เพราะเป็นวิธีที่ Hardcode จะทำให้แอปพังทันทีถ้าผู้ใช้นำเครื่องไปเปิดในเขตเวลาอื่น หรือในประเทศที่มีการปรับเวลาตาม Daylight Saving Time การใช้ฟังก์ชัน .toLocal() ที่ถูกออกแบบมาเพื่อจัดการเรื่องนี้โดยเฉพาะจึงเป็นวิธีที่ถูกต้องและไร้ข้อบกพร่องที่สุด

**Edge cases**:

- การเปิดแอปข้ามคืนหรือข้ามเขตเวลา เนื่องจากเวลาถูกแปลงผ่าน .toLocal() ณ จังหวะที่รับข้อมูลจาก API หากผู้ใช้เปิดแอปทิ้งไว้จนข้ามวัน ป้าย "Pickup today" อาจไม่อัปเดตอัตโนมัติ ผู้ใช้จำเป็นต้องทำการ Pull-to-refresh เพื่อให้ระบบคำนวณเงื่อนไขของวันและเวลาท้องถิ่นใหม่ทั้งหมด

---

### RES-107 · Deep link opens to a crash

**Root cause**:

- แอปพลิเคชันเกิดการ Crash ทันทีเมื่อเข้าใช้งานผ่าน Deep link เช่น Push notification เนื่องจากโค้ดใน onInit ของ DealDetailsController ทำการอ่านค่า Get.arguments และบังคับแปลงชนิดตัวแปร as DealModel โดยพลการ เมื่อเข้าใช้งานผ่าน Deep link จะไม่มีการส่งอ็อบเจ็กต์ผ่านหน่วยความจำ ทำให้ค่า arguments เป็น null และเกิดข้อผิดพลาด Type cast แครชในที่สุด นอกจากนี้ UI ไม่ได้ถูกออกแบบมาให้รองรับสถานะการรอข้อมูล Asynchronous loading

**Fix**:

1. ปรับปรุงลอจิกการรับข้อมูลให้รองรับ 2 ช่องทาง โดยใช้ if (args is DealModel) สำหรับการนำทางปกติ และดึง Get.parameters['id'] ไปเรียก API (dealRepo.fetchById) สำหรับ Deep link
2. นำ State Machine (Enum: DealLoadState) มาใช้เพื่อจัดการสถานะหน้าจอ ได้แก่ loading, ready, และ error
3. แก้ไข UI (DealDetailsScreen) ให้ตอบสนองตาม loadState โดยเพิ่มหน้าจอ Loading ระหว่างรอ API และหน้าจอ Error พร้อมปุ่ม Retry เพื่อจัดการกรณีโหลดข้อมูลล้มเหลว


**Alternative considered & rejected**:

- การใช้เพียงตัวแปร Boolean (isLoading) แบบธรรมดาปฏิเสธไป แม้จะป้องกันการแครชระหว่างรอข้อมูลได้ แต่ไม่ครอบคลุมกรณีที่ API ล้มเหลว การใช้ DealLoadState แบบ Enum ควบคู่กับการทำ Error UI & Retry mechanism เป็นวิธีที่ปลอดภัยและให้ประสบการณ์ผู้ใช้ที่ดีกว่า

**Edge cases**:

- ID สินค้าไม่มีอยู่จริง (Invalid / Expired ID) หาก Deep link ส่ง ID ของสินค้าที่ถูกลบไปแล้วหรือผิดรูปแบบเข้ามา ระบบจะไม่แครช เพราะลอจิกจะเปลี่ยนสถานะเป็น DealLoadState.error และแสดงหน้า UI แจ้งเตือนข้อผิดพลาด (We couldn't load this deal) ให้ผู้ใช้ทราบแทนการปล่อยให้แอปหยุดทำงาน

---

### Part B — Features

### F-1 · Live flash-sale countdowns

**Approach**:

- สร้างวิดเจ็ต LiveCountdownBadge แยกออกมาต่างหาก และใช้ StreamBuilder<DateTime> เพื่อจำกัดขอบเขตการ Rebuild เฉพาะแค่ตัวหนังสือเวลานับถอยหลังทุกๆ 1 วินาที โดยไม่กระทบกับการ์ดทั้งใบ ทำให้สามารถแสดงผลการ์ดที่มีเวลานับถอยหลังมากกว่า 100 ใบได้โดยที่เฟรมเรตไม่ตก

- ใช้ StreamBuilder<bool> ร่วมกับฟังก์ชัน .distinct() ในการตรวจจับสถานะหมดเวลา เพื่อเปลี่ยนสีการ์ดให้เป็นสีเทาและปิดการคลิก ทันทีที่เวลาหมด โดย .distinct() จะช่วยรับประกันว่าการ์ดจะถูก Rebuild เพื่อเปลี่ยนสีเพียงแค่ 1 ครั้งเท่านั้น ไม่ใช่ทุกวินาที

- แทรก Timer.periodic ไว้ใน CartService ซึ่งทำงานอยู่เบื้องหลังในระดับ Global Session เพื่อคอยตรวจสอบรายการสินค้าที่หมดเวลาทุกๆ 1 วินาที หากพบรายการที่ Expired ระบบจะลบสินค้านั้นออกจาก items ทันที พร้อมเรียก items.refresh() เพื่อบังคับให้ UI ของตะกร้าอัปเดตแบบเรียลไทม์ และแสดง Get.snackbar แจ้งเตือนผู้ใช้อย่างชัดเจน

**Alternative considered & rejected**:

- การใช้ Timer เดี่ยวๆ ร่วมกับ setState หรือ Obx คลุมทั้งหน้าจอ ปฏิเสธแนวทางนี้เนื่องจากจะทำให้เกิดการวาดหน้าจอใหม่ทั้งหน้าทุกๆ วินาที ซึ่งขัดต่อข้อกำหนดด้าน Performance ของโปรเจกต์

**Edge cases**:

- Expired in bag หมดเวลาพอดีตอนอยู่ในตะกร้า จัดการโดยฝัง Timer.periodic ไว้ระดับ Global ใน CartService เพื่อตรวจสอบตะกร้าทุก 1 วินาที หากพบไอเทมที่หมดเวลา ระบบจะใช้ removeWhere ลบออก, เรียก items.refresh() เพื่ออัปเดต UI ของตะกร้าทันทีแบบเรียลไทม์, และแสดง Snackbar แจ้งเตือนผู้ใช้อย่างชัดเจน

- Timezone drift การคำนวณ DateTime.now().difference(...) ทำงานได้อย่างถูกต้องไร้รอยต่อ เนื่องจากโมเดลข้อมูลได้ถูกแก้ไขให้แปลงเวลา UTC เป็น Local Time ตาม Timezone ของเครื่องผู้ใช้เรียบร้อยแล้วจากการแก้บั๊ก RES-106

---

### F-2 · Impression tracking

**Approach**:

- สร้างวิดเจ็ต DealImpressionTracker หุ้มการ์ดสินค้า โดยเรียกใช้ VisibilityDetector ตรวจสอบค่า visibleFraction >= 0.5 หากเข้าเงื่อนไขระบบจะเริ่มรัน Timer 1 วินาที โดยไม่มีการเรียก setState() เพื่อหลีกเลี่ยงการ Rebuild ที่ทำลายเฟรมเรต

- สร้าง _batchQueue ใน AnalyticsService เมื่อมี Event แรกเข้ามา ระบบจะตั้ง Timer จับเวลา 15 วินาที และเมื่อสะสมครบ 10 Events หรือเวลาครบ 15 วินาที (อย่างใดอย่างหนึ่งถึงก่อน) ระบบจะทำแพ็กเกจส่งไปที่ FakeApiService.sendAnalyticsBatch และเคลียร์คิวทิ้ง

**Verification**:

- ทดสอบโดยไปที่ Home → ⋮ → Analytics debug เมื่อหยุดมองการ์ดเกิน 1 วินาที จะพบรายการ deal_impression แสดงขึ้นมาทันที พร้อมแสดง Properties ครบถ้วน deal_id, source, position

- ตรวจสอบใน Debug Console จะพบ Log แจ้งเตือนการยิง API เช่น POST /analytics/batch events=10 เมื่อเงื่อนไข Batch ทำงานสมบูรณ์

**Edge cases**:

- ระบบ onVisibilityChanged จะตรวจสอบทันที หากเปอร์เซ็นต์การมองเห็นหลุดเกณฑ์ 50% ระบบจะสั่ง _timer?.cancel() ทิ้งก่อนถึง 1 วินาที ทำให้ไม่เกิดการยิง Event ขยะเข้าคิว

- ป้องกันการนับวิวซ้ำด้วยการเช็ค ID ผ่าน Set<int> _seenDealIds ใน AnalyticsService ทำให้ดีล 1 ชิ้น จะถูกบันทึกแค่ 1 ครั้งต่อ App Session เสมอ แม้ผู้ใช้จะเลื่อนขึ้นลงหลายรอบ

- ด้วยเงื่อนไขรัน Timer 15 วินาทีหลังเกิด Event แรก ช่วยลดระยะเวลาค้างท่อของข้อมูลให้สั้นที่สุด ลดความเสี่ยงที่ข้อมูล Impression จะสูญหายหากผู้ใช้พับจอหรือปิดแอปพลิเคชันอย่างกะทันหัน

---

### F-3 · Stock reservations with optimistic UI

**Approach**:

- เมื่อผู้ใช้กดเพิ่มสินค้า ระบบจะอัปเดต UI ให้สินค้าเข้าตะกร้าทันที จากนั้นจึงเรียก API reserveDeal ไปหลังบ้าน หากเกิดการแย่งสต็อก (API ตอบกลับ Error 409) ระบบจะทำการ Rollback โดยนำสินค้านั้นออกจากตะกร้าทันที และแสดง Snackbar แจ้งเตือนผู้ใช้

- เพิ่มตัวแปร reservationId และ expiresAt ใน CartItemModel และสร้างวิดเจ็ตเพื่อนับถอยหลัง 5 นาที แสดงผลแยกตามรายสินค้าในหน้าตะกร้า

- เมื่อผู้ใช้กดลบสินค้า หรือลดจำนวนจนเหลือ 0 ระบบจะเรียก API releaseReservation เพื่อคืนสต็อกให้ระบบส่วนกลางทันที

**Deliberately underspecified — my decision:**:

- เมื่อ Reservation หมดอายุระหว่างอยู่ในแอป: ตัดสินใจค้างสินค้านั้นไว้ในตะกร้า แต่ปรับ UI ให้การ์ดกลายเป็นสีเทา เปลี่ยนปุ่มเพิ่มลดจำนวนเป็นปุ่มถังขยะและล็อกการทำงานของปุ่ม Checkout 

- เหตุผลที่ตัดสินใจแบบนี้: เพื่อไม่ให้ผู้ใช้เกิดความสับสนจากการที่สินค้าหายไปจากตะกร้าเองแบบไร้สาเหตุ การปล่อยให้เห็นสถานะหมดอายุและบังคับให้ผู้ใช้กดลบเอง จะช่วยลดการสับสนในกรณีที่กำลังจะกดชำระเงินได้ดีกว่า

**Edge cases**:

- ดักจับ Error 410 (Reservation Expired) จาก orderRepo.checkout() เพื่อป้องกันการชำระเงินที่สต็อกหมดอายุไปแล้ว พร้อมแสดงแจ้งเตือนให้ผู้ใช้กลับมาตรวจสอบตะกร้าใหม่

---

### AI usage log


**Tools used**

- **Claude**:
  - RES-101: วิเคราะห์ root cause ของ search race condition, review โค้ด fix ที่เขียนเอง
  - RES-104: วิเคราะห์ root cause ของ duplicate deals, ช่วยออกแบบ pattern แก้ race condition (request generation guard)
  - RES-107: วิเคราะห์ root cause deep-link crash, ช่วยแก้ไข `DealDetailsController` / `DealDetailsScreen`
  - ช่วยจัดโครง `solutions.md`

- **Gemini**:
  - Part A (ระบุ ticket ที่ใช้จริง): root-cause analysis, วิเคราะห์ log
  - Part B (ระบุ feature ที่ใช้จริง): คำแนะนำเรื่อง DevTools profiling

**ตัวอย่างที่ AI แนะนำผิดหรือทำให้เข้าใจผิด**

**ตัวอย่างที่ 1 — RES-104**

**AI แนะนำ**: ให้เพิ่ม _page++ ก่อนเรียก fetchDeals() แล้วค่อย _page-- ใน catch block ถ้า request ล้มเหลว rollback pattern

**ทำไมมีปัญหา**: วิธีนี้แก้ไข state (_page) ไปก่อนที่จะรู้ผลว่า request สำเร็จหรือไม่ ทำให้ถ้ามี concurrent call อื่นเข้ามาแทรกระหว่างที่ยัง await อยู่ จะเกิดความเสี่ยงเรื่อง state ไม่สอดคล้องกันได้ง่ายกว่า

**จับได้ยังไง**: ลองตัวอื่นเทียบกับที่ AI ให้มาพบว่าถ้าเลื่อนการแก้ _page ไปไว้หลังจาก fetch สำเร็จแล้วเท่านั้น ใช้ตัวแปร local เช่น nextPage เก็บค่าไว้ก่อน จะไม่ต้องมี rollback เลย และปลอดภัยกว่า

**ทำอะไรแทน**: เปลี่ยนมาใช้ pattern "commit state เมื่อสำเร็จเท่านั้น" (mutate-after-success) แทนที่จะ mutate-then-rollback


**ตัวอย่างที่ 2 — RES-107**

**AI แนะนำ**: สาเหตุของการแครชเกิดจาก race condition ตอน cold start catalog ยังโหลดไม่เสร็จตอนที่ deep link ถูก resolve หรือไม่ก็ type mismatch ระหว่าง id ใน URI ที่เป็น String กับ id ที่เก็บใน catalog ที่เป็น int

**ทำไมมีปัญหา**: ทั้งสองข้อไม่ใช่สาเหตุที่แท้จริงเลย ตัวบั๊กจริงๆ ง่ายกว่านั้นมาก คือ deep-link handler เรียก Get.toNamed(route) โดยไม่ส่ง arguments: ไปเลย ทำให้ Get.arguments เป็นแค่ null และ controller ก็เขียน deal = Get.arguments as DealModel แบบไม่มีเงื่อนไขใดๆ ไม่มีเรื่อง catalog, ไม่มี race, ไม่มี type coercion เกี่ยวข้องเลยแม้แต่น้อย

**จับได้ยังไง**: ต้องรอจนกว่าจะได้เห็น onInit, deep-link dialog handler, และตาราง route จริง ถึงจะเห็นสาเหตุที่แท้จริงได้ชัดเจน 

**ทำอะไรแทน**: ตัด race-condition และ type-mismatch ทิ้งไปทั้งหมด แล้วอิงการแก้ไขจากสิ่งที่โค้ดแสดงให้เห็นจริงๆเท่านั้น คือแยกเงื่อนไขระหว่าง Get.arguments is DealModel กับกรณี deep-link fetch ด้วย id
"""

### Design questions

**Q1**:

- GetxController มีตัวตนอยู่นอกโครงสร้าง Widget tree ของ Flutter โดย Lifecycle ของมันถูกจัดการโดยระบบ Dependency Injection ของ GetX ซึ่งหมายความว่ามันสามารถทำงานค้างอยู่ใน Memory ได้นานกว่า Widget ที่สร้างมันขึ้นมา แม้ Widget นั้นจะถูกทำลายไปแล้ว เว้นแต่เราจะสั่งลบหรือผูกไว้กับ Route binding อย่างถูกต้อง ในทางกลับกัน State ของ Widget จะผูกติดกับ UI tree อย่างสมบูรณ์ และฟังก์ชัน dispose() ของ State จะถูกเรียกใช้งานแน่นอนเมื่อ Widget นั้นถูกลบออกไป

- ความไม่สอดคล้องกันนี้เป็นสาเหตุของ Memory leak ใน RES-103 เมื่อ DealController ถูกปิดและลบออกจากหน้าจอไปแล้ว แต่เนื่องจากมันได้ผูก Listener ever() ไว้กับ CartService ส่งผลให้ Controller ตัวนี้ยังคงติดค้างอยู่ใน Memory สรุปคือ UI State ตายไปแล้ว แต่ Controller ยังมีชีวิตอยู่ ทำให้เกิดการยิง API เบื้องหลังซ้ำซ้อนทับถมกันทุกครั้งที่ตะกร้าสินค้ามีการเปลี่ยนแปลง

**Q2**

- การนำ Obx ไปครอบ Subtree ขนาดใหญ่ เช่น ครอบทั้งหน้าจอ หรือครอบทั้ง ListView จะส่งผลเสียอย่างมากต่อประสิทธิภาพเพราะ Obx จะคอยติดตามทุก ตัวแปร Observable ที่ถูกเรียกใช้อยู่ภายในนั้นโดยอัตโนมัติ หากมีตัวแปรใดตัวแปรหนึ่งเปลี่ยนแปลง มันจะบังคับให้ Subtree ทั้งหมดที่อยู่ใต้ Obx นั้นถูก Rebuild ใหม่ทั้งหมด

- ดังที่เห็นในปัญหา RES-105 การนำ Obx ไปครอบ CustomScrollView ทั้งก้อน ในขณะที่มีการดึงค่าตัวแปรที่เปลี่ยนค่าอย่างรวดเร็วเช่น scrollOffset มาใช้งาน ทำให้ Flutter ถูกบังคับให้ Rebuild ลิสต์สินค้าทั้งหมด 60 ครั้งต่อวินาทีขณะที่ผู้ใช้เลื่อนหน้าจอ วิธีที่ถูกต้องคือการจำกัดขอบเขตของการ Rebuild ให้เล็กที่สุดเท่าที่จะทำได้ เช่น นำ Obx ไปครอบเฉพาะตัว Text, FilterChip หรือ FloatingActionButton ที่จำเป็นต้องเปลี่ยนค่าตาม State นั้นจริงๆเท่านั้น


**Q3**

- ในการดักจับบั๊กเกี่ยวกับ Timezone แบบ RES-106 เราไม่สามารถพึ่งพาการเทสต์แบบ Manual บนเครื่องโทรศัพท์เครื่องเดียวได้ เพราะ Timezone ปัจจุบันของเครื่องนักพัฒนาอาจจะไปบังเอิญตรงกับลอจิกพอดีและปกปิดบั๊กนั้นไว้ ผมจะเขียน Automated Unit Tests ที่จำลองสภาพแวดล้อมของ Timezone ที่แตกต่างกันอย่างชัดเจน 

---

### Time spent

- Total time spent ประมาณ 8 ชั่วโมง

1. Part A (Bug fixing): ประมาณ 4 ชั่วโมง 

2. Part B (Features): ประมาณ 3 ชั่วโมง

3. Documentation & cleanup  ประมาณ 1 ชั่วโมง

**What's unfinished**:

- การทำ Automated testing แบบครอบคลุม เช่น Unit test และ Widget test ถูกข้ามไปเนื่องจากข้อจำกัดด้านเวลา และระบบ Optimistic UI rollback ในปัจจุบันยังใช้เพียงแค่ Snackbar แจ้งเตือนแบบง่ายๆ ระบบ Retry queue สำหรับออฟไลน์ถูกตัดออกจากสโคปไปก่อน



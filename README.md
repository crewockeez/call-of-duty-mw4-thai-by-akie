# Call of Duty MW4 Thai by AKIE

โปรเจกต์ซับไทยสำหรับแคมเปญ **Call of Duty: Modern Warfare 4 (2026)** ดูแลโดย **AKIE**

**สถานะ: รุ่นทดลอง `0.1.0-alpha.1` — ยังไม่ครบแคมเปญ 100%** มีคำแทนที่ 6,446 คีย์ รวมบทพูด ตัวเลือกตอบ และชื่อผู้พูด จำนวนคีย์ไม่ใช่เปอร์เซ็นต์ความคืบหน้าของเนื้อเรื่อง คำแปลยังต้องตรวจบริบทและทดสอบครบทุกภารกิจ

## ดาวน์โหลด

เลือกไฟล์ที่ลงท้าย **`-data.zip`** ใน [Releases](../../releases) แล้วแตก ZIP ทั้งโฟลเดอร์ รุ่นนี้เป็นแพ็กคำแปลและเครื่องมือ ไม่แนบ `bink2w64.dll` / `trhook.dll` ของบุคคลที่สาม

## ติดตั้ง

1. ปิดเกม เตรียมตัวโหลดรุ่นที่รองรับจากไฟล์ที่คุณมี เช่นโฟลเดอร์ `files` 
2. เปิด `install.bat` แล้วเลือกโฟลเดอร์ตัวโหลดเมื่อระบบถาม ระบบตรวจ SHA-256 และนำเข้าเฉพาะในเครื่อง
3. เลือกโฟลเดอร์หลักของเกม หรือ `sp26` ที่มี `sp26-cod.exe`
4. เปิดเกมเป็นภาษา **English** และเปิด **Subtitles** ทดสอบใน Campaign/Offline

ไม่ต้องติดตั้ง Python เพื่อใช้แพ็กจาก Releases โปรแกรมจัดข้อความขวาไปซ้ายของเปอร์เซียจะไม่ถูกนำเข้า เราใช้ compatibility helper ที่สร้างจากซอร์สของโปรเจกต์นี้เอง

ถ้าใช้แพ็กไทยเก่า `v4 / v3.1` ให้ถอนแพ็กเดิมก่อนลงรุ่นสาธารณะครั้งแรก เพราะ helper เป็นไฟล์ที่สร้างใหม่ รุ่นถัดไปที่ใช้ตัวโหลดตรงกันสามารถใช้ `update.bat` ได้

## คืนค่าและแก้ปัญหา

- `uninstall.bat` คืนไฟล์ก่อนติดตั้งทั้งโฟลเดอร์หลักและ `sp26`
- `subtitle-size-normal.bat`, `subtitle-size-large.bat`, `subtitle-size-largest.bat` สลับข้อมูลขนาดซับขณะปิดเกม
- `check_install.bat` ตรวจไฟล์และคีย์จากภาพทดสอบ ผลอยู่ใน `diagnostics/last-check.json`

เก็บ `sp26/.mw4-thai-backups` ไว้ขณะใช้งานม็อด หากไฟล์เกมเปลี่ยนหลังลงม็อด ระบบจะหยุดก่อนเขียนทับ อ่าน [คู่มือติดตั้ง](docs/INSTALLATION.md) และ [ข้อมูลที่ตัวตรวจบันทึก](docs/PRIVACY.md)

## แจ้งซับอังกฤษที่เหลือหรือคำแปลผิด

เปิด [Issue](../../issues/new/choose) พร้อมชื่อภารกิจ รุ่นแพ็ก รุ่นเกม ข้อความอังกฤษ และภาพหรือเวลาในฉาก หากแนบ log ให้ลบข้อมูลส่วนตัวก่อน ทุกข้อความที่แก้ต้องรักษาคีย์อังกฤษและโค้ดควบคุมของเกมตามเดิม

## ร่วมแปลและพัฒนา

ไฟล์หลักคือ `translations/thai.jsonl` ดู [CONTRIBUTING.md](CONTRIBUTING.md) และ [แผนงาน](docs/ROADMAP.md)

```text
python tools/build.py --check
python tools/build.py
python -m unittest discover -s tests -v
```

ใช้ Python 3.10 ขึ้นไป ไม่ต้องใช้แพ็กเกจเสริม ไฟล์แจกอยู่ใน `dist/` กระบวนการสร้าง ZIP ใช้รายการไฟล์ที่อนุญาตและไม่แนบตัวโหลดที่นำเข้าในเครื่อง ดู [วิธีออกเวอร์ชัน](docs/RELEASING.md)

## เครดิตและใบอนุญาต

- ผู้ดูแลและพัฒนาซับไทย: **AKIE และผู้ร่วมโครงการ**
- ตัวโหลดภายนอกมีที่มาจากผู้สร้างแพ็กตุรกี ตามเครดิตของโปรเจกต์ต้นทาง ไม่ได้อ้างว่าเป็นผลงานของ AKIE
- ซอร์สและส่วนที่โครงการมีสิทธิ์ให้อนุญาตใช้ MIT โดยเก็บ [ใบอนุญาตต้นทาง](LICENSES/upstream-farsi-MIT.txt) ไว้ ดูขอบเขตใน [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)

โปรเจกต์แฟนเมด ไม่ได้เป็นผลิตภัณฑ์หรือได้รับการรับรองจาก Activision / Infinity Ward ข้อความอังกฤษและเครื่องหมายการค้าเป็นของเจ้าของสิทธิ์

[ดูหนัง](https://tidnung.com)

**English:** Thai campaign localization by AKIE. Work in progress, with 6,446 lookup entries; full campaign coverage and in-game compatibility are not yet verified. Public downloads exclude third-party hook binaries. Users supply a supported loader locally. Upstream credits and license notices are preserved.

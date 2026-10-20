# ออกเวอร์ชัน

1. แก้ version ใน `project.json` และ CHANGELOG ให้ตรงกับงานจริง
2. รัน validation/tests และสร้าง ZIP ด้วย `python tools/build.py`
3. ตรวจ `dist/` มี `-data.zip`, `-source.zip` และ `SHA256SUMS.txt`
4. ตรวจว่าไม่แนบ `bink2w64.dll`, `trhook.dll`, runtime-local, diagnostics, input archives หรือข้อมูลส่วนตัว
5. สร้าง GitHub prerelease ด้วย workflow **Release alpha** โดย tag ต้องตรงกับ `v` ตามด้วย version ใน project.json

CI สร้างเพียง artifacts ส่วน workflow release ต้องเรียกเองและตั้ง prerelease เสมอ ยังไม่ยืนยันว่ารันผ่าน GitHub จนกว่าจะมี run จริง

ZIP ข้อมูลมี helper ที่สร้างจากซอร์สของเราเอง การเปลี่ยนไปแนบตัวโหลดภายนอกต้องมีหลักฐานสิทธิ์ของตัวโหลดแยกจาก MIT ของโปรเจกต์ต้นทาง

## นำซอร์สขึ้น GitHub ครั้งแรก

ถ้าใช้ GitHub CLI ให้ลงชื่อเข้าใช้และตั้งชื่อ/อีเมลผู้เขียน Git ของตัวเองก่อน จากโฟลเดอร์โปรเจกต์รันคำสั่งต่อไปนี้ โดยยังไม่ต้องสร้าง repository ในหน้าเว็บ:

```text
git add .
git commit -m "Start AKIE Thai localization project"
gh repo create call-of-duty-mw4-thai-by-akie --public --source . --remote origin --push
```

หากสร้าง public repository ชื่อ `call-of-duty-mw4-thai-by-akie` ในหน้าเว็บไว้แล้ว ให้สร้างแบบว่างโดยไม่เพิ่ม README ซ้ำ และใช้ remote URL ที่ GitHub แสดงแทนคำสั่ง `gh repo create` เลือกสร้างทางเดียวเพื่อไม่ให้ซ้ำ ไม่มี credentials/token ฝังในสคริปต์นี้

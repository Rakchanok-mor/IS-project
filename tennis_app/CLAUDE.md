# tennis_app (Courtswap)

แอป Flutter สำหรับปล่อย/ซื้อคอร์ทเทนนิส-แบดมินตัน งานวิชา IS767 — backend เป็น Supabase (`supabase/schema.sql`), state ใช้ Provider

**ก่อนเขียนหรือแก้โค้ดใน `lib/` ทุกครั้ง ให้ใช้ skill `class-pattern`** (`.claude/skills/class-pattern/SKILL.md`)
โค้ดต้องเป็นแบบที่อาจารย์สอน: model → service (abstract + `XxxSupabaseService`) → controller (`onSync` stream) → page

เอกสารต้นฉบับ (สไลด์ IS767_01–13 + โปรเจค `first_app`) อยู่ใน Google Drive:
https://drive.google.com/drive/folders/1QRUPxlwDsFRg9mDcberd8w1ThDRUKNZ2

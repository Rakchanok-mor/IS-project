-- ===============================================================
-- Courtswap: โครงสร้างฐานข้อมูลทั้งหมด
-- วิธีใช้: Supabase Dashboard > SQL Editor > New query > วางทั้งไฟล์ > Run
-- รันซ้ำได้ (ใช้ if not exists / create or replace / drop ... if exists)
--
-- สารบัญ
--   1. ตาราง courts          สนาม
--   2. ตาราง listings        ประกาศขาย
--   3. ตาราง admins          แอดมิน
--   4. ตาราง orders          คำสั่งซื้อ
--   5. ตาราง requests        การตั้งรับของผู้ซื้อ + การจับคู่กับประกาศ
--   6. Storage               รูปหลักฐาน
--   7. ตารางการเงิน           บัญชีรับเงิน / รายการโอน / gateway จำลอง
--   8. ตาราง notifications   แจ้งเตือน
--   9. ตาราง banned_users    ผู้ใช้ที่ถูกแบน
--  10. ฟังก์ชันซื้อ-ขาย        กดซื้อ / ยกเลิก / หมดเวลา / gateway
--  11. ฟังก์ชันใช้สนาม         ยืนยันการเล่น / แจ้งปัญหา / ตัดสินข้อพิพาท
--  12. ฟังก์ชันอ่านข้อมูล      สำหรับหน้าจอ
--  13. Trigger              แจ้งเตือน / จับคู่การตั้งรับ / กันคนโดนแบน / โอนเงินอัตโนมัติ
--  14. งานตั้งเวลา (pg_cron)
--  15. ล้างของรุ่นเก่า        ฟังก์ชัน/ตารางที่เลิกใช้แล้ว
-- ===============================================================


-- ---------------------------------------------------------------
-- 1. ตาราง courts: สนาม (ใส่ข้อมูลจาก supabase/courts_template.csv)
-- ---------------------------------------------------------------
create table if not exists public.courts (
  id bigint generated always as identity primary key,
  name text not null,
  name_en text,
  sports text[] not null default '{}',
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now()
);

alter table public.courts enable row level security;

-- ผู้ใช้ที่ล็อกอินแล้วเห็นสนามทั้งหมด (เพิ่ม/แก้สนามทำใน Dashboard เท่านั้น)
drop policy if exists "users read courts" on public.courts;
create policy "users read courts"
  on public.courts for select
  to authenticated
  using (true);


-- ---------------------------------------------------------------
-- 2. ตาราง listings: ประกาศขายคอร์ท (หน้า 09_sellPage)
--   status: open = เปิดขาย, interested = มีคนสนใจ,
--           reserved = มีคนกดซื้อ ล็อกรอชำระเงิน, sold = ขายแล้ว,
--           expired = ถึงเวลาเล่นแล้วไม่มีคนซื้อ (pg_cron เปลี่ยนให้ หัวข้อ 11)
-- ---------------------------------------------------------------
create table if not exists public.listings (
  id bigint generated always as identity primary key,
  seller_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  seller_name text,                 -- ชื่อแบบย่อ เช่น "สมชาย ข."
  court_id bigint not null
    references public.courts (id) on delete restrict,
  sport text not null,
  details text,                     -- หมายเลขคอร์ท พื้นคอร์ท ในร่ม/กลางแจ้ง
  start_time timestamptz not null,
  end_time timestamptz not null,
  price integer not null,           -- ราคาขาย
  original_price integer,           -- ราคาที่จองมา
  scanned_price integer,            -- ราคาที่แอปอ่านจากรูปหลักฐานด้วย OCR (ML Kit)
  proof_path text,                  -- รูปหลักฐานการจองใน Storage
  status text not null default 'open',
  created_at timestamptz not null default now()
);

-- คอลัมน์ที่เพิ่มทีหลัง (ฐานข้อมูลเดิมที่สร้างตารางไว้ก่อนจะได้มีด้วย)
alter table public.listings
  add column if not exists scanned_price integer;

alter table public.listings drop constraint if exists listings_status_check;
alter table public.listings add constraint listings_status_check
  check (status in ('open', 'interested', 'reserved', 'sold', 'expired'));

-- ราคาขายต้องไม่เกินราคาที่จองมา
alter table public.listings
  drop constraint if exists listings_price_not_over_original;
alter table public.listings add constraint listings_price_not_over_original
  check (original_price is null or price <= original_price);

-- ราคาที่จองมาต้องไม่เกินราคาที่อ่านได้จากหลักฐาน
alter table public.listings
  drop constraint if exists listings_original_not_over_scanned;
alter table public.listings add constraint listings_original_not_over_scanned
  check (scanned_price is null or original_price <= scanned_price);

create index if not exists listings_sport_start_idx
  on public.listings (sport, status, start_time);
create index if not exists listings_seller_idx
  on public.listings (seller_id);

alter table public.listings enable row level security;

-- ผู้ใช้ที่ล็อกอินแล้วเห็นประกาศทั้งหมด (แอปกรองเฉพาะที่เปิดขายเอง)
drop policy if exists "users read listings" on public.listings;
create policy "users read listings"
  on public.listings for select
  to authenticated
  using (true);

-- ผู้ขายลงประกาศได้เฉพาะในชื่อตัวเอง (เปลี่ยนสถานะทำผ่านฟังก์ชันเท่านั้น)
drop policy if exists "sellers insert own listings" on public.listings;
create policy "sellers insert own listings"
  on public.listings for insert
  to authenticated
  with check (seller_id = auth.uid());


-- ---------------------------------------------------------------
-- 3. แอดมิน
--   เพิ่มแอดมิน: insert into public.admins values ('<user id จาก Authentication > Users>');
--   บัญชีแอดมินล็อกอินแล้วเห็นแค่เมนูแอดมิน (lib/pages/38_adminHomePage.dart)
-- ---------------------------------------------------------------
create table if not exists public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);
alter table public.admins enable row level security;

insert into public.admins (user_id)
values ('e01b6abb-4d2c-4797-a9b2-531a13647032')
on conflict (user_id) do nothing;

create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;


-- ---------------------------------------------------------------
-- 4. ตาราง orders: คำสั่งซื้อ
--   pending_payment  กดซื้อแล้ว ล็อกประกาศ 15 นาที รอจ่ายผ่าน gateway
--   held             เงินเข้าแล้ว พักไว้ที่ Courtswap
--   confirmed        ผู้ซื้อยืนยันการเล่น (หรือระบบยืนยันให้) → โอนให้ผู้ขายอัตโนมัติ
--   released         โอนให้ผู้ขายแล้ว
--   disputed         ผู้ซื้อแจ้งปัญหา รอผู้ขายชี้แจง + แอดมินตัดสิน
--   rejected         ตัดสินให้คืนเงินผู้ซื้อ รอโอนคืน
--   refunded         คืนเงินแล้ว
--   expired / cancelled   ไม่จ่ายทันเวลา / ผู้ซื้อยกเลิก
-- ---------------------------------------------------------------
create table if not exists public.orders (
  id bigint generated always as identity primary key,
  listing_id bigint not null
    references public.listings (id) on delete restrict,
  buyer_id uuid not null default auth.uid()
    references auth.users (id) on delete restrict,
  buyer_name text not null default '',
  amount integer not null check (amount > 0),
  reference text not null unique,           -- เลขที่คำสั่งซื้อ เช่น CS-00001
  status text not null default 'pending_payment',
  created_at timestamptz not null default now(),
  expires_at timestamptz,                   -- หมดเวลาชำระ

  -- ชำระเงินผ่าน Payment Gateway จำลอง
  charge_id text,
  charge_qr text,
  charge_status text,                       -- pending / succeeded
  slip_sender jsonb,                        -- ผู้โอนของคำสั่งซื้อเก่าที่จ่ายด้วยสลิป (ใช้คืนเงิน)
  paid_at timestamptz,

  -- ใช้สนาม
  confirmed_at timestamptz,
  auto_confirmed boolean not null default false,

  -- ข้อพิพาท
  dispute_category text,
  dispute_reason text,
  dispute_photo_path text,
  disputed_at timestamptz,
  seller_note text,
  evidence_path text,
  evidence_at timestamptz,
  resolution text,                          -- buyer = คืนเงินผู้ซื้อ, seller = โอนให้ผู้ขาย
  resolution_note text,
  resolved_at timestamptz,
  reject_reason text,

  released_at timestamptz,
  refunded_at timestamptz
);

alter table public.orders drop constraint if exists orders_status_check;
alter table public.orders add constraint orders_status_check
  check (status in (
    'pending_payment', 'held', 'confirmed', 'released',
    'disputed', 'rejected', 'refunded', 'expired', 'cancelled'
  ));

alter table public.orders drop constraint if exists orders_resolution_check;
alter table public.orders add constraint orders_resolution_check
  check (resolution is null or resolution in ('buyer', 'seller'));

-- ประกาศ 1 รายการมีคำสั่งซื้อที่ยังล็อกอยู่ได้ทีละ 1 รายการ (กันซื้อซ้อน)
create unique index if not exists orders_one_active_per_listing
  on public.orders (listing_id)
  where status not in ('expired', 'cancelled', 'refunded');
create unique index if not exists orders_charge_id_unique
  on public.orders (charge_id)
  where charge_id is not null;
create index if not exists orders_buyer_idx
  on public.orders (buyer_id, created_at desc);
create index if not exists orders_status_idx
  on public.orders (status);

alter table public.orders enable row level security;

drop policy if exists "buyers read own orders" on public.orders;
create policy "buyers read own orders"
  on public.orders for select
  to authenticated
  using (buyer_id = auth.uid());

drop policy if exists "sellers read orders of own listings" on public.orders;
create policy "sellers read orders of own listings"
  on public.orders for select
  to authenticated
  using (exists (
    select 1 from public.listings l
    where l.id = listing_id and l.seller_id = auth.uid()
  ));

drop policy if exists "admins read all orders" on public.orders;
create policy "admins read all orders"
  on public.orders for select
  to authenticated
  using (public.is_admin());

-- แอปแก้ตาราง orders เองไม่ได้ ทุกอย่างเปลี่ยนผ่านฟังก์ชันเท่านั้น
revoke insert, update, delete on public.orders from authenticated;


-- ---------------------------------------------------------------
-- 5. ตาราง requests: การตั้งรับสนามของผู้ซื้อ (หน้า 06_requestPage)
--   waiting = รอประกาศที่ตรงกัน, matched = ซื้อประกาศที่ตรงแล้ว
-- ---------------------------------------------------------------
create table if not exists public.requests (
  id bigint generated always as identity primary key,
  buyer_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  court_id bigint not null
    references public.courts (id) on delete restrict,
  sport text not null check (sport in ('tennis', 'badminton')),
  start_time timestamptz not null,
  end_time timestamptz not null,
  status text not null default 'waiting'
    check (status in ('waiting', 'matched')),
  matched_order_id bigint
    references public.orders (id) on delete set null,
  created_at timestamptz not null default now(),
  check (end_time > start_time)
);

create index if not exists requests_court_start_idx
  on public.requests (court_id, sport, start_time);
create index if not exists requests_buyer_idx
  on public.requests (buyer_id);

alter table public.requests enable row level security;

-- ผู้ซื้อเห็นและเพิ่มการตั้งรับของตัวเอง (แก้/ลบไม่ได้ สถานะเปลี่ยนผ่าน trigger)
drop policy if exists "buyers read own requests" on public.requests;
create policy "buyers read own requests"
  on public.requests for select
  to authenticated
  using (buyer_id = auth.uid());

drop policy if exists "buyers insert own requests" on public.requests;
create policy "buyers insert own requests"
  on public.requests for insert
  to authenticated
  with check (buyer_id = auth.uid());

-- เงื่อนไขจับคู่การตั้งรับกับประกาศ: สนามเดียวกัน กีฬาเดียวกัน ประกาศยังเปิดขาย
-- และเวลาของประกาศอยู่ในช่วงที่ผู้ซื้อเล่นได้ทั้งหมด
create or replace function public.listing_matches_request(
  l public.listings,
  r public.requests
)
returns boolean
language sql stable
as $$
  select l.court_id = r.court_id
     and l.sport = r.sport
     and l.status in ('open', 'interested')
     and l.start_time > now()
     and l.start_time >= r.start_time
     and l.end_time <= r.end_time
     and r.status = 'waiting'
     and l.seller_id <> r.buyer_id;
$$;

-- ประกาศที่ตรงกับการตั้งรับของผู้ซื้อ (หน้าหลักฝั่งซื้อ)
drop view if exists public.request_matches;
create view public.request_matches
with (security_invoker = true) as
select
  r.id as request_id,
  r.buyer_id,
  l.id as listing_id,
  l.seller_id,
  r.court_id,
  r.sport,
  l.start_time,
  l.end_time,
  l.price
from public.requests r
join public.listings l on public.listing_matches_request(l, r);


-- ---------------------------------------------------------------
-- 6. Storage: รูปหลักฐานการจอง / รูปแจ้งปัญหา / หลักฐานโต้แย้ง (ไม่เปิดสาธารณะ)
--   ไฟล์อยู่ในโฟลเดอร์ชื่อ user id ของเจ้าของ เช่น <uid>/1730800000000.jpg
-- ---------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('booking-proofs', 'booking-proofs', false)
on conflict (id) do nothing;

-- ผู้ซื้อเปิดดูหลักฐานการจองของประกาศที่จ่ายเงินแล้วได้ (เอาไปแสดงกับสนาม)
create or replace function public.can_read_listing_proof(p_path text)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1
      from public.orders o
      join public.listings l on l.id = o.listing_id
     where o.buyer_id = auth.uid()
       and o.status in ('held', 'confirmed', 'released', 'disputed')
       and l.proof_path = p_path
  );
$$;

drop policy if exists "sellers upload own proofs" on storage.objects;
create policy "sellers upload own proofs"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'booking-proofs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "sellers read own proofs" on storage.objects;
create policy "sellers read own proofs"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'booking-proofs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "buyers read proofs of paid orders" on storage.objects;
create policy "buyers read proofs of paid orders"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'booking-proofs'
    and public.can_read_listing_proof(name)
  );

drop policy if exists "admins read all files" on storage.objects;
create policy "admins read all files"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'booking-proofs' and public.is_admin());


-- ---------------------------------------------------------------
-- 7. ตารางการเงิน
--   Edge Functions: charges (รับเงิน) / transfers (คืนเงิน + โอนให้ผู้ขาย)
--                   mock-gateway (สมมติเป็น Payment Gateway ภายนอก)
-- ---------------------------------------------------------------

-- บัญชีรับเงินของผู้ขาย
create table if not exists public.payout_accounts (
  user_id uuid primary key default auth.uid()
    references auth.users (id) on delete cascade,
  bank_name text not null,
  account_number text not null,
  account_name text not null,
  updated_at timestamptz not null default now()
);

alter table public.payout_accounts enable row level security;

drop policy if exists "users read own payout account" on public.payout_accounts;
create policy "users read own payout account"
  on public.payout_accounts for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "users insert own payout account" on public.payout_accounts;
create policy "users insert own payout account"
  on public.payout_accounts for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "users update own payout account" on public.payout_accounts;
create policy "users update own payout account"
  on public.payout_accounts for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- รายการโอนออก: refund = คืนเงินผู้ซื้อ, payout = โอนให้ผู้ขาย
create table if not exists public.payment_transfers (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders (id) on delete restrict,
  kind text not null check (kind in ('refund', 'payout')),
  amount integer not null check (amount >= 0),
  destination jsonb not null default '{}',
  status text not null default 'processing'
    check (status in ('processing', 'succeeded', 'failed')),
  gateway_ref text,
  failure_reason text,
  requested_by uuid,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

-- คำสั่งซื้อเดียวโอนประเภทเดียวกันได้ครั้งเดียว (failed แล้วโอนใหม่ได้)
create unique index if not exists payment_transfers_one_active
  on public.payment_transfers (order_id, kind)
  where status in ('processing', 'succeeded');
create index if not exists payment_transfers_order_idx
  on public.payment_transfers (order_id, created_at desc);

alter table public.payment_transfers enable row level security;

drop policy if exists "related users read transfers" on public.payment_transfers;
create policy "related users read transfers"
  on public.payment_transfers for select
  to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.orders o
        join public.listings l on l.id = o.listing_id
       where o.id = order_id
         and (o.buyer_id = auth.uid() or l.seller_id = auth.uid())
    )
  );

-- สร้าง/แก้ผ่าน Edge Function (service_role) เท่านั้น
revoke insert, update, delete on public.payment_transfers from authenticated;

-- ข้อมูลภายในของ gateway จำลอง (ของจริงอยู่ที่ระบบของ gateway)
-- เปิด RLS โดยไม่มี policy = แอปอ่าน/เขียนไม่ได้ ใช้ได้เฉพาะ Edge Function
create table if not exists public.mock_gateway_charges (
  id text primary key,
  idempotency_key text not null unique,
  amount integer not null check (amount >= 0),
  currency text not null default 'THB',
  reference text,
  description text,
  status text not null default 'pending'
    check (status in ('pending', 'succeeded')),
  expires_at timestamptz,
  webhook_url text not null,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  paid_at timestamptz
);
alter table public.mock_gateway_charges enable row level security;
revoke all on public.mock_gateway_charges from anon, authenticated;


-- ---------------------------------------------------------------
-- 8. ตาราง notifications: แจ้งเตือนในแอป
--   สร้างด้วย trigger เท่านั้น (หัวข้อ 13) แอปฟังแบบ Realtime
-- ---------------------------------------------------------------
create table if not exists public.notifications (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  side text not null check (side in ('buyer', 'seller')),
  type text not null,
  title text not null,
  body text not null default '',
  sport text,                       -- ป้ายกีฬาบนการ์ด (trigger เติมให้)
  order_id bigint,
  listing_id bigint,
  request_id bigint,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_idx
  on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists "users read own notifications" on public.notifications;
create policy "users read own notifications"
  on public.notifications for select
  to authenticated
  using (user_id = auth.uid());

revoke insert, update, delete on public.notifications from authenticated;

-- ผู้ใช้กดอ่านแจ้งเตือนของตัวเองได้ (lib/services/notification_service.dart ใช้ .update())
-- แก้ได้เฉพาะคอลัมน์ read_at คอลัมน์อื่น (หัวข้อ ข้อความ) แก้ไม่ได้ กันปลอมแจ้งเตือน
grant update (read_at) on public.notifications to authenticated;

drop policy if exists "users mark own notifications read" on public.notifications;
create policy "users mark own notifications read"
  on public.notifications for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- เปิด Realtime ให้ตารางนี้
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;


-- ---------------------------------------------------------------
-- 9. ตาราง banned_users: ผู้ใช้ที่ถูกแบน (ผลตัดสินข้อพิพาท)
--   คนที่โดนแบนกดซื้อ / ลงประกาศ / ตั้งรับไม่ได้ (trigger หัวข้อ 13)
--   ยกเลิกแบน: delete from public.banned_users where user_id = '<uid>';
-- ---------------------------------------------------------------
create table if not exists public.banned_users (
  user_id uuid primary key references auth.users (id) on delete cascade,
  reason text not null default '',
  order_id bigint references public.orders (id) on delete set null,
  banned_by uuid,
  banned_at timestamptz not null default now()
);

alter table public.banned_users enable row level security;

drop policy if exists "users read own ban" on public.banned_users;
create policy "users read own ban"
  on public.banned_users for select
  to authenticated
  using (user_id = auth.uid() or public.is_admin());

revoke insert, update, delete on public.banned_users from authenticated;

create or replace function public.is_banned(p_user uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.banned_users where user_id = p_user);
$$;


-- ---------------------------------------------------------------
-- 10. ฟังก์ชันซื้อ-ขาย (แอปเรียกด้วย rpc)
--   security definer = ทำงานด้วยสิทธิ์ฐานข้อมูล แต่เช็กเองว่าใครเรียก
-- ---------------------------------------------------------------

-- ปลดล็อกประกาศที่หมดเวลาชำระ
create or replace function public.release_expired_orders()
returns void
language plpgsql security definer set search_path = public
as $$
begin
  update public.listings l
     set status = 'open'
    from public.orders o
   where o.listing_id = l.id
     and o.status = 'pending_payment'
     and o.expires_at < now()
     and l.status = 'reserved';

  update public.orders
     set status = 'expired'
   where status = 'pending_payment'
     and expires_at < now();
end;
$$;

-- กดซื้อ: ล็อกประกาศ 15 นาที + สร้างเลขที่คำสั่งซื้อ CS-00001, CS-00002, ...
create or replace function public.create_order(p_listing_id bigint)
returns public.orders
language plpgsql security definer set search_path = public
as $$
declare
  v_listing public.listings%rowtype;
  v_order public.orders%rowtype;
  v_name text;
begin
  if auth.uid() is null then
    raise exception 'not_logged_in';
  end if;

  perform public.release_expired_orders();

  -- for update = ล็อกแถว กันสองคนกดซื้อพร้อมกัน
  select * into v_listing from public.listings where id = p_listing_id for update;
  if not found then
    raise exception 'listing_not_available';
  end if;
  if v_listing.seller_id = auth.uid() then
    raise exception 'own_listing';
  end if;
  if v_listing.status not in ('open', 'interested') or v_listing.start_time <= now() then
    raise exception 'listing_not_available';
  end if;

  select coalesce(nullif(raw_user_meta_data ->> 'name', ''), split_part(email, '@', 1))
    into v_name
    from auth.users where id = auth.uid();

  insert into public.orders (listing_id, buyer_id, buyer_name, amount, reference, status, expires_at)
  values (
    p_listing_id,
    auth.uid(),
    coalesce(v_name, ''),
    v_listing.price,
    -- ยังไม่รู้ id ตอน insert ใส่ค่าชั่วคราวไว้ก่อน แล้วเปลี่ยนเป็นเลขจริงด้านล่าง
    'TMP-' || md5(random()::text || clock_timestamp()::text),
    'pending_payment',
    now() + interval '15 minutes' -- ต้องตรงกับ kPaymentMinutes ใน lib/payment_config.dart
  )
  returning * into v_order;

  update public.orders
     set reference = 'CS-' || lpad(v_order.id::text, 5, '0')
   where id = v_order.id
  returning * into v_order;

  update public.listings set status = 'reserved' where id = p_listing_id;
  return v_order;
end;
$$;

-- ผู้ซื้อยกเลิกก่อนชำระ → ปลดล็อกประกาศ
create or replace function public.cancel_order(p_order_id bigint)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_order public.orders%rowtype;
begin
  update public.orders
     set status = 'cancelled'
   where id = p_order_id and buyer_id = auth.uid() and status = 'pending_payment'
  returning * into v_order;

  if found then
    update public.listings set status = 'open'
     where id = v_order.listing_id and status = 'reserved';
  end if;
end;
$$;

-- Edge Function charges บันทึก charge (QR) ที่ gateway ออกให้ลงคำสั่งซื้อ
create or replace function public.attach_charge(
  p_order_id bigint,
  p_charge_id text,
  p_charge_qr text
)
returns public.orders
language plpgsql security definer set search_path = public
as $$
declare
  v_order public.orders%rowtype;
begin
  update public.orders
     set charge_id = p_charge_id, charge_qr = p_charge_qr, charge_status = 'pending'
   where id = p_order_id and status = 'pending_payment'
  returning * into v_order;
  if not found then
    raise exception 'order_not_pending';
  end if;
  return v_order;
end;
$$;

-- gateway แจ้งว่าเงินเข้าแล้ว → held + ประกาศขายแล้ว
-- เรียกซ้ำได้ (webhook ส่งซ้ำ) คำสั่งซื้อที่ไม่ได้รอชำระแล้วจะไม่ถูกเปลี่ยนสถานะ
create or replace function public.complete_charge(
  p_order_id bigint,
  p_charge_id text,
  p_amount integer
)
returns public.orders
language plpgsql security definer set search_path = public
as $$
declare
  v_order public.orders%rowtype;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if not found or v_order.charge_id is distinct from p_charge_id then
    raise exception 'charge_not_found';
  end if;

  if v_order.charge_status = 'succeeded' then
    return v_order;
  end if;

  -- จ่ายทันเวลาและยอดตรง → held
  -- ไม่งั้น (หมดเวลา / ยกเลิกไปแล้ว / ยอดไม่ตรง) แค่บันทึกว่าเงินเข้า ให้แอดมินคืนเงิน
  if v_order.status = 'pending_payment' and p_amount = v_order.amount then
    update public.orders
       set status = 'held', paid_at = now(), charge_status = 'succeeded'
     where id = p_order_id
    returning * into v_order;
    update public.listings set status = 'sold' where id = v_order.listing_id;
  else
    update public.orders
       set charge_status = 'succeeded'
     where id = p_order_id
    returning * into v_order;
  end if;
  return v_order;
end;
$$;

-- gateway แจ้งผลการโอนออกแล้ว → ปิดรายการโอน + refunded / released
-- เรียกซ้ำได้ (webhook ส่งซ้ำ) รายการที่จบแล้วจะไม่ถูกแก้อีก
create or replace function public.complete_transfer(
  p_transfer_id bigint,
  p_success boolean,
  p_gateway_ref text,
  p_reason text
)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_transfer public.payment_transfers%rowtype;
  v_order public.orders%rowtype;
begin
  select * into v_transfer from public.payment_transfers
   where id = p_transfer_id for update;
  if not found then
    raise exception 'transfer_not_found';
  end if;
  if v_transfer.status <> 'processing' then
    return;
  end if;

  if not p_success then
    update public.payment_transfers
       set status = 'failed', failure_reason = p_reason,
           gateway_ref = coalesce(p_gateway_ref, gateway_ref), completed_at = now()
     where id = p_transfer_id;
    return;
  end if;

  update public.payment_transfers
     set status = 'succeeded', gateway_ref = coalesce(p_gateway_ref, gateway_ref),
         completed_at = now()
   where id = p_transfer_id;

  if v_transfer.kind = 'refund' then
    -- คืนเงินแล้ว: ปลดล็อกประกาศ ถ้ายังไม่ถึงเวลาเล่น
    update public.orders
       set status = 'refunded', refunded_at = now()
     where id = v_transfer.order_id and status = 'rejected'
    returning * into v_order;
    if found then
      update public.listings set status = 'open'
       where id = v_order.listing_id and status = 'reserved' and start_time > now();
    end if;
  else
    update public.orders
       set status = 'released', released_at = now()
     where id = v_transfer.order_id and status = 'confirmed';
  end if;
end;
$$;

-- ฟังก์ชันที่ Edge Function เรียกได้คนเดียว (แอปเรียกตรงไม่ได้)
revoke execute on function public.attach_charge(bigint, text, text)
  from public, anon, authenticated;
grant execute on function public.attach_charge(bigint, text, text) to service_role;

revoke execute on function public.complete_charge(bigint, text, integer)
  from public, anon, authenticated;
grant execute on function public.complete_charge(bigint, text, integer) to service_role;

revoke execute on function public.complete_transfer(bigint, boolean, text, text)
  from public, anon, authenticated;
grant execute on function public.complete_transfer(bigint, boolean, text, text) to service_role;


-- ---------------------------------------------------------------
-- 11. ฟังก์ชันใช้สนาม (หลังจ่ายเงินแล้ว สถานะ held)
--   ได้เล่น:   held → confirmed (กดยืนยัน หรือระบบยืนยันให้เมื่อเลย 24 ชม. หลังเล่นจบ)
--             → โอนให้ผู้ขายอัตโนมัติ (trigger หัวข้อ 13)
--   แจ้งปัญหา: held → disputed → ผู้ขายชี้แจงภายใน 24 ชม. → แอดมินตัดสิน
--             ผู้ขายไม่ชี้แจงใน 24 ชม. = คืนเงินผู้ซื้ออัตโนมัติ
-- ---------------------------------------------------------------

-- ตัวจับเวลา 24 ชม. (pg_cron รันทุก 10 นาที และแอปเรียกตอนเปิดหน้ารายการ)
create or replace function public.process_play_deadlines()
returns void
language plpgsql security definer set search_path = public
as $$
begin
  -- ประกาศที่ถึงเวลาเล่นแล้วแต่ไม่มีคนซื้อ → expired (ไม่ลบ เก็บไว้เป็นประวัติ)
  update public.listings
     set status = 'expired'
   where status in ('open', 'interested')
     and start_time <= now();

  -- ผู้ซื้อไม่กดยืนยันหรือแจ้งปัญหาภายใน 24 ชม. หลังเล่นจบ → ระบบยืนยันให้
  update public.orders o
     set status = 'confirmed', confirmed_at = now(), auto_confirmed = true
    from public.listings l
   where l.id = o.listing_id
     and o.status = 'held'
     and l.end_time + interval '24 hours' < now();

  -- ผู้ขายไม่ส่งหลักฐานภายใน 24 ชม. → คืนเงินผู้ซื้อ
  update public.orders
     set status = 'rejected',
         resolution = 'buyer',
         resolved_at = now(),
         reject_reason = 'ผู้ขายไม่ส่งหลักฐานภายใน 24 ชม.'
   where status = 'disputed'
     and evidence_path is null
     and disputed_at + interval '24 hours' < now();
end;
$$;

-- ผู้ซื้อกดยืนยันว่าได้เล่นแล้ว (กดได้ทันทีหลังชำระเงินสำเร็จ)
create or replace function public.confirm_play(p_order_id bigint)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  update public.orders
     set status = 'confirmed', confirmed_at = now()
   where id = p_order_id and buyer_id = auth.uid() and status = 'held';
  if not found then
    raise exception 'order_not_confirmable';
  end if;
end;
$$;

-- ผู้ซื้อแจ้งปัญหา (ตั้งแต่จ่ายเงินแล้ว จนถึง 24 ชม. หลังเล่นจบ)
create or replace function public.report_problem(
  p_order_id bigint,
  p_category text,
  p_reason text,
  p_photo_path text
)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_end timestamptz;
begin
  select l.end_time into v_end
    from public.orders o
    join public.listings l on l.id = o.listing_id
   where o.id = p_order_id and o.buyer_id = auth.uid() and o.status = 'held'
   for update of o;
  if not found then
    raise exception 'order_not_reportable';
  end if;
  if v_end + interval '24 hours' < now() then
    raise exception 'report_window_closed';
  end if;

  update public.orders
     set status = 'disputed',
         dispute_category = p_category,
         dispute_reason = p_reason,
         dispute_photo_path = p_photo_path,
         disputed_at = now()
   where id = p_order_id;
end;
$$;

-- ผู้ขายส่งหลักฐานโต้แย้ง (ภายใน 24 ชม. หลังผู้ซื้อแจ้งปัญหา)
create or replace function public.submit_dispute_evidence(
  p_order_id bigint,
  p_note text,
  p_evidence_path text
)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_order public.orders%rowtype;
begin
  select o.* into v_order
    from public.orders o
    join public.listings l on l.id = o.listing_id
   where o.id = p_order_id and l.seller_id = auth.uid()
   for update of o;
  if not found or v_order.status <> 'disputed' then
    raise exception 'order_not_disputed';
  end if;
  if v_order.disputed_at + interval '24 hours' < now() then
    raise exception 'evidence_window_closed';
  end if;

  update public.orders
     set seller_note = p_note, evidence_path = p_evidence_path, evidence_at = now()
   where id = p_order_id;
end;
$$;

-- แอดมินตัดสินข้อพิพาท: ผู้ซื้อถูก = rejected (คืนเงิน), ผู้ขายถูก = confirmed (โอนให้ผู้ขาย)
create or replace function public.resolve_dispute(
  p_order_id bigint,
  p_favor_buyer boolean,
  p_note text
)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'not_admin';
  end if;

  if p_favor_buyer then
    update public.orders
       set status = 'rejected', resolution = 'buyer', resolution_note = p_note,
           resolved_at = now(), reject_reason = 'ผลตัดสินข้อพิพาท: คืนเงินผู้ซื้อ'
     where id = p_order_id and status = 'disputed';
  else
    update public.orders
       set status = 'confirmed', resolution = 'seller', resolution_note = p_note,
           resolved_at = now(), confirmed_at = now()
     where id = p_order_id and status = 'disputed';
  end if;

  if not found then
    raise exception 'order_not_disputed';
  end if;
end;
$$;

-- แอดมินแบนผู้ซื้อหรือผู้ขายของคำสั่งซื้อนี้ (p_party = 'buyer' / 'seller')
--   ผู้ซื้อแจ้งปัญหาเท็จ → แบนผู้ซื้อ, หลักฐานการจองปลอม → แบนผู้ขาย
create or replace function public.ban_order_party(
  p_order_id bigint,
  p_party text,
  p_reason text
)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_user uuid;
begin
  if not public.is_admin() then
    raise exception 'not_admin';
  end if;
  if p_party not in ('buyer', 'seller') then
    raise exception 'bad_party';
  end if;

  select case when p_party = 'buyer' then o.buyer_id else l.seller_id end
    into v_user
    from public.orders o
    join public.listings l on l.id = o.listing_id
   where o.id = p_order_id;
  if v_user is null then
    raise exception 'order_not_found';
  end if;
  if exists (select 1 from public.admins where user_id = v_user) then
    raise exception 'cannot_ban_admin';
  end if;

  insert into public.banned_users (user_id, reason, order_id, banned_by)
  values (v_user, coalesce(p_reason, ''), p_order_id, auth.uid())
  on conflict (user_id) do update
    set reason = excluded.reason,
        order_id = excluded.order_id,
        banned_by = excluded.banned_by,
        banned_at = now();
end;
$$;


-- ---------------------------------------------------------------
-- 12. ฟังก์ชันอ่านข้อมูลสำหรับหน้าจอ
-- ---------------------------------------------------------------

-- จำนวนผู้ตั้งรับที่ตรงกับประกาศแต่ละอันของเรา (ป้ายบนการ์ดผู้ขาย)
create or replace function public.get_my_listing_request_counts()
returns table (listing_id bigint, request_count bigint)
language sql stable security definer set search_path = public
as $$
  select l.id, count(r.id)
    from public.listings l
    join public.requests r on public.listing_matches_request(l, r)
   where l.seller_id = auth.uid()
   group by l.id;
$$;

-- ผู้ตั้งรับที่ตรงกับประกาศนี้: ชื่อแบบย่อ (เช่น "สมชาย ร.") + ช่วงเวลาที่อยากเล่น
-- ผู้ขายอ่าน auth.users ตรง ๆ ไม่ได้ จึงต้องผ่านฟังก์ชันนี้
drop function if exists public.get_listing_requests(bigint);
create or replace function public.get_listing_requests(p_listing_id bigint)
returns table (
  request_id bigint,
  start_time timestamptz,
  end_time timestamptz,
  buyer_name text
)
language plpgsql stable security definer set search_path = public
as $$
begin
  if not exists (
    select 1 from public.listings
     where id = p_listing_id and seller_id = auth.uid()
  ) then
    raise exception 'not_your_listing';
  end if;

  return query
    select r.id, r.start_time, r.end_time,
           case
             when coalesce(trim(u.raw_user_meta_data ->> 'first_name'), '') <> '' then
               trim(u.raw_user_meta_data ->> 'first_name')
               || coalesce(' ' || nullif(left(trim(u.raw_user_meta_data ->> 'last_name'), 1), '') || '.', '')
             when coalesce(trim(u.raw_user_meta_data ->> 'name'), '') <> '' then
               trim(u.raw_user_meta_data ->> 'name')
             else 'ผู้ซื้อ'
           end
      from public.listings l
      join public.requests r on public.listing_matches_request(l, r)
      join auth.users u on u.id = r.buyer_id
     where l.id = p_listing_id
     order by r.created_at;
end;
$$;

-- ชื่อ-นามสกุลเต็มของผู้ขาย ให้เฉพาะผู้ซื้อของคำสั่งซื้อนี้ (หรือแอดมิน)
create or replace function public.get_order_seller_name(p_order_id bigint)
returns text
language sql stable security definer set search_path = public
as $$
  select coalesce(
           nullif(trim(concat_ws(' ',
             nullif(trim(u.raw_user_meta_data ->> 'first_name'), ''),
             nullif(trim(u.raw_user_meta_data ->> 'last_name'), ''))), ''),
           nullif(trim(u.raw_user_meta_data ->> 'name'), ''),
           l.seller_name)
    from public.orders o
    join public.listings l on l.id = o.listing_id
    join auth.users u on u.id = l.seller_id
   where o.id = p_order_id
     and (o.buyer_id = auth.uid() or public.is_admin());
$$;

-- แอดมินดูบัญชีรับเงินของผู้ขายในคำสั่งซื้อนี้ (ไม่มี = คืนแถวว่าง)
create or replace function public.get_seller_payout_account(p_order_id bigint)
returns setof public.payout_accounts
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'not_admin';
  end if;

  return query
    select p.*
      from public.orders o
      join public.listings l on l.id = o.listing_id
      join public.payout_accounts p on p.user_id = l.seller_id
     where o.id = p_order_id;
end;
$$;

-- เหตุผลที่เราโดนแบน (ไม่โดนแบน = null) แอปเช็กตอนล็อกอิน
create or replace function public.get_my_ban_reason()
returns text
language sql stable security definer set search_path = public
as $$
  select coalesce(nullif(trim(reason), ''), 'ละเมิดกติกาการใช้งาน')
    from public.banned_users
   where user_id = auth.uid();
$$;



-- ---------------------------------------------------------------
-- 13. Trigger
-- ---------------------------------------------------------------

-- ===== 13.1 ตัวช่วยสร้างแจ้งเตือน =====

-- ชื่อสนาม + วันเวลาเล่น เช่น "อัลไพน์ เทนนิส คลับ · 08/11 18:00"
create or replace function public.listing_label(p_listing_id bigint)
returns text
language sql stable security definer set search_path = public
as $$
  select coalesce(c.name, 'สนาม') || ' · '
         || to_char(l.start_time at time zone 'Asia/Bangkok', 'DD/MM HH24:MI')
    from public.listings l
    left join public.courts c on c.id = l.court_id
   where l.id = p_listing_id;
$$;

create or replace function public.add_notification(
  p_user uuid,
  p_side text,
  p_type text,
  p_title text,
  p_body text,
  p_order_id bigint,
  p_listing_id bigint,
  p_request_id bigint
)
returns void
language sql security definer set search_path = public
as $$
  insert into public.notifications
    (user_id, side, type, title, body, order_id, listing_id, request_id)
  values
    (p_user, p_side, p_type, p_title, coalesce(p_body, ''), p_order_id, p_listing_id, p_request_id);
$$;

-- ใช้ภายใน trigger เท่านั้น แอปเรียกเองไม่ได้
revoke execute on function public.add_notification(uuid, text, text, text, text, bigint, bigint, bigint)
  from public, anon, authenticated;

-- เติมกีฬาให้แจ้งเตือนจากประกาศ / การตั้งรับ (แอปใช้แสดงป้ายกีฬา)
create or replace function public.fill_notification_sport()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.sport is null and new.listing_id is not null then
    select l.sport into new.sport from public.listings l where l.id = new.listing_id;
  end if;
  if new.sport is null and new.request_id is not null then
    select r.sport into new.sport from public.requests r where r.id = new.request_id;
  end if;
  return new;
end;
$$;

drop trigger if exists notifications_fill_sport on public.notifications;
create trigger notifications_fill_sport
  before insert on public.notifications
  for each row execute function public.fill_notification_sport();


-- ===== 13.2 แจ้งเตือนเมื่อคำสั่งซื้อเปลี่ยน =====
create or replace function public.notify_order_change()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_seller uuid;
  v_place text;
begin
  select l.seller_id into v_seller from public.listings l where l.id = new.listing_id;
  v_place := public.listing_label(new.listing_id);

  -- มีคนกดซื้อ
  if tg_op = 'INSERT' then
    perform public.add_notification(v_seller, 'seller', 'order_created',
      'มีคนกดซื้อประกาศของคุณ', v_place || ' · รอผู้ซื้อชำระเงิน',
      new.id, new.listing_id, null);
    return new;
  end if;

  -- ผู้ขายส่งคำชี้แจงข้อพิพาท (สถานะยังเป็น disputed)
  if new.status = 'disputed' and new.evidence_at is distinct from old.evidence_at then
    perform public.add_notification(new.buyer_id, 'buyer', 'dispute_evidence',
      'ผู้ขายชี้แจงข้อพิพาทแล้ว', v_place || ' · รอแอดมินตัดสิน',
      new.id, new.listing_id, null);
  end if;

  if new.status is not distinct from old.status then
    return new;
  end if;

  if new.status = 'held' then
    perform public.add_notification(new.buyer_id, 'buyer', 'payment_held',
      'ชำระเงินสำเร็จ', v_place || ' · เงินพักไว้ที่ Courtswap ไปเล่นตามนัดได้เลย',
      new.id, new.listing_id, null);
    perform public.add_notification(v_seller, 'seller', 'order_paid',
      'ผู้ซื้อชำระเงินแล้ว', v_place || ' · เงินพักไว้ที่ Courtswap',
      new.id, new.listing_id, null);

  elsif new.status = 'rejected' and old.status = 'disputed' then
    -- ผลตัดสิน: คืนเงินผู้ซื้อ (รวมกรณีผู้ขายไม่ชี้แจงใน 24 ชม.)
    perform public.add_notification(new.buyer_id, 'buyer', 'dispute_resolved',
      'ผลตัดสิน: คืนเงินให้คุณ', v_place || ' · ' || coalesce(new.reject_reason, ''),
      new.id, new.listing_id, null);
    perform public.add_notification(v_seller, 'seller', 'dispute_resolved',
      'ผลตัดสิน: คืนเงินผู้ซื้อ', v_place || ' · ' || coalesce(new.reject_reason, ''),
      new.id, new.listing_id, null);

  elsif new.status = 'refunded' then
    perform public.add_notification(new.buyer_id, 'buyer', 'refunded',
      'คืนเงินแล้ว', '฿' || new.amount || ' เข้าบัญชีที่คุณโอนมา · ' || v_place,
      new.id, new.listing_id, null);

  elsif new.status = 'confirmed' and old.status = 'disputed' then
    -- ผลตัดสิน: โอนให้ผู้ขาย
    perform public.add_notification(new.buyer_id, 'buyer', 'dispute_resolved',
      'ผลตัดสิน: โอนเงินให้ผู้ขาย', v_place,
      new.id, new.listing_id, null);
    perform public.add_notification(v_seller, 'seller', 'dispute_resolved',
      'ผลตัดสิน: โอนเงินให้คุณ', v_place || ' · Courtswap กำลังโอนเงินให้คุณ',
      new.id, new.listing_id, null);

  elsif new.status = 'confirmed' then
    if new.auto_confirmed then
      perform public.add_notification(new.buyer_id, 'buyer', 'auto_confirmed',
        'ระบบยืนยันการเล่นให้แล้ว', v_place || ' · ไม่มีการแจ้งปัญหาภายใน 24 ชม.',
        new.id, new.listing_id, null);
    end if;
    perform public.add_notification(v_seller, 'seller', 'play_confirmed',
      'ผู้ซื้อยืนยันการเล่นแล้ว', v_place || ' · Courtswap กำลังโอนเงินให้คุณ',
      new.id, new.listing_id, null);

  elsif new.status = 'disputed' then
    perform public.add_notification(v_seller, 'seller', 'dispute_opened',
      'ผู้ซื้อแจ้งปัญหา ชี้แจงภายใน 24 ชม.',
      v_place || ' · ' || coalesce(nullif(new.dispute_category, ''), left(new.dispute_reason, 40)),
      new.id, new.listing_id, null);

  elsif new.status in ('expired', 'cancelled') and old.status = 'pending_payment' then
    perform public.add_notification(v_seller, 'seller', 'order_dropped',
      case when new.status = 'expired' then 'ผู้ซื้อไม่ชำระเงินภายในเวลา'
           else 'ผู้ซื้อยกเลิกการซื้อ' end,
      v_place || ' · ประกาศกลับมาเปิดขายแล้ว',
      new.id, new.listing_id, null);

  elsif new.status = 'released' then
    -- ยอดที่ผู้ขายได้รับ = ราคาขาย - ค่าธรรมเนียม 50 บาท (ตรงกับ kPlatformFee ในแอป)
    perform public.add_notification(v_seller, 'seller', 'payout_released',
      'โอนเงินให้คุณแล้ว', '฿' || greatest(new.amount - 50, 0) || ' · ' || v_place,
      new.id, new.listing_id, null);
  end if;

  return new;
end;
$$;

drop trigger if exists orders_notify on public.orders;
create trigger orders_notify
  after insert or update on public.orders
  for each row execute function public.notify_order_change();


-- ===== 13.3 แจ้งเตือนเมื่อประกาศ / การตั้งรับตรงกัน =====

-- ลงประกาศใหม่ → แจ้งผู้ซื้อที่ตั้งรับตรงกัน
create or replace function public.notify_new_listing()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.notifications (user_id, side, type, title, body, listing_id, request_id)
  select r.buyer_id, 'buyer', 'request_match',
         'มีสนามตรงกับที่คุณตั้งรับ',
         public.listing_label(new.id) || ' · ฿' || new.price,
         new.id, r.id
    from public.requests r
   where public.listing_matches_request(new, r);
  return new;
end;
$$;

drop trigger if exists listings_notify on public.listings;
create trigger listings_notify
  after insert on public.listings
  for each row execute function public.notify_new_listing();

-- ตั้งรับใหม่ → แจ้งผู้ขายที่มีประกาศตรงกัน
create or replace function public.notify_new_request()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.notifications (user_id, side, type, title, body, listing_id, request_id)
  select l.seller_id, 'seller', 'request_match',
         'มีผู้ตั้งรับตรงกับประกาศของคุณ',
         public.listing_label(l.id),
         l.id, new.id
    from public.listings l
   where public.listing_matches_request(l, new);
  return new;
end;
$$;

drop trigger if exists requests_notify on public.requests;
create trigger requests_notify
  after insert on public.requests
  for each row execute function public.notify_new_request();


-- ===== 13.4 การตั้งรับเปลี่ยนสถานะตามคำสั่งซื้อ =====

-- ซื้อประกาศที่ตรงกับการตั้งรับ → การตั้งรับเป็น matched
create or replace function public.match_requests_on_order()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  update public.requests r
     set status = 'matched', matched_order_id = new.id
    from public.listings l
   where l.id = new.listing_id
     and r.buyer_id = new.buyer_id
     and r.status = 'waiting'
     and public.listing_matches_request(l, r);
  return new;
end;
$$;

drop trigger if exists orders_match_requests on public.orders;
create trigger orders_match_requests
  after insert on public.orders
  for each row execute function public.match_requests_on_order();

-- คำสั่งซื้อหมดเวลา / ยกเลิก / คืนเงิน และยังไม่เลยเวลาที่ตั้งรับ → กลับเป็น waiting
create or replace function public.reopen_requests_on_order_end()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  update public.requests
     set status = 'waiting', matched_order_id = null
   where matched_order_id = new.id
     and status = 'matched'
     and end_time > now();
  return new;
end;
$$;

drop trigger if exists orders_reopen_requests on public.orders;
create trigger orders_reopen_requests
  after update of status on public.orders
  for each row
  when (new.status in ('expired', 'cancelled', 'refunded')
        and old.status is distinct from new.status)
  execute function public.reopen_requests_on_order_end();


-- ===== 13.5 คนที่โดนแบนสร้างรายการใหม่ไม่ได้ =====
-- (ระบบทำงานเอง เช่น Edge Function ไม่มี auth.uid() = ไม่เช็ก)
create or replace function public.block_banned_users()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is not null and public.is_banned(auth.uid()) then
    raise exception 'account_banned';
  end if;
  return new;
end;
$$;

drop trigger if exists orders_block_banned on public.orders;
create trigger orders_block_banned
  before insert on public.orders
  for each row execute function public.block_banned_users();

drop trigger if exists listings_block_banned on public.listings;
create trigger listings_block_banned
  before insert on public.listings
  for each row execute function public.block_banned_users();

drop trigger if exists requests_block_banned on public.requests;
create trigger requests_block_banned
  before insert on public.requests
  for each row execute function public.block_banned_users();


-- ===== 13.6 โอนเงินให้ผู้ขายอัตโนมัติเมื่อคำสั่งซื้อเป็น confirmed =====
-- trigger เรียก Edge Function transfers ผ่าน pg_net
-- โอนไม่สำเร็จ (เช่น ผู้ขายยังไม่กรอกบัญชี) → แอดมินกดโอนใหม่ได้
--
-- ต้องตั้งรหัสลับครั้งเดียว (ไม่ใส่ในไฟล์นี้):
--   1. สร้างรหัสสุ่ม:  openssl rand -hex 32
--   2. supabase secrets set INTERNAL_TRANSFER_SECRET=<รหัส>
--   3. รันใน SQL Editor:  select vault.create_secret('<รหัส>', 'internal_transfer_secret');
create extension if not exists pg_net with schema extensions;

create or replace function public.auto_payout_on_confirm()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_secret text;
begin
  select decrypted_secret into v_secret
    from vault.decrypted_secrets
   where name = 'internal_transfer_secret'
   limit 1;
  if v_secret is null then
    -- ยังไม่ได้ตั้งรหัส: ข้ามการโอนอัตโนมัติ (แอดมินกดโอนเองได้)
    raise warning 'internal_transfer_secret not set, skip auto payout for order %', new.id;
    return new;
  end if;

  perform net.http_post(
    url := 'https://szwfwgtzuziysbwpskus.supabase.co/functions/v1/transfers',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-Internal-Secret', v_secret
    ),
    body := jsonb_build_object('order_id', new.id, 'kind', 'payout')
  );
  return new;
end;
$$;

drop trigger if exists orders_auto_payout on public.orders;
create trigger orders_auto_payout
  after update of status on public.orders
  for each row
  when (new.status = 'confirmed' and old.status is distinct from 'confirmed')
  execute function public.auto_payout_on_confirm();


-- ---------------------------------------------------------------
-- 14. งานตั้งเวลา (pg_cron)
--   เช็กกำหนดเวลา 24 ชม. ทุก 10 นาที ไม่ต้องรอให้มีคนเปิดแอป
--   (ชื่อเดิม = อัปเดตตารางเวลาเดิม รันซ้ำได้)
-- ---------------------------------------------------------------
create extension if not exists pg_cron;

select cron.schedule(
  'play-deadlines',
  '*/10 * * * *',
  'select public.process_play_deadlines()'
);


-- ---------------------------------------------------------------
-- 15. ล้างของรุ่นเก่าที่ยังค้างในฐานข้อมูล (ไม่มีที่ไหนใช้แล้ว)
--   ต้องเก็บคำสั่งไว้ในไฟล์นี้ จะได้รู้ว่าเคยมีอะไรและลบไปเพราะอะไร
--   รันซ้ำได้ (if exists)
-- ---------------------------------------------------------------

-- ฟังก์ชันรายงานรุ่นแรก: ตอนนี้แอปดึง orders ด้วย .from('orders').select()
-- แล้วรวมยอดใน Dart (lib/services/report_service.dart, lib/models/report_model.dart)
drop function if exists public.get_admin_sales_report(text);
drop function if exists public.get_admin_order_status_report();
drop function if exists public.get_my_income_report();

-- แอดมินกดคืนเงิน / โอนให้ผู้ขายเองรุ่นแรก: เปลี่ยนสถานะอย่างเดียวโดยไม่โอนเงินจริง
-- ตอนนี้ใช้ Edge Function transfers + complete_transfer (หัวข้อ 10) แทน
drop function if exists public.mark_refunded(bigint);
drop function if exists public.release_to_seller(bigint);

-- อ่านแจ้งเตือนรุ่นแรก (rpc): ตอนนี้แอปใช้ .from('notifications').update() แทน
-- สิทธิ์อยู่ที่ policy "users mark own notifications read" (หัวข้อ 8)
drop function if exists public.mark_notification_read(bigint);
drop function if exists public.mark_all_notifications_read();

-- ตาราง users รุ่นแรก (เก็บแค่ id + email ซ้ำกับ auth.users)
-- แอปเก็บชื่อ/เบอร์ใน user metadata ของ Supabase Auth แทน (lib/pages/03_signupPage.dart)
-- ลบ trigger ก่อน ไม่งั้นสมัครสมาชิกจะพังตอนตารางหายไป
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();
drop table if exists public.users;  -- ไม่ใส่ cascade: ถ้ามีอะไรอ้างถึงอยู่จะ error ไม่ลบ

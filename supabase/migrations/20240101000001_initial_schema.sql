-- Smenube.ru - Initial Database Schema
-- Version: 1.0
-- Description: Создание базовых таблиц для платформы

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- ========== PROFILES TABLE ==========
-- Расширяет auth.users, содержит данные пользователей
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  
  -- Роли: client (заказчик), worker (исполнитель), admin (администратор)
  role TEXT NOT NULL DEFAULT 'worker' 
    CHECK (role IN ('client', 'worker', 'admin')),
  
  -- Основная информация
  full_name TEXT,
  phone TEXT UNIQUE NOT NULL,
  avatar_url TEXT,
  
  -- Рейтинг и статистика
  rating NUMERIC DEFAULT 5.0,
  completed_orders INTEGER DEFAULT 0,
  is_verified BOOLEAN DEFAULT FALSE,
  
  -- Тимestamps
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ========== GIGS TABLE ==========
-- Таблица смен (заданий)
CREATE TABLE IF NOT EXISTS public.gigs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  
  -- Связь с заказчиком
  client_id UUID REFERENCES public.profiles(id) NOT NULL,
  
  -- Основная информация
  title TEXT NOT NULL,
  description TEXT,
  
  -- Категория работы
  category TEXT NOT NULL DEFAULT 'other' 
    CHECK (category IN ('moving', 'cleaning', 'repair', 'delivery', 'other')),
  
  -- Адрес и геолокация
  address TEXT NOT NULL,
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  
  -- Финансы
  price INTEGER NOT NULL CHECK (price > 0),
  balance_hold INTEGER DEFAULT 0, -- Замороженная сумма на счету заказчика
  
  -- Время и продолжительность
  hours_per_shift INTEGER DEFAULT 8,
  start_time TIME,
  end_time TIME,
  
  -- Количество исполнителей
  slots INTEGER DEFAULT 1 CHECK (slots > 0),
  
  -- Дополнительные опции
  has_corporate_transport BOOLEAN DEFAULT FALSE,
  auto_confirm BOOLEAN DEFAULT FALSE, -- Автоподтверждение заявок
  
  -- Статус смены
  status TEXT DEFAULT 'open' 
    CHECK (status IN ('open', 'assigned', 'in_progress', 'completed', 'cancelled')),
  
  -- Таймстампы
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ========== GIG_RECURRING TABLE ==========
-- Повторяющиеся смены (для выбора нескольких дней)
CREATE TABLE IF NOT EXISTS public.gig_recurring (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  gig_id UUID REFERENCES public.gigs(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL,
  status TEXT DEFAULT 'scheduled' 
    CHECK (status IN ('scheduled', 'completed', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ========== GIG_PHOTOS TABLE ==========
-- Фотографии объектов
CREATE TABLE IF NOT EXISTS public.gig_photos (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  gig_id UUID REFERENCES public.gigs(id) ON DELETE CASCADE NOT NULL,
  url TEXT NOT NULL,
  order_index INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ========== PROPOSALS TABLE ==========
-- Заявки исполнителей на смены
CREATE TABLE IF NOT EXISTS public.proposals (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  gig_id UUID REFERENCES public.gigs(id) ON DELETE CASCADE NOT NULL,
  worker_id UUID REFERENCES public.profiles(id) NOT NULL,
  message TEXT,
  status TEXT DEFAULT 'pending' 
    CHECK (status IN ('pending', 'accepted', 'rejected', 'withdrawn')),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  
  -- Один исполнитель может подать только одну заявку на смену
  UNIQUE(gig_id, worker_id)
);

-- ========== TRANSACTIONS TABLE ==========
-- Финансовые транзакции
CREATE TABLE IF NOT EXISTS public.transactions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  gig_id UUID REFERENCES public.gigs(id),
  from_user UUID REFERENCES public.profiles(id),
  to_user UUID REFERENCES public.profiles(id),
  amount INTEGER NOT NULL,
  commission INTEGER DEFAULT 0,
  type TEXT CHECK (type IN ('payment', 'payout', 'refund')),
  status TEXT DEFAULT 'pending' 
    CHECK (status IN ('pending', 'completed', 'failed', 'hold')),
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ========== REVIEWS TABLE ==========
-- Отзывы и рейтинги
CREATE TABLE IF NOT EXISTS public.reviews (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  gig_id UUID REFERENCES public.gigs(id) NOT NULL,
  author_id UUID REFERENCES public.profiles(id) NOT NULL,
  target_id UUID REFERENCES public.profiles(id) NOT NULL,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  
  -- Один отзыв на одну смену
  UNIQUE(gig_id, author_id, target_id)
);

-- ========== HIDDEN_WORKERS TABLE ==========
-- Скрытые исполнители (кнопка "скрыть мои смены от этого исполнителя")
CREATE TABLE IF NOT EXISTS public.hidden_workers (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  client_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  worker_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  
  -- Одна запись на пару клиент-исполнитель
  UNIQUE(client_id, worker_id)
);

-- ========== CHATS TABLE ==========
-- Сообщения между пользователями
CREATE TABLE IF NOT EXISTS public.chats (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  gig_id UUID REFERENCES public.gigs(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES public.profiles(id) NOT NULL,
  receiver_id UUID REFERENCES public.profiles(id) NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ========== INDEXES ==========
-- Индексы для производительности

-- Для быстрого поиска смен по статусу
CREATE INDEX IF NOT EXISTS idx_gigs_status ON public.gigs(status);
CREATE INDEX IF NOT EXISTS idx_gigs_client_id ON public.gigs(client_id);

-- Для поиска по геолокации
CREATE INDEX IF NOT EXISTS idx_gigs_location ON public.gigs USING GIST (
  ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
);

-- Для поиска пользователей по телефону
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON public.profiles(phone);

-- Для заявок
CREATE INDEX IF NOT EXISTS idx_proposals_gig_id ON public.proposals(gig_id);
CREATE INDEX IF NOT EXISTS idx_proposals_worker_id ON public.proposals(worker_id);
CREATE INDEX IF NOT EXISTS idx_proposals_status ON public.proposals(status);

-- Для повторяющихся смен
CREATE INDEX IF NOT EXISTS idx_gig_recurring_date ON public.gig_recurring(date);
CREATE INDEX IF NOT EXISTS idx_gig_recurring_gig_id ON public.gig_recurring(gig_id);

-- Для чатов
CREATE INDEX IF NOT EXISTS idx_chats_gig_id ON public.chats(gig_id);
CREATE INDEX IF NOT EXISTS idx_chats_sender_receiver ON public.chats(sender_id, receiver_id);

-- ========== ROW LEVEL SECURITY ==========
-- Включаем RLS для всех таблиц
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gigs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gig_recurring ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gig_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hidden_workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;

-- ========== RLS POLICIES ==========

-- Профили: все видят профили, но редактировать можно только свой
CREATE POLICY "Профили видны всем" 
ON public.profiles FOR SELECT 
USING (true);

CREATE POLICY "Пользователи обновляют свой профиль" 
ON public.profiles FOR UPDATE 
USING (auth.uid() = id);

-- Смены: 
-- 1. Все видят открытые смены
-- 2. Заказчик видит все свои смены
-- 3. Исполнители не видят смены, где их скрыли
CREATE POLICY "Смены видны всем кроме скрытых" 
ON public.gigs FOR SELECT 
USING (
  status = 'open' 
  AND NOT EXISTS (
    SELECT 1 FROM public.hidden_workers hw 
    WHERE hw.client_id = gigs.client_id 
    AND hw.worker_id = auth.uid()
  )
  OR client_id = auth.uid()
);

CREATE POLICY "Заказчики создают смены" 
ON public.gigs FOR INSERT 
WITH CHECK (auth.uid() = client_id);

CREATE POLICY "Заказчики обновляют свои смены" 
ON public.gigs FOR UPDATE 
USING (auth.uid() = client_id);

-- Заявки: видны заказчику смены и исполнителю
CREATE POLICY "Заявки видны заказчику и исполнителю" 
ON public.proposals FOR SELECT 
USING (
  auth.uid() IN (
    SELECT client_id FROM public.gigs WHERE id = gig_id
  ) OR auth.uid() = worker_id
);

CREATE POLICY "Исполнители создают заявки" 
ON public.proposals FOR INSERT 
WITH CHECK (auth.uid() = worker_id);

-- ========== FUNCTIONS & TRIGGERS ==========

-- Функция для обновления updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Триггеры для updated_at
CREATE TRIGGER update_profiles_updated_at 
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_gigs_updated_at 
  BEFORE UPDATE ON public.gigs
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Функция для автоматического создания профиля при регистрации
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, phone, role)
  VALUES (
    NEW.id,
    NEW.phone,
    CASE 
      WHEN NEW.email LIKE '%@smenube.ru' THEN 'admin'
      ELSE 'client'
    END
  );
  RETURN NEW;
END;
$$ language 'plpgsql' SECURITY DEFINER;

-- Триггер для автоматического создания профиля
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ========== STORAGE BUCKETS ==========
-- Создаем бакеты для хранения файлов
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('gig-photos', 'gig-photos', true),
  ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Политики для storage
CREATE POLICY "Гостям доступны фото смен" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'gig-photos');

CREATE POLICY "Пользователи загружают фото смен" 
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'gig-photos' 
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Пользователи удаляют свои фото" 
ON storage.objects FOR DELETE 
USING (
  bucket_id = 'gig-photos' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- ========== COMMENTS ==========
COMMENT ON TABLE public.profiles IS 'Профили пользователей платформы';
COMMENT ON TABLE public.gigs IS 'Смены (задания) созданные заказчиками';
COMMENT ON TABLE public.gig_recurring IS 'Повторяющиеся дни для смен';
COMMENT ON TABLE public.proposals IS 'Заявки исполнителей на смены';
COMMENT ON COLUMN public.gigs.auto_confirm IS 'Автоматическое подтверждение заявок от исполнителей';
COMMENT ON COLUMN public.hidden_workers.client_id IS 'Заказчик, который скрыл исполнителя';
COMMENT ON COLUMN public.hidden_workers.worker_id IS 'Исполнитель, которого скрыли';

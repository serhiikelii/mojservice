-- Migration: Add category-specific services support
-- Date: 2025-11-03
-- Author: Blueprint Architect
--
-- Problem: Currently all services are available for all device categories.
-- Solution: Add many-to-many relationship between categories and services.

-- ============================================================================
-- 1. CREATE CATEGORY_SERVICES JOIN TABLE
-- ============================================================================
CREATE TABLE category_services (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  category_id UUID NOT NULL REFERENCES device_categories(id) ON DELETE CASCADE,
  service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Ensure unique combination of category and service
  UNIQUE(category_id, service_id)
);

-- Indexes for faster lookups
CREATE INDEX idx_category_services_category_id ON category_services(category_id);
CREATE INDEX idx_category_services_service_id ON category_services(service_id);
CREATE INDEX idx_category_services_active ON category_services(is_active);

-- Trigger for updated_at
CREATE TRIGGER update_category_services_updated_at BEFORE UPDATE ON category_services
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 2. ENABLE RLS ON CATEGORY_SERVICES
-- ============================================================================
ALTER TABLE category_services ENABLE ROW LEVEL SECURITY;

-- Public read access
CREATE POLICY "Public read access for category_services" ON category_services
  FOR SELECT USING (is_active = true);

-- ============================================================================
-- 3. SEED CATEGORY-SPECIFIC SERVICES
-- ============================================================================

-- First, insert all services with multilingual names
INSERT INTO services (slug, name_ru, name_en, name_cz, service_type, "order") VALUES
-- iPhone services
('iphone-display-original-prc', 'Замена дисплея оригинал PRC', 'Display Replacement Original PRC', 'Výměna displeje originál PRC', 'main', 10),
('iphone-display-analog', 'Замена дисплея (аналог)', 'Display Replacement (Analog)', 'Výměna displeje (analog)', 'main', 20),
('iphone-battery', 'Замена аккумулятора', 'Battery Replacement', 'Výměna baterie', 'main', 30),
('iphone-back-glass', 'Замена заднего стеклокорпуса', 'Back Glass Replacement', 'Výměna zadního skla', 'main', 40),
('iphone-housing', 'Замена корпуса', 'Housing Replacement', 'Výměna krytu', 'main', 50),
('iphone-camera-main', 'Замена основной камеры', 'Main Camera Replacement', 'Výměna hlavní kamery', 'main', 60),
('iphone-charging-cable', 'Замена шлейфа зарядки', 'Charging Cable Replacement', 'Výměna nabíjecího kabelu', 'main', 70),
('iphone-water-damage', 'Восстановление от повреждения водой', 'Water Damage Recovery', 'Obnova po poškození vodou', 'main', 80),

-- iPad services
('ipad-glass', 'Замена стекла дисплея', 'Display Glass Replacement', 'Výměna skla displeje', 'main', 10),
('ipad-digitizer', 'Замена сенсора дисплея', 'Digitizer Replacement', 'Výměna digitizéru', 'main', 20),
('ipad-display-original', 'Замена дисплея оригинал', 'Display Replacement Original', 'Výměna displeje originál', 'main', 30),
('ipad-battery', 'Замена аккумулятора', 'Battery Replacement', 'Výměna baterie', 'main', 40),
('ipad-water-damage', 'Восстановление от повреждения водой', 'Water Damage Recovery', 'Obnova po poškození vodou', 'main', 50),
('ipad-charging-port', 'Замена разъема зарядки', 'Charging Port Replacement', 'Výměna nabíjecího portu', 'main', 60),

-- MacBook services
('macbook-display', 'Замена дисплея', 'Display Replacement', 'Výměna displeje', 'main', 10),
('macbook-battery', 'Замена аккумулятора', 'Battery Replacement', 'Výměna baterie', 'main', 20),
('macbook-keyboard', 'Замена клавиатуры', 'Keyboard Replacement', 'Výměna klávesnice', 'main', 30),
('macbook-thermal-paste', 'Чистка, замена термопасты', 'Cleaning, Thermal Paste Replacement', 'Čištění, výměna termální pasty', 'main', 40),

-- Apple Watch services
('watch-glass', 'Замена стекла', 'Glass Replacement', 'Výměna skla', 'main', 10),
('watch-digitizer', 'Замена сенсора', 'Digitizer Replacement', 'Výměna senzoru', 'main', 20),
('watch-display', 'Замена дисплея', 'Display Replacement', 'Výměna displeje', 'main', 30),
('watch-battery', 'Замена аккумулятора', 'Battery Replacement', 'Výměna baterie', 'main', 40),
('watch-nfc', 'Восстановление NFC', 'NFC Recovery', 'Obnova NFC', 'main', 50)
ON CONFLICT (slug) DO NOTHING;

-- Link services to categories
-- Get category IDs (assuming they exist from initial migration)
DO $$
DECLARE
  iphone_id UUID;
  ipad_id UUID;
  macbook_id UUID;
  watch_id UUID;
BEGIN
  -- Get category IDs
  SELECT id INTO iphone_id FROM device_categories WHERE slug = 'iphone';
  SELECT id INTO ipad_id FROM device_categories WHERE slug = 'ipad';
  SELECT id INTO macbook_id FROM device_categories WHERE slug = 'macbook';
  SELECT id INTO watch_id FROM device_categories WHERE slug = 'apple-watch';

  -- Link iPhone services
  INSERT INTO category_services (category_id, service_id, is_active)
  SELECT iphone_id, id, true FROM services WHERE slug IN (
    'iphone-display-original-prc',
    'iphone-display-analog',
    'iphone-battery',
    'iphone-back-glass',
    'iphone-housing',
    'iphone-camera-main',
    'iphone-charging-cable',
    'iphone-water-damage'
  ) ON CONFLICT DO NOTHING;

  -- Link iPad services
  INSERT INTO category_services (category_id, service_id, is_active)
  SELECT ipad_id, id, true FROM services WHERE slug IN (
    'ipad-glass',
    'ipad-digitizer',
    'ipad-display-original',
    'ipad-battery',
    'ipad-water-damage',
    'ipad-charging-port'
  ) ON CONFLICT DO NOTHING;

  -- Link MacBook services
  INSERT INTO category_services (category_id, service_id, is_active)
  SELECT macbook_id, id, true FROM services WHERE slug IN (
    'macbook-display',
    'macbook-battery',
    'macbook-keyboard',
    'macbook-thermal-paste'
  ) ON CONFLICT DO NOTHING;

  -- Link Apple Watch services
  INSERT INTO category_services (category_id, service_id, is_active)
  SELECT watch_id, id, true FROM services WHERE slug IN (
    'watch-glass',
    'watch-digitizer',
    'watch-display',
    'watch-battery',
    'watch-nfc'
  ) ON CONFLICT DO NOTHING;
END $$;

-- ============================================================================
-- 4. CREATE VIEW FOR EASY QUERYING
-- ============================================================================
CREATE OR REPLACE VIEW category_services_view AS
SELECT
  cs.id,
  cs.category_id,
  dc.slug as category_slug,
  dc.name_ru as category_name_ru,
  dc.name_en as category_name_en,
  dc.name_cz as category_name_cz,
  cs.service_id,
  s.slug as service_slug,
  s.name_ru as service_name_ru,
  s.name_en as service_name_en,
  s.name_cz as service_name_cz,
  s.service_type,
  s."order" as service_order,
  cs.is_active,
  cs.created_at,
  cs.updated_at
FROM category_services cs
JOIN device_categories dc ON cs.category_id = dc.id
JOIN services s ON cs.service_id = s.id
WHERE cs.is_active = true
ORDER BY dc."order", s."order";

-- Grant public read access to view
GRANT SELECT ON category_services_view TO anon, authenticated;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================
COMMENT ON TABLE category_services IS 'Many-to-many relationship between device categories and services. Each category can have multiple specific services.';
COMMENT ON COLUMN category_services.is_active IS 'Allows soft-deletion of category-service relationships without losing data';
COMMENT ON VIEW category_services_view IS 'Convenient view for fetching category-specific services with all related data';

-- Migration: Seed prices for category-specific services
-- Date: 2025-11-03
-- Author: Blueprint Architect
--
-- This file adds example prices for all category-specific services across different models.
-- Prices are representative and should be adjusted based on actual market rates.

-- ============================================================================
-- HELPER FUNCTION: Add price for all models in a category
-- ============================================================================
CREATE OR REPLACE FUNCTION add_prices_for_category(
  p_category_slug TEXT,
  p_service_slug TEXT,
  p_price DECIMAL(10, 2),
  p_price_type price_type_enum DEFAULT 'fixed',
  p_duration_minutes INTEGER DEFAULT 60,
  p_warranty_months INTEGER DEFAULT 24
)
RETURNS void AS $$
DECLARE
  v_service_id UUID;
  v_model_record RECORD;
BEGIN
  -- Get service ID
  SELECT id INTO v_service_id FROM services WHERE slug = p_service_slug;

  IF v_service_id IS NULL THEN
    RAISE NOTICE 'Service % not found', p_service_slug;
    RETURN;
  END IF;

  -- Add price for all models in this category
  FOR v_model_record IN
    SELECT dm.id as model_id
    FROM device_models dm
    JOIN device_categories dc ON dm.category_id = dc.id
    WHERE dc.slug = p_category_slug
  LOOP
    INSERT INTO prices (model_id, service_id, price, price_type, duration_minutes, warranty_months)
    VALUES (v_model_record.model_id, v_service_id, p_price, p_price_type, p_duration_minutes, p_warranty_months)
    ON CONFLICT (model_id, service_id) DO UPDATE
    SET price = p_price, price_type = p_price_type, duration_minutes = p_duration_minutes;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SEED PRICES FOR iPHONE SERVICES
-- ============================================================================

-- Display replacements (most expensive, varies by model generation)
SELECT add_prices_for_category('iphone', 'iphone-display-original-prc', 4500.00, 'from', 45, 24);
SELECT add_prices_for_category('iphone', 'iphone-display-analog', 2800.00, 'from', 45, 12);

-- Battery replacement (standard price across most models)
SELECT add_prices_for_category('iphone', 'iphone-battery', 1500.00, 'fixed', 30, 24);

-- Back glass and housing (labor-intensive)
SELECT add_prices_for_category('iphone', 'iphone-back-glass', 3200.00, 'from', 90, 12);
SELECT add_prices_for_category('iphone', 'iphone-housing', 4800.00, 'from', 120, 12);

-- Camera and charging cable (component replacements)
SELECT add_prices_for_category('iphone', 'iphone-camera-main', 2500.00, 'from', 45, 24);
SELECT add_prices_for_category('iphone', 'iphone-charging-cable', 1800.00, 'fixed', 30, 24);

-- Water damage recovery (diagnostic + repair)
SELECT add_prices_for_category('iphone', 'iphone-water-damage', 2000.00, 'from', 180, 6);

-- ============================================================================
-- SEED PRICES FOR iPAD SERVICES
-- ============================================================================

-- Glass and digitizer (varies by iPad model size)
SELECT add_prices_for_category('ipad', 'ipad-glass', 3500.00, 'from', 60, 12);
SELECT add_prices_for_category('ipad', 'ipad-digitizer', 4200.00, 'from', 60, 12);

-- Full display replacement (most expensive for iPad)
SELECT add_prices_for_category('ipad', 'ipad-display-original', 6500.00, 'from', 90, 24);

-- Battery replacement (larger capacity = higher price)
SELECT add_prices_for_category('ipad', 'ipad-battery', 2800.00, 'from', 60, 24);

-- Charging port and water damage
SELECT add_prices_for_category('ipad', 'ipad-charging-port', 2200.00, 'fixed', 45, 24);
SELECT add_prices_for_category('ipad', 'ipad-water-damage', 3000.00, 'from', 240, 6);

-- ============================================================================
-- SEED PRICES FOR MacBook SERVICES
-- ============================================================================

-- Display replacement (most expensive MacBook service)
SELECT add_prices_for_category('macbook', 'macbook-display', 15000.00, 'from', 120, 24);

-- Battery replacement (varies by MacBook model)
SELECT add_prices_for_category('macbook', 'macbook-battery', 6500.00, 'from', 90, 24);

-- Keyboard replacement (especially for butterfly keyboards)
SELECT add_prices_for_category('macbook', 'macbook-keyboard', 8000.00, 'from', 180, 12);

-- Thermal paste and cleaning (maintenance service)
SELECT add_prices_for_category('macbook', 'macbook-thermal-paste', 2500.00, 'fixed', 90, 6);

-- ============================================================================
-- SEED PRICES FOR Apple Watch SERVICES
-- ============================================================================

-- Glass replacement (precision work)
SELECT add_prices_for_category('apple-watch', 'watch-glass', 2500.00, 'from', 45, 12);

-- Digitizer replacement
SELECT add_prices_for_category('apple-watch', 'watch-digitizer', 3200.00, 'from', 45, 12);

-- Full display replacement
SELECT add_prices_for_category('apple-watch', 'watch-display', 4500.00, 'from', 60, 24);

-- Battery replacement (small component, delicate work)
SELECT add_prices_for_category('apple-watch', 'watch-battery', 2000.00, 'fixed', 30, 24);

-- NFC recovery (specialized service)
SELECT add_prices_for_category('apple-watch', 'watch-nfc', 3500.00, 'from', 90, 12);

-- ============================================================================
-- CLEANUP: Drop helper function
-- ============================================================================
DROP FUNCTION add_prices_for_category;

-- ============================================================================
-- VERIFICATION QUERY (commented out, uncomment to check results)
-- ============================================================================
/*
SELECT
  dc.name_en as category,
  dm.name as model,
  s.name_en as service,
  p.price,
  p.price_type,
  p.duration_minutes,
  p.warranty_months
FROM prices p
JOIN device_models dm ON p.model_id = dm.id
JOIN device_categories dc ON dm.category_id = dc.id
JOIN services s ON p.service_id = s.id
ORDER BY dc."order", dm."order", s."order";
*/

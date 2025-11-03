# ADR-001: Category-Specific Services Architecture

**Status:** Accepted
**Date:** 2025-11-03
**Author:** Blueprint Architect
**Deciders:** Development Team

---

## Context and Problem Statement

The initial database schema was designed without consideration that different Apple device categories (iPhone, iPad, MacBook, Apple Watch) require **different types of repair services**.

**Current Problem:**
- All services are available for all device categories
- Cannot distinguish between iPhone-specific services (e.g., "Back glass replacement") and MacBook-specific services (e.g., "Keyboard replacement")
- Pricelist pages show irrelevant services for each category
- Admin panel cannot manage services per category

**Example Issues:**
- Apple Watch shows "Keyboard replacement" (MacBook service)
- MacBook shows "NFC recovery" (Apple Watch service)
- iPad shows "Back glass replacement" (iPhone-specific)

---

## Decision Drivers

1. **Business Requirements:** Each device category has unique repair services
2. **User Experience:** Users should only see relevant services for their device
3. **Data Integrity:** Prevent incorrect price entries (e.g., keyboard price for Apple Watch)
4. **Scalability:** Easy to add new categories and services in the future
5. **Maintainability:** Clear relationship between categories and services

---

## Considered Options

### Option 1: Add Category Field to Services Table ❌
```sql
ALTER TABLE services ADD COLUMN category_id UUID REFERENCES device_categories(id);
```

**Pros:**
- Simple to implement
- Easy to query

**Cons:**
- **Cannot support services used by multiple categories** (e.g., "Battery replacement" for iPhone and iPad)
- Requires service duplication for shared services
- Difficult to manage shared vs. unique services

### Option 2: Many-to-Many Relationship (category_services) ✅ **SELECTED**
```sql
CREATE TABLE category_services (
  category_id UUID REFERENCES device_categories(id),
  service_id UUID REFERENCES services(id),
  UNIQUE(category_id, service_id)
);
```

**Pros:**
- **Flexible:** Services can belong to one or multiple categories
- **No Duplication:** Shared services (e.g., "Battery replacement") exist once
- **Extensible:** Easy to add/remove category-service relationships
- **Data Integrity:** Unique constraint prevents duplicates

**Cons:**
- Additional join table (minimal overhead)
- Slightly more complex queries

### Option 3: JSON Array in Categories Table ❌
```sql
ALTER TABLE device_categories ADD COLUMN service_ids UUID[];
```

**Pros:**
- No additional table

**Cons:**
- **Poor data integrity:** No foreign key constraints
- **Difficult queries:** Cannot efficiently filter or join
- **No audit trail:** Hard to track changes
- **Anti-pattern** in relational databases

---

## Decision Outcome

**Chosen Option:** Option 2 - Many-to-Many Relationship via `category_services` table

**Justification:**
- Provides maximum flexibility for current and future requirements
- Maintains data integrity with proper foreign keys
- Supports both unique and shared services across categories
- Industry-standard approach for many-to-many relationships
- Easy to query with SQL joins or ORMs

---

## Architecture Design

### Database Schema

```
device_categories (iPhone, iPad, MacBook, Watch)
        ↓
category_services (Many-to-Many Join Table)
        ↓
services (Display, Battery, Keyboard, etc.)
        ↓
prices (Model-specific pricing)
```

### New Table: category_services

```sql
CREATE TABLE category_services (
  id UUID PRIMARY KEY,
  category_id UUID NOT NULL REFERENCES device_categories(id),
  service_id UUID NOT NULL REFERENCES services(id),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  UNIQUE(category_id, service_id)
);
```

**Fields:**
- `id`: Primary key (UUID)
- `category_id`: Reference to device category
- `service_id`: Reference to service
- `is_active`: Soft delete flag (disable without losing data)
- `created_at`, `updated_at`: Audit timestamps

**Indexes:**
- `idx_category_services_category_id` - Fast lookups by category
- `idx_category_services_service_id` - Fast lookups by service
- `idx_category_services_active` - Filter active relationships

### Convenience View: category_services_view

```sql
CREATE VIEW category_services_view AS
SELECT
  cs.id,
  dc.slug as category_slug,
  dc.name_ru as category_name_ru,
  s.slug as service_slug,
  s.name_ru as service_name_ru,
  s.service_type,
  s."order" as service_order,
  cs.is_active
FROM category_services cs
JOIN device_categories dc ON cs.category_id = dc.id
JOIN services s ON cs.service_id = s.id
WHERE cs.is_active = true
ORDER BY dc."order", s."order";
```

**Benefits:**
- Simplified queries for frontend
- Pre-joined data for common use cases
- Read-only access for public users

---

## Services Breakdown by Category

### iPhone (8 services)
1. Замена дисплея оригинал PRC - 4500 CZK (from)
2. Замена дисплея (аналог) - 2800 CZK (from)
3. Замена аккумулятора - 1500 CZK (fixed)
4. Замена заднего стеклокорпуса - 3200 CZK (from)
5. Замена корпуса - 4800 CZK (from)
6. Замена основной камеры - 2500 CZK (from)
7. Замена шлейфа зарядки - 1800 CZK (fixed)
8. Восстановление от повреждения водой - 2000 CZK (from)

### iPad (6 services)
1. Замена стекла дисплея - 3500 CZK (from)
2. Замена сенсора дисплея - 4200 CZK (from)
3. Замена дисплея оригинал - 6500 CZK (from)
4. Замена аккумулятора - 2800 CZK (from)
5. Восстановление от повреждения водой - 3000 CZK (from)
6. Замена разъема зарядки - 2200 CZK (fixed)

### MacBook (4 services)
1. Замена дисплея - 15000 CZK (from)
2. Замена аккумулятора - 6500 CZK (from)
3. Замена клавиатуры - 8000 CZK (from)
4. Чистка, замена термопасты - 2500 CZK (fixed)

### Apple Watch (5 services)
1. Замена стекла - 2500 CZK (from)
2. Замена сенсора - 3200 CZK (from)
3. Замена дисплея - 4500 CZK (from)
4. Замена аккумулятора - 2000 CZK (fixed)
5. Восстановление NFC - 3500 CZK (from)

**Total:** 23 unique services across 4 categories

---

## Implementation Plan

### Phase 1: Database Migration ✅
- [x] Create `category_services` table
- [x] Add indexes and RLS policies
- [x] Create `category_services_view`
- [x] Seed 23 category-specific services
- [x] Link services to categories
- [x] Seed example prices for all services

**Files:**
- `supabase/migrations/20251103_add_category_services.sql`
- `supabase/migrations/20251103_seed_prices.sql`

### Phase 2: API Endpoints Update 🔄
**Required Changes:**

1. **GET /api/pricelist/[category]** - List models in category
   - ✅ No changes needed (already category-filtered)

2. **GET /api/pricelist/[category]/[model]** - Services for specific model
   - ❌ Currently: Fetches ALL services
   - ✅ Update to: Fetch only category-specific services

   ```typescript
   // BEFORE (incorrect)
   const services = await supabase
     .from('services')
     .select('*');

   // AFTER (correct)
   const services = await supabase
     .from('category_services_view')
     .select('*')
     .eq('category_slug', categorySlug)
     .eq('is_active', true)
     .order('service_order');
   ```

3. **GET /api/services** - All services (admin)
   - ✅ No changes needed

4. **GET /api/services/by-category/[categorySlug]** - **NEW ENDPOINT**
   ```typescript
   // GET /api/services/by-category/iphone
   export async function GET(
     request: Request,
     { params }: { params: { categorySlug: string } }
   ) {
     const { data, error } = await supabase
       .from('category_services_view')
       .select('*')
       .eq('category_slug', params.categorySlug)
       .eq('is_active', true);

     return Response.json(data);
   }
   ```

**Files to Update:**
- `src/app/api/pricelist/[category]/[model]/route.ts`
- `src/app/api/services/by-category/[categorySlug]/route.ts` (new)

### Phase 3: UI Components Update 🔄
**Required Changes:**

1. **PricelistPage Component** (`src/app/pricelist/[category]/[model]/page.tsx`)
   ```typescript
   // Update service fetching logic
   const { data: services } = await supabase
     .from('category_services_view')
     .select(`
       service_id,
       service_slug,
       service_name_ru,
       service_name_en,
       service_name_cz
     `)
     .eq('category_slug', params.category)
     .eq('is_active', true);
   ```

2. **Admin Service Manager** (if exists)
   - Add UI to manage category-service relationships
   - Checkboxes to enable/disable services per category
   - Bulk actions for common operations

**Files to Update:**
- `src/app/pricelist/[category]/[model]/page.tsx`
- `src/components/pricelist/*` (service display components)
- `src/app/admin/services/*` (admin management, if exists)

### Phase 4: Admin Panel Enhancement 📊
**New Features:**

1. **Category-Service Matrix View**
   ```
   Service              | iPhone | iPad | MacBook | Watch
   ---------------------|--------|------|---------|-------
   Battery Replacement  |   ✓    |  ✓   |    ✓    |   ✓
   Display Replacement  |   ✓    |  ✓   |    ✓    |   ✓
   Keyboard Replacement |   ✗    |  ✗   |    ✓    |   ✗
   NFC Recovery         |   ✗    |  ✗   |    ✗    |   ✓
   ```

2. **Batch Operations**
   - Enable/disable service for multiple categories at once
   - Copy service pricing across similar models
   - Bulk import/export of category-service relationships

---

## Consequences

### Positive ✅
- **User Experience:** Users see only relevant services for their device
- **Data Quality:** Prevents incorrect price entries
- **Flexibility:** Easy to add new categories or services
- **Performance:** Indexed queries remain fast
- **Maintainability:** Clear data relationships

### Negative ⚠️
- **Migration Effort:** Need to update API endpoints and UI components
- **Initial Complexity:** Requires understanding of many-to-many relationships
- **Admin Overhead:** More configuration required when adding new services

### Neutral ℹ️
- **Database Size:** Minimal increase (one additional table)
- **Query Performance:** Negligible impact with proper indexes
- **Backward Compatibility:** Old queries will still work, but return incorrect data (need full migration)

---

## Validation and Testing

### Database Validation
```sql
-- Verify all categories have services
SELECT
  dc.name_en as category,
  COUNT(cs.id) as service_count
FROM device_categories dc
LEFT JOIN category_services cs ON dc.id = cs.category_id
GROUP BY dc.id, dc.name_en
ORDER BY dc."order";

-- Expected results:
-- iPhone: 8 services
-- iPad: 6 services
-- MacBook: 4 services
-- Apple Watch: 5 services
```

### API Testing
```bash
# Test category-specific services
curl http://localhost:3000/api/services/by-category/iphone
# Should return 8 iPhone services

curl http://localhost:3000/api/services/by-category/macbook
# Should return 4 MacBook services
```

### UI Testing Checklist
- [ ] iPhone pricelist shows only iPhone services
- [ ] iPad pricelist shows only iPad services
- [ ] MacBook pricelist shows only MacBook services
- [ ] Apple Watch pricelist shows only Watch services
- [ ] Admin panel can manage category-service relationships
- [ ] Prices display correctly for each service-model combination

---

## Migration Rollback Plan

If critical issues are discovered:

```sql
-- Rollback Step 1: Disable RLS on new table
ALTER TABLE category_services DISABLE ROW LEVEL SECURITY;

-- Rollback Step 2: Drop view
DROP VIEW IF EXISTS category_services_view;

-- Rollback Step 3: Drop table
DROP TABLE IF EXISTS category_services;

-- Rollback Step 4: Remove new services
DELETE FROM services WHERE created_at > '2025-11-03';
```

**Note:** Rollback should be avoided if possible. Instead, use `is_active = false` to temporarily disable problematic relationships.

---

## References

- [PostgreSQL Many-to-Many Relationships](https://www.postgresql.org/docs/current/tutorial-join.html)
- [Supabase Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)
- [Database Normalization Best Practices](https://en.wikipedia.org/wiki/Database_normalization)

---

## Approval

**Blueprint Architect:** ✅ Approved (2025-11-03)
**Implementation Engineer:** ⏳ Pending Review
**Quality Guardian:** ⏳ Pending Testing

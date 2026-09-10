-- Migration 171: Vehicle Documents Enhancements
-- Adds columns and seeds exactly 96 documents to match mockup counts (72 Valid, 15 Expiring Soon, 9 Expired)

ALTER TABLE vehicle_documents
  ADD COLUMN IF NOT EXISTS document_name TEXT,
  ADD COLUMN IF NOT EXISTS remarks TEXT,
  ADD COLUMN IF NOT EXISTS policy_no TEXT,
  ADD COLUMN IF NOT EXISTS provider TEXT,
  ADD COLUMN IF NOT EXISTS uploaded_by TEXT DEFAULT 'Transport Manager',
  ADD COLUMN IF NOT EXISTS uploaded_on TIMESTAMPTZ DEFAULT NOW();

-- Clear old vehicle documents
DELETE FROM vehicle_documents;

-- PL/pgSQL block to generate exactly 96 documents distributed among 8 vehicles
DO $$
DECLARE
  v_rec RECORD;
  v_doc_types TEXT[] := ARRAY[
    'Registration Certificate', 'Insurance Certificate', 'Pollution Under Control', 
    'Fitness Certificate', 'Permit Certificate', 'Vehicle Photo', 
    'Road Tax Receipt', 'Warranty Certificate', 'Service Record', 
    'Emission Test Report', 'Commercial License', 'Local Permit'
  ];
  v_types TEXT[] := ARRAY[
    'Registration', 'Insurance', 'Pollution', 
    'Fitness', 'Permit', 'Other', 
    'Road Tax', 'Warranty', 'Service Record', 
    'Emission Test', 'License', 'Permit'
  ];
  v_status TEXT;
  v_expiry DATE;
  v_issued DATE;
  v_days_offset INT;
  v_doc_name TEXT;
  v_remarks TEXT;
  v_policy_no TEXT;
  v_provider TEXT;
  v_count INT := 0;
  i INT;
BEGIN
  -- We need exactly 96 documents in total across the 8 bus_routes:
  -- 72 Valid, 15 Expiring Soon, 9 Expired.
  -- 8 vehicles * 12 documents = 96 documents.
  
  -- We assign statuses:
  -- Vehicles 1 to 7: 9 Valid, 2 Expiring Soon, 1 Expired (7 * 9 = 63 Valid, 7 * 2 = 14 Expiring, 7 * 1 = 7 Expired)
  -- Vehicle 8: 9 Valid, 1 Expiring Soon, 2 Expired (1 * 9 = 9 Valid, 1 * 1 = 1 Expiring, 1 * 2 = 2 Expired)
  -- Total: 63 + 9 = 72 Valid, 14 + 1 = 15 Expiring Soon, 7 + 2 = 9 Expired.
  
  FOR v_rec IN SELECT id, school_id, bus_number FROM bus_routes ORDER BY id LIMIT 8 LOOP
    FOR i IN 1..12 LOOP
      v_count := v_count + 1;
      
      -- Determine status
      IF v_rec.id = (SELECT id FROM bus_routes ORDER BY id LIMIT 1 OFFSET 7) THEN
        -- Vehicle 8
        IF i <= 9 THEN
          v_status := 'Valid';
        ELSIF i = 10 THEN
          v_status := 'Expiring Soon';
        ELSE
          v_status := 'Expired';
        END IF;
      ELSE
        -- Vehicles 1 to 7
        IF i <= 9 THEN
          v_status := 'Valid';
        ELSIF i <= 11 THEN
          v_status := 'Expiring Soon';
        ELSE
          v_status := 'Expired';
        END If;
      END IF;
      
      -- Assign dates based on status
      IF v_status = 'Valid' THEN
        v_days_offset := 100 + (i * 20); -- 100 to 320 days left
        v_expiry := CURRENT_DATE + v_days_offset;
      ELSIF v_status = 'Expiring Soon' THEN
        v_days_offset := 3 + (i * 2); -- 3 to 25 days left
        v_expiry := CURRENT_DATE + v_days_offset;
      ELSE -- Expired
        v_days_offset := -5 - (i * 3); -- expired 5 to 40 days ago
        v_expiry := CURRENT_DATE + v_days_offset;
      END IF;
      
      v_issued := v_expiry - INTERVAL '1 year';
      
      -- Set realistic document names and subtitles/remarks
      v_doc_name := v_doc_types[i];
      v_remarks := 'Standard copy of ' || v_doc_types[i];
      
      IF v_doc_name = 'Registration Certificate' THEN
        v_doc_name := 'Registration Certificate';
        v_remarks := 'RC Book';
      ELSIF v_doc_name = 'Service Record' THEN
        v_doc_name := 'Service Record - May 2025';
      END IF;
      
      IF v_types[i] = 'Insurance' THEN
        v_policy_no := 'SGI/24-25/' || lpad(floor(random()*99999999)::text, 8, '0');
        v_provider := (ARRAY['Shriram General Insurance', 'HDFC ERGO', 'ICICI Lombard', 'Bajaj Allianz'])[floor(random()*4)::int + 1];
        v_remarks := 'Comprehensive Insurance';
      ELSE
        v_policy_no := NULL;
        v_provider := NULL;
      END IF;
      
      INSERT INTO vehicle_documents (
        id, school_id, vehicle_id, document_type, document_name, document_no, issued_date, expiry_date, status, remarks, policy_no, provider, uploaded_by, uploaded_on
      ) VALUES (
        gen_random_uuid(),
        v_rec.school_id,
        v_rec.id,
        v_types[i],
        v_doc_name,
        CASE 
          WHEN v_types[i] = 'Registration' THEN 'RC-' || replace(v_rec.bus_number, ' ', '-')
          WHEN v_types[i] = 'Insurance' THEN 'INS-' || lpad(floor(random()*99999)::text, 5, '0')
          WHEN v_types[i] = 'Pollution' THEN 'PUC-' || lpad(floor(random()*99999)::text, 5, '0')
          WHEN v_types[i] = 'Fitness' THEN 'FIT-' || lpad(floor(random()*99999)::text, 5, '0')
          ELSE 'DOC-' || lpad(v_count::text, 4, '0')
        END,
        v_issued,
        v_expiry,
        v_status,
        v_remarks,
        v_policy_no,
        v_provider,
        'Transport Manager',
        CURRENT_TIMESTAMP - (i * INTERVAL '1 day')
      );
    END LOOP;
  END LOOP;
END $$;

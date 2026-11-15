-- ============================================================================
-- Migration: 496_comprehensive_energy_management_system.sql
-- Description: Smart Energy Meters, Tariffs, Utility Bills, Reports, and Multi-Tab Telemetry
-- ============================================================================

-- 1. Create Smart Energy Meters Table
CREATE TABLE IF NOT EXISTS public.campus_energy_meters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    meter_name VARCHAR(150) NOT NULL,
    meter_code VARCHAR(100) NOT NULL,
    meter_type VARCHAR(100) NOT NULL DEFAULT 'smart_meter', -- 'smart_meter', 'submeter', 'smart_plug', 'modbus_tcp', 'three_phase'
    protocol VARCHAR(50) NOT NULL DEFAULT 'mqtt',           -- 'mqtt', 'modbus_tcp', 'modbus_rtu', 'zigbee'
    mqtt_topic VARCHAR(250),
    modbus_slave_id INT DEFAULT 1,
    modbus_register_map JSONB DEFAULT '{}'::jsonb,
    ip_address VARCHAR(50),
    port INT DEFAULT 502,
    building_name VARCHAR(100) NOT NULL,
    floor_name VARCHAR(100),
    room_name VARCHAR(100),
    location_path VARCHAR(200) NOT NULL,
    parent_meter_id UUID,
    ct_ratio NUMERIC(8,2) DEFAULT 1.0,
    pt_ratio NUMERIC(8,2) DEFAULT 1.0,
    voltage NUMERIC(8,2) DEFAULT 230.0,
    current_amps NUMERIC(8,2) DEFAULT 0.0,
    active_power_watts NUMERIC(10,2) DEFAULT 0.0,
    power_factor NUMERIC(5,3) DEFAULT 0.95,
    frequency_hz NUMERIC(5,2) DEFAULT 50.0,
    total_import_kwh NUMERIC(12,2) DEFAULT 0.0,
    last_telemetry_at TIMESTAMPTZ DEFAULT now(),
    status VARCHAR(50) NOT NULL DEFAULT 'online', -- 'online', 'idle', 'offline', 'error'
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_campus_meter_code UNIQUE (school_id, meter_code)
);

CREATE INDEX IF NOT EXISTS idx_campus_energy_meters_school ON public.campus_energy_meters(school_id);
CREATE INDEX IF NOT EXISTS idx_campus_energy_meters_location ON public.campus_energy_meters(location_path);

-- 2. Create Campus Electricity Tariffs Table
CREATE TABLE IF NOT EXISTS public.campus_energy_tariffs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    provider_name VARCHAR(150) NOT NULL,
    tariff_name VARCHAR(150) NOT NULL,
    tariff_type VARCHAR(50) NOT NULL DEFAULT 'time_of_use', -- 'flat', 'time_of_use', 'slab'
    rate_per_kwh_standard NUMERIC(6,2) NOT NULL DEFAULT 12.0,
    rate_per_kwh_peak NUMERIC(6,2) NOT NULL DEFAULT 15.5,
    rate_per_kwh_off_peak NUMERIC(6,2) NOT NULL DEFAULT 8.5,
    peak_hours_start VARCHAR(10) DEFAULT '18:00',
    peak_hours_end VARCHAR(10) DEFAULT '22:00',
    fixed_charge_monthly NUMERIC(10,2) DEFAULT 5000.0,
    demand_charge_per_kw NUMERIC(6,2) DEFAULT 350.0,
    tax_pct NUMERIC(5,2) DEFAULT 18.0,
    effective_from DATE DEFAULT CURRENT_DATE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_energy_tariffs_school ON public.campus_energy_tariffs(school_id);

-- 3. Create Utility Bills Management Table
CREATE TABLE IF NOT EXISTS public.campus_utility_bills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    provider_name VARCHAR(150) NOT NULL,
    bill_number VARCHAR(100) NOT NULL,
    billing_period_start DATE NOT NULL,
    billing_period_end DATE NOT NULL,
    units_consumed_kwh NUMERIC(10,2) NOT NULL,
    amount_inr NUMERIC(10,2) NOT NULL,
    tax_inr NUMERIC(10,2) DEFAULT 0.0,
    fixed_charges_inr NUMERIC(10,2) DEFAULT 0.0,
    calculated_meter_kwh NUMERIC(10,2) NOT NULL,
    variance_pct NUMERIC(6,2) DEFAULT 0.0,
    due_date DATE NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'paid', -- 'paid', 'pending', 'disputed'
    invoice_url VARCHAR(250),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_utility_bill_number UNIQUE (school_id, bill_number)
);

CREATE INDEX IF NOT EXISTS idx_utility_bills_school ON public.campus_utility_bills(school_id, billing_period_end DESC);

-- 4. Create Campus Energy Reports Table
CREATE TABLE IF NOT EXISTS public.campus_energy_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    report_title VARCHAR(250) NOT NULL,
    template_type VARCHAR(100) NOT NULL,
    scope_type VARCHAR(50) NOT NULL DEFAULT 'campus',
    scope_id VARCHAR(150) DEFAULT 'All',
    date_from DATE NOT NULL,
    date_to DATE NOT NULL,
    file_format VARCHAR(20) NOT NULL DEFAULT 'pdf', -- 'pdf', 'excel', 'csv'
    file_size_kb INT DEFAULT 450,
    generated_by VARCHAR(100) NOT NULL DEFAULT 'Admin',
    status VARCHAR(50) NOT NULL DEFAULT 'completed',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_energy_reports_school ON public.campus_energy_reports(school_id, created_at DESC);

-- ============================================================================
-- Seed Canonical Data (School ID: 11111111-1111-1111-1111-111111111111)
-- ============================================================================

DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111'::UUID;
BEGIN
    -- 1. Seed Smart Meters
    INSERT INTO public.campus_energy_meters (
        school_id, meter_name, meter_code, meter_type, protocol, mqtt_topic, ip_address,
        building_name, floor_name, room_name, location_path, voltage, current_amps,
        active_power_watts, power_factor, frequency_hz, total_import_kwh, status
    ) VALUES
    (
        v_school_id, 'Main Substation 3-Phase Meter', 'MTR-SUB-01', 'three_phase', 'modbus_tcp',
        'energy/greenwood/substation/telemetry', '192.168.1.200', 'Administration Block', 'Ground Floor', 'Electrical Substation',
        'Administration Block > Substation', 415.2, 85.4, 35400.0, 0.97, 50.02, 148600.0, 'online'
    ),
    (
        v_school_id, 'Academic Block (A) Main Feeder', 'MTR-ACAD-01', 'submeter', 'mqtt',
        'energy/greenwood/acad_a/telemetry', '192.168.1.201', 'Academic Block (A)', 'Ground Floor', 'Main Panel',
        'Academic Block (A) > Main Panel', 231.4, 28.5, 6500.0, 0.96, 50.00, 43200.0, 'online'
    ),
    (
        v_school_id, 'Library Block Feeder Meter', 'MTR-LIB-01', 'submeter', 'mqtt',
        'energy/greenwood/library/telemetry', '192.168.1.202', 'Library Block', 'First Floor', 'Panel Room',
        'Library Block > Panel Room', 230.1, 14.2, 3200.0, 0.95, 49.98, 21800.0, 'online'
    ),
    (
        v_school_id, 'Laboratories Block Feeder Meter', 'MTR-LAB-01', 'submeter', 'modbus_tcp',
        'energy/greenwood/labs/telemetry', '192.168.1.203', 'Laboratories Block', 'Ground Floor', 'Lab Main Panel',
        'Laboratories Block > Lab Main Panel', 229.8, 16.8, 3850.0, 0.94, 50.01, 20200.0, 'online'
    ),
    (
        v_school_id, 'Administration Block Feeder Meter', 'MTR-ADMIN-01', 'submeter', 'mqtt',
        'energy/greenwood/admin/telemetry', '192.168.1.204', 'Administration Block', 'Ground Floor', 'Admin Switchboard',
        'Administration Block > Admin Switchboard', 230.5, 12.0, 2750.0, 0.96, 50.00, 16400.0, 'online'
    ),
    (
        v_school_id, 'Hostel Block Feeder Meter', 'MTR-HOSTEL-01', 'submeter', 'mqtt',
        'energy/greenwood/hostel/telemetry', '192.168.1.205', 'Hostel Block', 'Ground Floor', 'Hostel Utility Room',
        'Hostel Block > Utility Room', 231.0, 11.5, 2600.0, 0.95, 50.00, 15300.0, 'online'
    ),
    (
        v_school_id, 'Cafeteria & Dining Hall Meter', 'MTR-CAFE-01', 'smart_meter', 'mqtt',
        'energy/greenwood/cafe/telemetry', '192.168.1.206', 'Cafeteria', 'Ground Floor', 'Kitchen Power Board',
        'Cafeteria > Kitchen Power Board', 230.0, 9.4, 2150.0, 0.93, 49.99, 12100.0, 'online'
    ),
    (
        v_school_id, 'Server Room Smart PDU A', 'PDU-SRV-01', 'smart_plug', 'mqtt',
        'energy/greenwood/server/telemetry', '192.168.1.207', 'Administration Block', 'Second Floor', 'Server Room A',
        'Administration Block > Server Room A', 229.5, 18.2, 4100.0, 0.98, 50.00, 18450.0, 'online'
    )
    ON CONFLICT (school_id, meter_code) DO UPDATE SET
        voltage = EXCLUDED.voltage,
        active_power_watts = EXCLUDED.active_power_watts,
        updated_at = now();

    -- 2. Seed Electricity Tariffs
    DELETE FROM public.campus_energy_tariffs WHERE school_id = v_school_id;
    INSERT INTO public.campus_energy_tariffs (
        school_id, provider_name, tariff_name, tariff_type, rate_per_kwh_standard,
        rate_per_kwh_peak, rate_per_kwh_off_peak, peak_hours_start, peak_hours_end,
        fixed_charge_monthly, demand_charge_per_kw, tax_pct, is_active
    ) VALUES
    (
        v_school_id, 'State Electricity Board (BESCOM)', 'Commercial High-Tension (HT-2B)', 'time_of_use',
        12.00, 15.50, 8.50, '18:00', '22:00', 5000.00, 350.00, 18.00, true
    ),
    (
        v_school_id, 'Green Power Solar Wheeling', 'Solar Net Metering Tariff', 'flat',
        7.20, 7.20, 7.20, '00:00', '23:59', 0.00, 0.00, 5.00, false
    );

    -- 3. Seed Utility Bills
    DELETE FROM public.campus_utility_bills WHERE school_id = v_school_id;
    INSERT INTO public.campus_utility_bills (
        school_id, provider_name, bill_number, billing_period_start, billing_period_end,
        units_consumed_kwh, amount_inr, tax_inr, fixed_charges_inr, calculated_meter_kwh,
        variance_pct, due_date, status, notes
    ) VALUES
    (
        v_school_id, 'State Electricity Board (BESCOM)', 'BES-2024-12-8841', '2024-12-01', '2024-12-31',
        15200.0, 182400.0, 27823.7, 5000.0, 14860.0, -2.2, '2025-01-20', 'paid', 'Verified with main substation check meter'
    ),
    (
        v_school_id, 'State Electricity Board (BESCOM)', 'BES-2024-11-7392', '2024-11-01', '2024-11-30',
        16308.0, 195696.0, 29851.6, 5000.0, 16120.0, -1.1, '2024-12-20', 'paid', 'Winter baseline billing'
    ),
    (
        v_school_id, 'State Electricity Board (BESCOM)', 'BES-2024-10-6215', '2024-10-01', '2024-10-31',
        17450.0, 209400.0, 31943.4, 5000.0, 17290.0, -0.9, '2024-11-20', 'paid', 'Higher exam hall and event usage'
    ),
    (
        v_school_id, 'State Electricity Board (BESCOM)', 'BES-2025-01-9402', '2025-01-01', '2025-01-31',
        14650.0, 175800.0, 26816.9, 5000.0, 14860.0, 1.4, '2025-02-20', 'pending', 'Current billing cycle pending final settlement'
    );

    -- 4. Seed Energy Reports
    DELETE FROM public.campus_energy_reports WHERE school_id = v_school_id;
    INSERT INTO public.campus_energy_reports (
        school_id, report_title, template_type, scope_type, scope_id,
        date_from, date_to, file_format, file_size_kb, generated_by, status
    ) VALUES
    (
        v_school_id, 'Monthly Campus Energy Executive Summary', 'monthly_executive', 'campus', 'Greenwood High School',
        '2024-12-01', '2024-12-31', 'pdf', 540, 'King Doe (Admin)', 'completed'
    ),
    (
        v_school_id, 'Academic Block (A) Detailed Energy Audit', 'building_comparison', 'building', 'Academic Block (A)',
        '2024-12-10', '2025-01-10', 'excel', 320, 'King Doe (Admin)', 'completed'
    ),
    (
        v_school_id, 'Campus Carbon Footprint & Scope 2 Emissions', 'carbon_audit', 'campus', 'Greenwood High School',
        '2024-01-01', '2024-12-31', 'pdf', 890, 'King Doe (Admin)', 'completed'
    ),
    (
        v_school_id, 'Utility Bill Reconciliation & Tariff Variance', 'cost_reconciliation', 'campus', 'Greenwood High School',
        '2024-10-01', '2024-12-31', 'csv', 180, 'Finance Team', 'completed'
    ),
    (
        v_school_id, 'HVAC & Lighting Operational Efficiency Report', 'device_type_analysis', 'device_type', 'HVAC & Lighting',
        '2024-12-15', '2025-01-10', 'pdf', 410, 'Facility Manager', 'completed'
    );
END $$;

-- Database migration: 164_contact_us_configurations.sql
-- Add contact columns to system_configurations and set default values.

ALTER TABLE public.system_configurations
ADD COLUMN IF NOT EXISTS contact_email TEXT NOT NULL DEFAULT 'support@schoolerp.com',
ADD COLUMN IF NOT EXISTS contact_phone TEXT NOT NULL DEFAULT '+91 98765 43210',
ADD COLUMN IF NOT EXISTS contact_address TEXT NOT NULL DEFAULT 'School ERP Solutions Pvt. Ltd., Plot No. 123, Tech Park, Sector 62, Noida, Uttar Pradesh - 201309, India',
ADD COLUMN IF NOT EXISTS live_chat_info TEXT NOT NULL DEFAULT 'Available in the application';

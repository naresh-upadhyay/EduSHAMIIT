-- Migration 197: Add created_by and updated_by columns to vehicle_categories table

ALTER TABLE vehicle_categories
  ADD COLUMN IF NOT EXISTS created_by TEXT DEFAULT 'Transport Manager',
  ADD COLUMN IF NOT EXISTS updated_by TEXT DEFAULT 'Transport Manager';

UPDATE vehicle_categories
SET 
  created_by = COALESCE(created_by, 'Transport Manager'),
  updated_by = COALESCE(updated_by, 'Transport Manager'),
  created_at = COALESCE(created_at, NOW()),
  updated_at = COALESCE(updated_at, NOW());

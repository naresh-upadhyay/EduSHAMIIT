-- Migration: 093_storage_buckets.sql
-- Description: Creates the storage buckets required for avatars and document uploads.

INSERT INTO storage.buckets (id, name, public) 
VALUES 
    ('documents', 'documents', true), 
    ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

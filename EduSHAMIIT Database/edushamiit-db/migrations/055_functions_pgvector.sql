CREATE EXTENSION IF NOT EXISTS vector;
CREATE OR REPLACE FUNCTION search_knowledge_base(p_school_id UUID, p_query_embedding vector(1536), p_subject TEXT DEFAULT NULL, p_grade TEXT DEFAULT NULL, p_match_count INT DEFAULT 5) RETURNS TABLE (id UUID, content TEXT, source TEXT, metadata JSONB, similarity NUMERIC) AS $$
BEGIN RETURN QUERY SELECT kb.id, kb.content, kb.source, kb.metadata, 1 - (kb.embedding <=> p_query_embedding) AS similarity FROM knowledge_base kb WHERE kb.school_id = p_school_id AND (p_subject IS NULL OR kb.subject = p_subject) AND (p_grade IS NULL OR kb.grade = p_grade) ORDER BY kb.embedding <=> p_query_embedding LIMIT p_match_count; END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ingest_document_chunk(p_school_id UUID, p_subject TEXT, p_grade TEXT, p_source TEXT, p_content TEXT, p_embedding vector(1536), p_metadata JSONB DEFAULT '{}') RETURNS UUID AS $$
DECLARE v_id UUID; BEGIN INSERT INTO knowledge_base (school_id, subject, grade, source, content, embedding, metadata) VALUES (p_school_id, p_subject, p_grade, p_source, p_content, p_embedding, p_metadata) RETURNING id INTO v_id; RETURN v_id; END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bulk_ingest_documents(p_school_id UUID, p_subject TEXT, p_grade TEXT, p_source TEXT, p_chunks JSONB) RETURNS INT AS $$
DECLARE v_chunk JSONB; v_count INT := 0; BEGIN FOR v_chunk IN SELECT jsonb_array_elements(p_chunks) LOOP PERFORM ingest_document_chunk(p_school_id, p_subject, p_grade, p_source, v_chunk->>'content', (v_chunk->>'embedding')::vector(1536), COALESCE(v_chunk->'metadata', '{}'::jsonb)); v_count := v_count + 1; END LOOP; RETURN v_count; END; $$ LANGUAGE plpgsql;

-- ============================================================
-- Migration 098: Define match_documents for LangChain RAG
-- Required by: SupabaseVectorStore(query_name="match_documents")
-- ============================================================

CREATE OR REPLACE FUNCTION match_documents(
    query_embedding vector(1536),
    match_count     INT DEFAULT 5,
    filter          JSONB DEFAULT '{}'::JSONB
)
RETURNS TABLE (
    id         UUID,
    content    TEXT,
    metadata   JSONB,
    similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        kb.id,
        kb.content,
        kb.metadata,
        1 - (kb.embedding <=> query_embedding) AS similarity
    FROM knowledge_base kb
    WHERE (filter = '{}'::JSONB)
       OR (kb.metadata @> filter)
    ORDER BY kb.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

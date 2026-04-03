-- EduSHAMIIT Database Initialization
-- Enable pgvector extension for RAG embeddings
CREATE EXTENSION IF NOT EXISTS vector;

-- Knowledge base table for RAG pipeline
CREATE TABLE IF NOT EXISTS knowledge_base (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID NOT NULL,
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    embedding vector(1536),
    subject VARCHAR(100),
    grade VARCHAR(50),
    source VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for vector similarity search
CREATE INDEX IF NOT EXISTS idx_knowledge_base_embedding 
    ON knowledge_base USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

-- Create index for school_id filtering
CREATE INDEX IF NOT EXISTS idx_knowledge_base_school 
    ON knowledge_base(school_id);

-- Vector similarity search function
CREATE OR REPLACE FUNCTION match_documents(
    query_embedding vector(1536),
    match_count INT DEFAULT 5,
    filter JSONB DEFAULT '{}'
)
RETURNS TABLE (
    id UUID,
    content TEXT,
    metadata JSONB,
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
    WHERE 
        (filter->>'school_id' IS NULL OR kb.school_id::TEXT = filter->>'school_id')
        AND (filter->>'subject' IS NULL OR kb.subject = filter->>'subject')
        AND (filter->>'grade' IS NULL OR kb.grade = filter->>'grade')
    ORDER BY kb.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- IoT devices table
CREATE TABLE IF NOT EXISTS iot_devices (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID NOT NULL,
    room_id VARCHAR(100) NOT NULL,
    device_name VARCHAR(100),
    ip_address VARCHAR(45),
    status VARCHAR(20) DEFAULT 'offline',
    last_seen TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- IoT device states table
CREATE TABLE IF NOT EXISTS iot_device_states (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    device_id VARCHAR(100) NOT NULL,
    room_id VARCHAR(100) NOT NULL,
    fan VARCHAR(10) DEFAULT 'off',
    light1 VARCHAR(10) DEFAULT 'off',
    light2 VARCHAR(10) DEFAULT 'off',
    projector VARCHAR(10) DEFAULT 'off',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- IoT control log
CREATE TABLE IF NOT EXISTS iot_control_log (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID,
    room_id VARCHAR(100),
    device VARCHAR(50),
    action VARCHAR(20),
    triggered_by VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- IoT scheduled actions
CREATE TABLE IF NOT EXISTS iot_scheduled_actions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID NOT NULL,
    room_id VARCHAR(100),
    device VARCHAR(50),
    action VARCHAR(20),
    scheduled_time TIMESTAMPTZ,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- AI chat history
CREATE TABLE IF NOT EXISTS ai_chat_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID NOT NULL,
    user_id UUID NOT NULL,
    session_id VARCHAR(100),
    role VARCHAR(20) NOT NULL,
    content TEXT,
    tool_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_chat_session 
    ON ai_chat_history(session_id, created_at);
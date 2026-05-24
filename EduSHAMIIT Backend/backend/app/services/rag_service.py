"""
RAG (Retrieval-Augmented Generation) Service — Gemini-powered.
Uses text-embedding-004 (768-dim) padded with zeros to fill the
vector(1536) pgvector column. Cosine similarity is preserved
mathematically because the zero-padded components contribute zero
to the dot product while the L2 norms grow identically.
"""
import tempfile
import os
from typing import List

import httpx

GEMINI_API_KEY = os.getenv("GOOGLE_API_KEY", "AIza-placeholder-google-key")
_EMBED_URL = (
    "https://generativelanguage.googleapis.com/v1beta/models/"
    "text-embedding-004:embedContent?key=" + GEMINI_API_KEY
)

TARGET_DIM = 1536   # schema column: vector(1536)
NATIVE_DIM  = 768   # text-embedding-004 output


# ---------------------------------------------------------------------------
# Padded Google Embeddings — LangChain Embeddings-compatible
# ---------------------------------------------------------------------------

class PaddedGoogleEmbeddings:
    """
    Wraps Google text-embedding-004 (768-dim) and zero-pads each vector to
    TARGET_DIM (1536) so it fits the existing pgvector schema without
    a database migration.

    Implements the LangChain Embeddings interface:
      - embed_documents(texts) -> List[List[float]]
      - embed_query(text)      -> List[float]
    """

    def _embed_single(self, text: str) -> List[float]:
        """Synchronous single-document embedding via REST."""
        payload = {
            "model": "models/text-embedding-004",
            "content": {"parts": [{"text": text}]},
            "taskType": "RETRIEVAL_DOCUMENT",
        }
        resp = httpx.post(_EMBED_URL, json=payload, timeout=30.0)
        resp.raise_for_status()
        raw = resp.json()["embedding"]["values"]
        # Zero-pad: 768 native + 768 zeros = 1536
        return raw + [0.0] * (TARGET_DIM - len(raw))

    def _embed_query_single(self, text: str) -> List[float]:
        """Synchronous single-query embedding via REST (taskType = QUERY)."""
        payload = {
            "model": "models/text-embedding-004",
            "content": {"parts": [{"text": text}]},
            "taskType": "RETRIEVAL_QUERY",
        }
        resp = httpx.post(_EMBED_URL, json=payload, timeout=30.0)
        resp.raise_for_status()
        raw = resp.json()["embedding"]["values"]
        return raw + [0.0] * (TARGET_DIM - len(raw))

    def embed_documents(self, texts: List[str]) -> List[List[float]]:
        return [self._embed_single(t) for t in texts]

    def embed_query(self, text: str) -> List[float]:
        return self._embed_query_single(text)


# ---------------------------------------------------------------------------
# Ingest
# ---------------------------------------------------------------------------

async def ingest_document(
    pdf_bytes: bytes,
    school_id: str,
    subject: str,
    grade: str,
    source: str,
) -> int:
    """Load a PDF, chunk it, embed it via Gemini, store in Supabase pgvector."""
    try:
        from langchain_community.document_loaders import PyPDFLoader
        from langchain.text_splitter import RecursiveCharacterTextSplitter
        from langchain_community.vectorstores import SupabaseVectorStore
        from app.services.supabase_client import get_supabase

        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
            tmp.write(pdf_bytes)
            tmp_path = tmp.name

        try:
            loader = PyPDFLoader(tmp_path)
            docs = loader.load()

            splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)
            chunks = splitter.split_documents(docs)

            for chunk in chunks:
                chunk.metadata.update({
                    "school_id": school_id,
                    "subject": subject,
                    "grade": grade,
                    "source": source,
                })

            embeddings = PaddedGoogleEmbeddings()
            vector_store = SupabaseVectorStore(
                client=get_supabase(),
                embedding=embeddings,
                table_name="knowledge_base",
                query_name="match_documents",
            )
            await vector_store.aadd_documents(chunks)
            return len(chunks)
        finally:
            os.unlink(tmp_path)

    except Exception as e:
        print(f"RAG ingestion error: {e}")
        return 0


# ---------------------------------------------------------------------------
# Search
# ---------------------------------------------------------------------------

async def search_knowledge_base(
    query: str,
    school_id: str,
    subject: str = "",
    grade: str = "",
    k: int = 5,
) -> list:
    """Search the knowledge base for relevant content using Gemini embeddings."""
    try:
        from langchain_community.vectorstores import SupabaseVectorStore
        from app.services.supabase_client import get_supabase

        filter_dict: dict = {"school_id": school_id}
        if subject:
            filter_dict["subject"] = subject
        if grade:
            filter_dict["grade"] = grade

        embeddings = PaddedGoogleEmbeddings()
        vector_store = SupabaseVectorStore(
            client=get_supabase(),
            embedding=embeddings,
            table_name="knowledge_base",
            query_name="match_documents",
        )
        docs = vector_store.similarity_search(query, k=k, filter=filter_dict)
        return docs
    except Exception as e:
        print(f"RAG search error: {e}")
        return []
import tempfile
import os
from typing import List


async def ingest_document(
    pdf_bytes: bytes,
    school_id: str,
    subject: str,
    grade: str,
    source: str,
) -> int:
    """Load a PDF, chunk it, embed it, and store in Supabase pgvector."""
    try:
        from langchain_community.document_loaders import PyPDFLoader
        from langchain.text_splitter import RecursiveCharacterTextSplitter
        from langchain_openai import OpenAIEmbeddings
        from langchain_community.vectorstores import SupabaseVectorStore
        from app.services.supabase_client import get_supabase

        # Save bytes to temp file
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

            embeddings = OpenAIEmbeddings(
                model="text-embedding-3-small",
                openai_api_key=os.getenv("OPENAI_API_KEY", "sk-placeholder-openai-key")
            )
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


async def search_knowledge_base(
    query: str,
    school_id: str,
    subject: str = "",
    grade: str = "",
    k: int = 5,
) -> list:
    """Search the knowledge base for relevant content."""
    try:
        from langchain_openai import OpenAIEmbeddings
        from langchain_community.vectorstores import SupabaseVectorStore
        from app.services.supabase_client import get_supabase

        filter_dict = {"school_id": school_id}
        if subject:
            filter_dict["subject"] = subject
        if grade:
            filter_dict["grade"] = grade

        embeddings = OpenAIEmbeddings(
            model="text-embedding-3-small",
            openai_api_key=os.getenv("OPENAI_API_KEY", "sk-placeholder-openai-key")
        )
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
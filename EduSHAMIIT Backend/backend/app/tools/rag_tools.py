import os
from langchain_core.tools import tool


def get_rag_tools(school_id: str) -> list:
    """Return RAG search tools scoped to this school."""

    @tool
    def search_curriculum(query: str, subject: str = "", grade: str = "", k: int = 5) -> str:
        """
        Search the school's curriculum, textbooks, past papers, and study materials
        to find relevant content for answering academic questions.
        Use this tool FIRST for any academic question before generating an answer.
        Args:
            query: the student's question in natural language
            subject: optional filter (e.g. 'Mathematics', 'Physics')
            grade: optional filter (e.g. 'Class 10', 'Class 12')
            k: number of results to return (default 5)
        """
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
            if not docs:
                return "No relevant curriculum content found. Answering from general knowledge."

            context = "\n\n---\n\n".join([
                f"[Source: {d.metadata.get('source', 'Unknown')}]\n{d.page_content}"
                for d in docs
            ])
            return context
        except Exception as e:
            return f"Search error: {str(e)}"

    @tool
    def get_school_info() -> str:
        """Get general information about the school.
        Use when a guest or prospective parent asks about the school, facilities, admission process, or general info."""
        sb = get_supabase()
        try:
            school = sb.table("schools").select("*").eq("id", school_id).single().execute().data
            if not school:
                return "Welcome to EduSHAMIIT! For more information about our school, please visit our website or contact the admissions office."

            buf = [f"🏫 {school.get('name', 'EduSHAMIIT Academy')}:"]
            buf.append(f"  📍 Address: {school.get('address', 'Contact office for details')}")
            buf.append(f"  📞 Phone: {school.get('phone', 'N/A')}")
            buf.append(f"  📧 Email: {school.get('email', 'N/A')}")
            buf.append(f"  🌐 Website: {school.get('website', 'N/A')}")
            buf.append("")
            buf.append(f"  📋 Classes: {school.get('classes_offered', 'Nursery to Class 12')}")
            buf.append(f"  👨‍🏫 Total Teachers: {school.get('total_teachers', 'N/A')}")
            buf.append(f"  👨‍🎓 Total Students: {school.get('total_students', 'N/A')}")
            buf.append("")
            buf.append("📝 Admission Process:")
            buf.append("  1. Visit the school or apply online")
            buf.append("  2. Submit required documents")
            buf.append("  3. Entrance test (if applicable)")
            buf.append("  4. Interview with principal")
            buf.append("  5. Fee payment and enrollment")

            return "\n".join(buf)
        except Exception:
            return "Welcome to EduSHAMIIT! For more information about our school, facilities, and admission process, please contact our admissions office."

    return [search_curriculum, get_school_info]

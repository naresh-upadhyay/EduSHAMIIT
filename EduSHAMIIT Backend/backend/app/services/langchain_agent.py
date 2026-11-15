import json
import uuid
import re
import ast
from typing import AsyncGenerator, Optional, Any
from datetime import datetime

from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_core.messages import AIMessage, HumanMessage

from app.services.supabase_client import get_supabase
from app.middleware.auth import set_current_user_context
from app.agents.router import TaskType, detect_task, get_llm
from app.agents.prompts import get_system_prompt


def is_greeting_text(text: str) -> bool:
    """Check if the text is a non-substantive greeting or trivial greeting."""
    if not text:
        return True
    clean = re.sub(r"[#*_`\n\r.,!?:;\-]", " ", text).strip().lower()
    greetings = {
        "hi", "hello", "hey", "hii", "hiii", "namaste", "good morning", 
        "good afternoon", "good evening", "greetings", "yo", "heya", "help", "test"
    }
    return clean in greetings or len(clean) < 3


def generate_smart_title(content: str) -> str:
    """Generate a concise, professional 3-5 word executive title from user prompt."""
    if not content:
        return "General Consultation"
    clean = re.sub(r"[#*_`\n\r]", " ", content).strip()
    clean = re.sub(r"\s+", " ", clean)
    lower = clean.lower()

    if is_greeting_text(content):
        return "General Consultation"

    for prefix in [
        "can you please ", "please ", "show me the ", "show me ", "tell me about ", "tell me ",
        "what is the ", "what is ", "generate a ", "generate ", "give me the ", "give me ",
        "draft a ", "draft ", "create a ", "create ", "how many ", "where is ", "find ", "list ",
        "compare ", "summarize ", "explain ", "check ", "display ", "get ", "view ", "which "
    ]:
        if lower.startswith(prefix):
            clean = clean[len(prefix):].strip()
            lower = clean.lower()
            break

    words = clean.split()
    if not words:
        return "General Consultation"

    title_words = words[:5]
    title = " ".join(title_words).strip(".,!?:; -")
    title = title.title()
    if len(title) > 36:
        title = title[:33] + "..."
    return title


def get_gemini_fallbacks(primary_model: str) -> list:
    """Return the list of top available free-tier Gemini models as fallbacks."""
    from langchain_google_genai import ChatGoogleGenerativeAI
    import os
    
    all_gemini = [
        "gemini-2.0-flash",
        "gemini-1.5-flash",
        "gemini-1.5-flash-8b",
        "gemini-2.5-flash",
        "gemini-1.5-pro"
    ]
    fallbacks = []
    
    google_key = (
        os.getenv("GEMINI_API_KEY") 
        or os.getenv("GOOGLE_API_KEY") 
        or ""
    ).strip().strip("'\"")

    if not google_key or google_key.startswith("AIza-placeholder"):
        return []
        
    for m in all_gemini:
        if m != primary_model:
            fallbacks.append(
                ChatGoogleGenerativeAI(
                    model=m,
                    temperature=0.3,
                    max_tokens=8192,
                    streaming=True,
                    google_api_key=google_key
                )
            )
    return fallbacks[:4]


def extract_text_tool_calls(text: str) -> list:
    calls = []
    if not text:
        return calls

    # 1. Match <tool_call>\s*(.*?)\s*</tool_call>
    for m in re.finditer(r'<tool_call>\s*(.*?)\s*</tool_call>', text, re.DOTALL):
        raw = m.group(1).strip()
        try:
            calls.append(json.loads(raw))
        except Exception:
            try:
                clean = re.sub(r'[\r\n]+', ' ', raw)
                calls.append(json.loads(clean))
            except Exception:
                pass

    # 2. Match ```json ... ``` with name/tool
    for m in re.finditer(r'```(?:json)?\s*(\{.*?\})\s*```', text, re.DOTALL):
        try:
            data = json.loads(m.group(1).strip())
            if "name" in data or "tool" in data:
                calls.append(data)
        except Exception:
            pass

    # 3. Match raw standalone JSON with 'name' and 'arguments' if not already found
    if not calls and ('"name":' in text or '"tool":' in text):
        for m in re.finditer(r'(\{(?:[^{}]|(?R))*\})', text, re.DOTALL):
            try:
                data = json.loads(m.group(1).strip())
                if ("name" in data or "tool" in data) and ("arguments" in data or "args" in data):
                    calls.append(data)
            except Exception:
                pass

    return calls


from langchain.agents.agent import MultiActionAgentOutputParser
from langchain.agents.output_parsers.tools import ToolAgentAction, parse_ai_message_to_tool_action
from langchain_core.outputs import ChatGeneration
from langchain_core.agents import AgentFinish


class HybridToolsAgentOutputParser(MultiActionAgentOutputParser):
    """Parses both native OpenAI tool_calls and text-based tool_call patterns (<tool_call>, ```json, etc)."""

    @property
    def _type(self) -> str:
        return "hybrid-tools-agent-output-parser"

    def parse_result(self, result: list, *, partial: bool = False):
        if not result or not isinstance(result[0], ChatGeneration):
            raise ValueError("This output parser only works on ChatGeneration output")
        message = result[0].message

        # 1. Native OpenAI / LangChain tool_calls
        if getattr(message, "tool_calls", None) or message.additional_kwargs.get("tool_calls"):
            return parse_ai_message_to_tool_action(message)

        # 2. Text-based tool call formats in message.content
        content = str(message.content or "")
        text_tool_calls = extract_text_tool_calls(content)
        if text_tool_calls:
            actions = []
            for tc in text_tool_calls:
                fn_name = tc.get("name") or tc.get("tool")
                if not fn_name:
                    continue
                args = tc.get("arguments") if "arguments" in tc else tc.get("args", {})
                if isinstance(args, str):
                    try:
                        args = json.loads(args)
                    except Exception:
                        args = {"query": args}
                elif not isinstance(args, dict):
                    args = {"input": str(args)}

                tc_id = "tc_" + str(uuid.uuid4())[:8]
                log = f"\nInvoking: `{fn_name}` with `{args}`\n\n"
                actions.append(
                    ToolAgentAction(
                        tool=fn_name,
                        tool_input=args,
                        log=log,
                        message_log=[message],
                        tool_call_id=tc_id,
                    )
                )
            if actions:
                return actions

        # 3. Final Answer: Strip any leftover <tool_call> tags
        clean_output = re.sub(r'<tool_call>.*?</tool_call>', '', content, flags=re.DOTALL).strip()
        if not clean_output:
            clean_output = content

        return AgentFinish(
            return_values={"output": clean_output}, log=clean_output
        )

    def parse(self, text: str):
        raise ValueError("Can only parse messages")

def build_agent(
    role: str,
    school_id: str,
    task_type: str = "qa",
    user_id: str = None,
    launched_from: str = None,
    force_openrouter: bool = False,
    preferred_model: str = None,
    primary_llm: Any = None,
    fallback_llms: list = None,
    query: str = ""
):
    """Build a role-scoped, task-appropriate LangChain agent with multi-provider fallbacks."""
    from langchain.agents import AgentExecutor
    from langchain.agents.format_scratchpad import format_to_tool_messages
    from langchain.agents.output_parsers import ToolsAgentOutputParser
    from langchain_core.runnables import RunnablePassthrough
    from app.tools import get_all_tools, filter_tools_by_role
    from app.agents.router import get_fallback_llms, get_llm

    if primary_llm is not None:
        llm = primary_llm
        fallbacks = fallback_llms or []
    else:
        llm = get_llm(task_type, force_openrouter=force_openrouter, preferred_model=preferred_model, user_id=user_id)
        fallbacks = get_fallback_llms(user_id=user_id)
        if not force_openrouter and "gemini" in str(type(llm)).lower():
            gemini_fallbacks = get_gemini_fallbacks(getattr(llm, "model", ""))
            fallbacks = gemini_fallbacks + fallbacks

    all_tools = get_all_tools(school_id)
    tools = filter_tools_by_role(all_tools, role, school_id, query=query)

    prompt = ChatPromptTemplate.from_messages([
        ("system", get_system_prompt(role, school_id, user_id, launched_from)),
        MessagesPlaceholder("chat_history"),
        ("human", "{input}\n\nCRITICAL REMINDER: If you are generating, exporting, downloading, or creating any document (PDF, Excel spreadsheet, CSV) or image, you MUST call the appropriate tool ('generate_document' or 'generate_image') first to create the file. NEVER output a download link or markdown link manually or write one you made up; you must only use the exact markdown link returned in the tool's execution result. If you output a link without executing the tool, the file will not exist on the server and the user will get a 404 error."),
        MessagesPlaceholder("agent_scratchpad"),
    ])

    # Bind tools to the primary model
    primary_with_tools = llm.bind_tools(tools)
    
    if fallbacks:
        fallbacks_with_tools = []
        for f in fallbacks:
            try:
                fallbacks_with_tools.append(f.bind_tools(tools))
            except Exception:
                pass
        if fallbacks_with_tools:
            model_with_tools = primary_with_tools.with_fallbacks(fallbacks_with_tools)
        else:
            model_with_tools = primary_with_tools
    else:
        model_with_tools = primary_with_tools

    # Construct the tool-calling agent custom pipeline
    agent = (
        RunnablePassthrough.assign(
            agent_scratchpad=lambda x: format_to_tool_messages(
                x["intermediate_steps"]
            )
        )
        | prompt
        | model_with_tools
        | HybridToolsAgentOutputParser()
    )

    return AgentExecutor(
        agent=agent,
        tools=tools,
        return_intermediate_steps=True,
        max_iterations=5,
        verbose=True,
    )


def load_history(session_id: str) -> list:
    """Load chat history from database."""
    try:
        sb = get_supabase()
        messages = sb.table("ai_chat_history") \
            .select("role, content, tool_calls") \
            .eq("session_id", session_id) \
            .order("created_at", ascending=False) \
            .limit(40).execute()

        history = []
        for msg in reversed(messages.data):
            if msg["role"] == "user":
                history.append(HumanMessage(content=msg["content"]))
            elif msg["role"] == "assistant":
                content = msg["content"]
                tool_calls = msg.get("tool_calls") or {}
                # Clean up hallucinated download links in history
                if "/api/chat/download/" in content and "generate_document" not in tool_calls:
                    content = re.sub(
                        r"\[Download [^\]]+\]\(/api/chat/download/[^\)]+\)", 
                        "(document download link available after generation)", 
                        content
                    )
                history.append(AIMessage(content=content))
        return history
    except Exception:
        return []


async def sync_conversation_on_message(
    session_id: str,
    user_id: str,
    school_id: str,
    user_text: str
) -> Optional[str]:
    """Ensure conversation record exists in ai_conversations and has an up-to-date smart title."""
    if not session_id or not user_id:
        return None
    try:
        sb = get_supabase()
        res = await sb.table("ai_conversations").select("id, title").eq("id", session_id).limit(1).aexecute()
        rows = res.data or []
        is_greeting = is_greeting_text(user_text)

        generic_titles = {
            "new chat", "untitled", "fee collection report", 
            "new conversation", "hi", "hello", "hey", "conversation", 
            "general inquiry", "general consultation"
        }

        if rows:
            current_title = rows[0].get("title", "")
            # If current title is generic and current prompt is substantive, upgrade it!
            if not is_greeting and (not current_title or current_title.lower() in generic_titles):
                new_title = generate_smart_title(user_text)
                await sb.table("ai_conversations").update({
                    "title": new_title,
                    "updated_at": datetime.utcnow().isoformat()
                }).eq("id", session_id).aexecute()
                return new_title
            else:
                await sb.table("ai_conversations").update({
                    "updated_at": datetime.utcnow().isoformat()
                }).eq("id", session_id).aexecute()
                return current_title
        else:
            # Create the conversation record immediately
            title = generate_smart_title(user_text)
            await sb.table("ai_conversations").insert({
                "id": session_id,
                "school_id": school_id,
                "user_id": user_id,
                "title": title,
                "context_module": "general",
                "is_pinned": False,
                "is_archived": False,
                "created_at": datetime.utcnow().isoformat(),
                "updated_at": datetime.utcnow().isoformat()
            }).aexecute()
            return title
    except Exception as e:
        print(f"[sync_conversation_on_message] Error: {e}")
        return None


async def save_message(session_id: str, user_id: str, role: str, content: str, school_id: str = "", tool_data: dict = None, attachment_url: str = None, attachment_type: str = None, attachment_name: str = None, thought_process: list = None):
    """Save a message to chat history and sync conversation metadata."""
    try:
        sb = get_supabase()
        msg_id = str(uuid.uuid4())
        msg_payload = {
            "id": msg_id,
            "school_id": school_id,
            "user_id": user_id,
            "session_id": session_id,
            "role": role,
            "content": content,
            "tool_calls": tool_data,
        }
        if attachment_url:
            msg_payload["attachment_url"] = attachment_url
        if attachment_type:
            msg_payload["attachment_type"] = attachment_type
        if attachment_name:
            msg_payload["attachment_name"] = attachment_name
        if thought_process:
            msg_payload["thought_process"] = thought_process

        await sb.table("ai_chat_history").insert(msg_payload).aexecute()

        # Update updated_at, last_message, and last_message_at on ai_conversations
        if session_id and user_id:
            try:
                now_iso = datetime.utcnow().isoformat()
                snippet = (content or "").replace("\n", " ").strip()
                if len(snippet) > 80:
                    snippet = snippet[:77] + "..."
                await sb.table("ai_conversations").update({
                    "updated_at": now_iso,
                    "last_message": snippet,
                    "last_message_at": now_iso,
                }).eq("id", session_id).aexecute()
            except Exception:
                pass
    except Exception as e:
        print(f"Save message error: {e}")


def extract_tool_results(result: dict) -> dict:
    """Extract tool results from agent output."""
    tool_data = {}
    steps = result.get("intermediate_steps", [])
    for step in steps:
        if len(step) >= 2:
            action = step[0]
            observation = step[1]
            tool_name = getattr(action, "tool", "unknown")
            tool_data[tool_name] = str(observation)[:500]
    return tool_data


def extract_document_text(doc_bytes: bytes, filename: str) -> str:
    """Extract text content from various document types (PDF, XLSX, CSV, TXT, DOCX)."""
    ext = filename.split(".")[-1].lower()
    
    if ext == "pdf":
        try:
            import io
            from pypdf import PdfReader
            reader = PdfReader(io.BytesIO(doc_bytes))
            text_parts = []
            for idx, page in enumerate(reader.pages):
                text_parts.append(f"--- Page {idx + 1} ---")
                text_parts.append(page.extract_text() or "")
            return "\n".join(text_parts)
        except Exception as e:
            return f"[Error parsing PDF: {str(e)}]"
            
    elif ext in ["xlsx", "xls"]:
        try:
            import io
            import openpyxl
            wb = openpyxl.load_workbook(io.BytesIO(doc_bytes), read_only=True, data_only=True)
            text_parts = []
            for sheet in wb.sheetnames:
                text_parts.append(f"--- Sheet: {sheet} ---")
                ws = wb[sheet]
                for row in ws.iter_rows(values_only=True):
                    if any(row):
                        text_parts.append(", ".join(str(cell) if cell is not None else "" for cell in row))
            return "\n".join(text_parts)
        except Exception as e:
            return f"[Error parsing Excel: {str(e)}]"
            
    elif ext == "csv":
        try:
            return doc_bytes.decode("utf-8", errors="ignore")
        except Exception as e:
            return f"[Error parsing CSV: {str(e)}]"
            
    elif ext in ["docx", "doc"]:
        try:
            import io
            import zipfile
            import xml.etree.ElementTree as ET
            
            with zipfile.ZipFile(io.BytesIO(doc_bytes)) as docx:
                content_xml = docx.read('word/document.xml')
                root = ET.fromstring(content_xml)
                ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
                paragraphs = []
                for p in root.findall('.//w:p', ns):
                    texts = [t.text for t in p.findall('.//w:t', ns) if t.text]
                    if texts:
                        paragraphs.append("".join(texts))
                return "\n".join(paragraphs)
        except Exception as e:
            try:
                return doc_bytes.decode("utf-8", errors="ignore")
            except Exception:
                return f"[Error parsing Word document: {str(e)}]"
                
    else:
        try:
            return doc_bytes.decode("utf-8", errors="ignore")
        except Exception as e:
            return f"[Unsupported document format: {ext}]"


async def process_message(
    text: str = "",
    image_b64: str = None,
    audio_path: str = None,
    doc_b64: str = None,
    doc_name: str = None,
    user: dict = None,
    session_id: str = "",
    school_id: str = "",
    launched_from: str = None,
) -> AsyncGenerator[dict, None]:
    """Single entry point for all message types. Yields SSE chunks."""

    # Set user context for tools
    if user:
        set_current_user_context(user)

    # Step 1: Transcribe voice if provided
    if audio_path:
        from app.services.whisper_service import transcribe_file
        text = await transcribe_file(audio_path)
        yield {"type": "text", "content": f"🎤 I heard: {text}\n\n"}

    # Step 2: Handle image directly (skip agent for pure vision tasks)
    if image_b64:
        from app.services.vision_service import analyze_image
        result = await analyze_image(image_b64, text, user_id=user_id)
        
        # Persist messages in database history
        user_id = user.get("id", "") if user else ""
        user_content = text if text else "Describe this image"
        await save_message(session_id, user_id, "user", f"📷 [Image] {user_content}", school_id)
        await save_message(session_id, user_id, "assistant", result, school_id)
        
        yield {"type": "text", "content": result}
        yield {"type": "scratchpad", "session_id": session_id, "stage": "done", "title": "Complete", "detail": "Finished response generation."}
        yield {"type": "done", "session_id": session_id}
        return

    # Step 2.5: Handle document processing if provided
    original_user_text = text
    if doc_b64 and doc_name:
        import base64
        try:
            doc_bytes = base64.b64decode(doc_b64)
            extracted_text = extract_document_text(doc_bytes, doc_name)
            text = f"[Document Attached: {doc_name}]\n---\n{extracted_text}\n---\n\nUser Question: {original_user_text}"
        except Exception as de:
            text = f"[Error decoding document {doc_name}: {str(de)}]\n\nUser Question: {original_user_text}"

    if not text:
        yield {"type": "text", "content": "Please send a message, voice note, or document."}
        yield {"type": "scratchpad", "session_id": session_id, "stage": "done", "title": "Complete", "detail": "Finished response generation."}
        yield {"type": "done", "session_id": session_id}
        return

    # Step 3: Automatically ensure conversation exists, generate smart title and notify client
    user_id = user.get("id", "") if user else ""
    role = user.get("role", "student") if user else "student"
    active_title = await sync_conversation_on_message(
        session_id=session_id,
        user_id=user_id,
        school_id=school_id,
        user_text=original_user_text or text
    )
    if active_title:
        yield {"type": "conversation_updated", "title": active_title, "session_id": session_id}

    # Step 4: Detect task type and prepare execution
    task = detect_task(text)
    history = load_history(session_id)

    accumulated_text = ""
    active_tools = {}
    completed_tools = []
    execution_success = False

    # Multi-Provider Resilient Execution:
    # Sequence: 1. Groq (Primary) -> 2. Gemini -> 3. Cloudflare -> 4. OpenRouter
    from app.agents.router import get_candidate_chain
    candidates = get_candidate_chain(user_id=user_id)
    initial_provider = candidates[0]["provider"].title() if candidates else "Groq"

    yield {
        "type": "scratchpad",
        "session_id": session_id,
        "stage": "thinking",
        "title": "Brainstorming & Planning...",
        "detail": f"Analyzing query and selecting optimal capabilities with {initial_provider}."
    }

    token_streamed = False

    for idx, cand in enumerate(candidates):
        if execution_success:
            break
        provider_name = cand["provider"]
        model_name = cand["model"]
        current_llm = cand["llm"]
        fallback_llms = [c["llm"] for c in candidates if c != cand]

        try:
            if idx > 0:
                print(f"[AI Fallback] Engaging {provider_name} ({model_name}) fallback for user {user_id}...")
                yield {
                    "type": "scratchpad",
                    "session_id": session_id,
                    "stage": "fallback",
                    "title": f"Switching to {provider_name.title()} Fallback",
                    "detail": f"Engaging model: {model_name}."
                }
                yield {"type": "text", "session_id": session_id, "content": f"⚡ *[Switching to {provider_name} Fallback: {model_name}...]*\n\n"}
                accumulated_text = ""
                active_tools = {}
                completed_tools = []

            agent = build_agent(
                role, school_id, task,
                user_id=user_id,
                launched_from=launched_from,
                primary_llm=current_llm,
                fallback_llms=fallback_llms,
                query=text
            )

            async for event in agent.astream_events(
                {"input": text, "chat_history": history},
                version="v2"
            ):
                kind = event["event"]
                name = event["name"]

                if kind == "on_chat_model_stream":
                    data_dict = event.get("data") or {}
                    chunk = data_dict.get("chunk")
                    if chunk and hasattr(chunk, "content") and chunk.content:
                        token = chunk.content
                        accumulated_text += token

                        # Suppress raw tool call tags from streaming to user
                        if "<tool_call" in accumulated_text and "</tool_call>" not in accumulated_text:
                            continue
                        elif "</tool_call>" in token or "<tool_call>" in token:
                            continue
                        elif '"name":' in token and ('"get_' in token or '"generate_' in token):
                            continue

                        clean_token = re.sub(r'<tool_call>.*?</tool_call>', '', token, flags=re.DOTALL)
                        if clean_token:
                            if not token_streamed:
                                token_streamed = True
                                yield {
                                    "type": "scratchpad",
                                    "session_id": session_id,
                                    "stage": "synthesizing",
                                    "title": "Synthesizing Response",
                                    "detail": "Formulating structured academic response."
                                }
                            yield {"type": "text", "session_id": session_id, "content": clean_token}

                elif kind == "on_tool_start":
                    data_dict = event.get("data") or {}
                    tool_input_val = data_dict.get("input")
                    print(f"DEBUG TOOL START: name={name} input={tool_input_val} type={type(tool_input_val)}")
                    active_tools[event["run_id"]] = (name, tool_input_val)
                    display_name = name.replace("_", " ").title()
                    
                    # Show scratchpad thinking / input preview for document generation
                    content_preview = ""
                    input_desc = ""
                    if isinstance(tool_input_val, dict):
                        if "prompt" in tool_input_val:
                            input_desc = f": {tool_input_val['prompt'][:60]}..."
                        elif "class_name" in tool_input_val:
                            input_desc = f" for Class {tool_input_val['class_name']}"
                        elif name == "generate_document":
                            doc_content = tool_input_val.get("content", "")
                            if doc_content:
                                clean_preview = doc_content.replace("#", "").replace("*", "").strip()
                                preview_text = clean_preview[:120] + "..." if len(clean_preview) > 120 else clean_preview
                                content_preview = f"\n> *Drafting Content: \"{preview_text}\"*\n"

                    yield {
                        "type": "scratchpad",
                        "session_id": session_id,
                        "stage": "tool_running",
                        "title": f"Executing: {display_name}",
                        "detail": f"Calling academic tool {display_name}{input_desc}."
                    }
                    
                    yield {"type": "text", "session_id": session_id, "content": f"\n\n⚙️ *[Executing: {display_name}...]*\n{content_preview}\n"}

                elif kind == "on_tool_end":
                    run_id = event["run_id"]
                    if run_id in active_tools:
                        tool_name, tool_input = active_tools.pop(run_id)
                        data_dict = event.get("data") or {}
                        tool_output = data_dict.get("output")
                        completed_tools.append((tool_name, tool_input, tool_output))
                        display_name = tool_name.replace("_", " ").title()
                        yield {
                            "type": "scratchpad",
                            "session_id": session_id,
                            "stage": "tool_done",
                            "title": f"Completed: {display_name}",
                            "detail": "Tool executed successfully. Processing results into final answer."
                        }
                        yield {"type": "text", "session_id": session_id, "content": f"\n*[Completed: {display_name}]* ✅\n\n"}
            if accumulated_text:
                execution_success = True

        except Exception as e:
            err_str = str(e)
            print(f"[Agent Execution Attempt] Provider={provider_name} Model={model_name} error: {err_str}")
            if idx < len(candidates) - 1:
                # Seamlessly continue to next candidate in priority chain
                continue
            else:
                import traceback
                traceback.print_exc()
                error_msg = f"I encountered an error: {str(e)}. Please try again."
                yield {"type": "text", "content": error_msg}
                break

    try:
        # Build final response text and tool results
        output = accumulated_text if accumulated_text else "I couldn't process that request."
        
        # Extract image generation result if present
        for tool_name, tool_input, tool_output in completed_tools:
            if tool_name == "generate_image":
                img_md = None
                if isinstance(tool_output, dict):
                    img_md = tool_output.get("markdown")
                elif isinstance(tool_output, str) and "![" in tool_output:
                    m_img = re.search(r"(!\[[^\]]*\]\([^\)]+\))", tool_output)
                    if m_img:
                        img_md = m_img.group(0)
                if img_md and img_md not in output:
                    output += f"\n\n{img_md}"

        # Strip any raw <tool_call> code tags from final output
        output = re.sub(r'<tool_call>.*?</tool_call>', '', output, flags=re.DOTALL).strip()

        # Check if generate_document tool was executed and extract result
        generated_doc = None
        for tool_name, tool_input, tool_output in completed_tools:
            if tool_name == "generate_document":
                download_url = None
                markdown_link = None
                if isinstance(tool_output, dict):
                    download_url = tool_output.get("download_url")
                    markdown_link = tool_output.get("markdown_link")
                elif isinstance(tool_output, str):
                    try:
                        parsed = ast.literal_eval(tool_output)
                        if isinstance(parsed, dict):
                            download_url = parsed.get("download_url")
                            markdown_link = parsed.get("markdown_link")
                    except Exception:
                        m_url = re.search(r"'/api/chat/download/[^']+'", tool_output)
                        if m_url:
                            download_url = m_url.group(0).strip("'")
                        m_link = re.search(r"(\[Download [^\]]+\]\(/api/chat/download/[^\)]+\))", tool_output)
                        if m_link:
                            markdown_link = m_link.group(0)
                
                if download_url and markdown_link:
                    generated_doc = (download_url, markdown_link)
                    break
        
        # Fallback / Auto-Generator:
        # If user asked for a document OR the LLM outputted a download link,
        # but generate_document wasn't executed or completed, generate the real file on-the-fly!
        if not generated_doc:
            user_lower = (original_user_text or text or "").lower()
            doc_keywords = [
                "pdf", "docx", "doc", "word document", "word doc",
                "excel", "xlsx", "xls", "spreadsheet", "csv",
                "ppt", "pptx", "powerpoint", "presentation", "slides",
                "create doc", "generate doc", "create file", "export file"
            ]
            doc_link_match = re.search(
                r"\[([^\]]*(?:Download|File|PDF|Doc|Word|Excel|Sheet|PPT|Presentation|Slides)[^\]*)\]\(([^\)]+)\)",
                output,
                re.IGNORECASE
            )
            generic_ext_match = re.search(
                r"\[([^\]]+\.(pdf|docx|xlsx|pptx|csv|txt))\]\(([^\)]+)\)",
                output,
                re.IGNORECASE
            )

            is_doc_requested = any(kw in user_lower for kw in doc_keywords)
            has_download_link = bool(doc_link_match or generic_ext_match)

            if is_doc_requested or has_download_link:
                try:
                    from app.tools.academic_tools import create_document_file
                    
                    link_text = (doc_link_match.group(1) if doc_link_match else (generic_ext_match.group(1) if generic_ext_match else "")).lower()
                    
                    if "docx" in link_text or "word" in link_text or "docx" in user_lower or "word" in user_lower:
                        target_type = "docx"
                    elif "pptx" in link_text or "ppt" in link_text or "powerpoint" in link_text or "slides" in user_lower or "pptx" in user_lower or "ppt" in user_lower:
                        target_type = "pptx"
                    elif "xlsx" in link_text or "excel" in link_text or "sheet" in link_text or "xlsx" in user_lower or "excel" in user_lower or "spreadsheet" in user_lower:
                        target_type = "xlsx"
                    elif "csv" in link_text or "csv" in user_lower:
                        target_type = "csv"
                    elif "txt" in link_text or "text" in user_lower or ("notes" in user_lower and "pdf" not in user_lower):
                        target_type = "txt"
                    else:
                        target_type = "pdf"
                    
                    target_filename = None
                    if generic_ext_match:
                        target_filename = generic_ext_match.group(1).strip()
                    elif doc_link_match:
                        raw_label = doc_link_match.group(1)
                        clean_label = re.sub(r'^[^\w\s]+', '', raw_label).strip()
                        clean_label = re.sub(r'^(?:Download|File)\s*:\s*', '', clean_label, flags=re.IGNORECASE).strip()
                        if clean_label:
                            target_filename = clean_label
                    
                    if not target_filename or len(target_filename) < 3:
                        h1_match = re.search(r'^#\s+([^\n]+)', output, re.MULTILINE)
                        if h1_match:
                            target_filename = h1_match.group(1).strip()
                        else:
                            clean_q = re.sub(r'[^\w\s]', '', original_user_text or text).strip()
                            words = [w for w in clean_q.split() if w.lower() not in ['create', 'generate', 'pdf', 'docx', 'doc', 'excel', 'ppt', 'for', 'a', 'an', 'the', 'please', 'could', 'you', 'me']]
                            target_filename = "_".join(words[:5]).title() if words else "Document"

                    target_filename = re.sub(r'[^\w\-_\.]', '_', target_filename)
                    if not target_filename.lower().endswith(f".{target_type}"):
                        target_filename = f"{target_filename}.{target_type}"
                    
                    clean_content = re.sub(r'\[([^\]]+)\]\((https?://[^\)]+|/api/chat/download/[^\)]+)\)', '', output).strip()
                    if not clean_content:
                        clean_content = output

                    # If data table is missing from conversational text, inject table from completed tools (e.g. get_pending_fee_students)
                    if ("|" not in clean_content) and target_type in ("xlsx", "csv", "docx"):
                        for t_name, t_in, t_out in completed_tools:
                            t_out_str = str(t_out)
                            if "|" in t_out_str:
                                clean_content += f"\n\n{t_out_str}"
                                break
                    
                    res = create_document_file(
                        doc_type=target_type,
                        filename=target_filename,
                        content=clean_content,
                        school_id=school_id
                    )
                    if res.get("success"):
                        d_url = res.get("download_url")
                        d_md = res.get("markdown_link")
                        if d_url and d_md:
                            generated_doc = (d_url, d_md)
                except Exception as doc_gen_err:
                    print(f"Auto-document generation fallback error: {doc_gen_err}")
        
        # Process and safeguard download links in the output text
        original_output = output
        any_download_pattern = r"\[([^\]]+)\]\((https?://[^\)]+|/api/chat/download/[^\)]+)\)"
        
        if generated_doc:
            download_url, markdown_link = generated_doc
            # Case 1: Document generated successfully. Replace all download links in output with real working link.
            def _replace_link(m):
                label = m.group(1)
                if "📄" not in label and "Download" in label:
                    label = f"📄 {label}"
                return f"[{label}]({download_url})"

            if re.search(any_download_pattern, output):
                output = re.sub(any_download_pattern, _replace_link, output)
            else:
                output += f"\n\nHere is your generated document: {markdown_link}"
        else:
            # Case 2: Document generation did not occur or failed.
            # Clean up all hallucinated download links to prevent 404 errors or external spam redirects.
            if re.search(any_download_pattern, output):
                def _scrub_fake(m):
                    url = m.group(2)
                    if any(url.lower().endswith(x) for x in ['.pdf', '.docx', '.xlsx', '.pptx', '.csv', '.txt']) or 'download' in m.group(1).lower() or 'files.' in url.lower():
                        return "(document generation unavailable - please request again)"
                    return m.group(0)
                output = re.sub(any_download_pattern, _scrub_fake, output)

        # Convert any bare ERP action lines like "• View Full Pending Fee List in ERP: /admin/student-fees" into clickable markdown links
        action_line_regex = r'(?m)^([\s*•\-\d\.]+\s*)([^:\n\[]+?):\s*`?(/admin/[a-zA-Z0-9_\-]+)`?\s*$'
        def _fmt_action_line(m):
            pfx = m.group(1) or ""
            lbl = m.group(2).strip()
            rte = m.group(3).strip()
            return f"{pfx}[{lbl}]({rte})"
        output = re.sub(action_line_regex, _fmt_action_line, output)
                
        # Send text update if modified to replace hallucinated text on the client
        if output != original_output:
            yield {"type": "replace_text", "content": output}

        tool_data = {}
        for tool_name, tool_input, tool_output in completed_tools:
            tool_data[tool_name] = str(tool_output)[:500]

        if tool_data:
            yield {"type": "tool_result", "data": tool_data}

        # Step 6: Save conversation
        user_id = user.get("id", "") if user else ""
        save_text = f"📄 [Document: {doc_name}] {original_user_text}" if doc_name else text
        await save_message(session_id, user_id, "user", save_text, school_id)
        await save_message(session_id, user_id, "assistant", output, school_id, tool_data)

    except Exception as e:
        import traceback
        traceback.print_exc()
        error_msg = f"I encountered an error: {str(e)}. Please try again."
        yield {"type": "text", "content": error_msg}

    yield {"type": "scratchpad", "session_id": session_id, "stage": "done", "title": "Complete", "detail": "Finished response generation."}
    yield {"type": "done", "session_id": session_id}
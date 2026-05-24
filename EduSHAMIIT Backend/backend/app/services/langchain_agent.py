import json
import uuid
from typing import AsyncGenerator, Optional, Any
from datetime import datetime

from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_core.messages import AIMessage, HumanMessage

from app.services.supabase_client import get_supabase
from app.middleware.auth import set_current_user_context
from app.agents.router import TaskType, detect_task, get_llm
from app.agents.prompts import get_system_prompt


def build_agent(role: str, school_id: str, task_type: str = "qa", user_id: str = None):
    """Build a role-scoped, task-appropriate LangChain agent with fallback LLMs."""
    from langchain.agents import AgentExecutor
    from langchain.agents.format_scratchpad import format_to_tool_messages
    from langchain.agents.output_parsers import ToolsAgentOutputParser
    from langchain_core.runnables import RunnablePassthrough
    from app.tools import get_all_tools, filter_tools_by_role
    from app.agents.router import get_fallback_llms

    llm = get_llm(task_type)
    all_tools = get_all_tools(school_id)
    tools = filter_tools_by_role(all_tools, role, school_id)

    prompt = ChatPromptTemplate.from_messages([
        ("system", get_system_prompt(role, school_id, user_id)),
        MessagesPlaceholder("chat_history"),
        ("human", "{input}"),
        MessagesPlaceholder("agent_scratchpad"),
    ])

    # Bind tools to the primary model
    primary_with_tools = llm.bind_tools(tools)

    # Fetch fallbacks (OpenRouter & GitHub Models) and bind tools to them individually
    fallbacks = get_fallback_llms()
    if fallbacks:
        fallbacks_with_tools = [f.bind_tools(tools) for f in fallbacks]
        model_with_tools = primary_with_tools.with_fallbacks(fallbacks_with_tools)
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
        | ToolsAgentOutputParser()
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
            .select("role, content") \
            .eq("session_id", session_id) \
            .order("created_at") \
            .limit(20).execute()

        history = []
        for msg in messages.data:
            if msg["role"] == "user":
                history.append(HumanMessage(content=msg["content"]))
            elif msg["role"] == "assistant":
                history.append(AIMessage(content=msg["content"]))
        return history
    except Exception:
        return []


async def save_message(session_id: str, user_id: str, role: str, content: str, school_id: str = "", tool_data: dict = None):
    """Save a message to chat history."""
    try:
        sb = get_supabase()
        sb.table("ai_chat_history").insert({
            "school_id": school_id,
            "user_id": user_id,
            "session_id": session_id,
            "role": role,
            "content": content,
            "tool_calls": tool_data,
        }).execute()
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


async def process_message(
    text: str = "",
    image_b64: str = None,
    audio_path: str = None,
    user: dict = None,
    session_id: str = "",
    school_id: str = "",
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
        result = await analyze_image(image_b64, text)
        yield {"type": "text", "content": result}
        yield {"type": "done"}
        return

    if not text:
        yield {"type": "text", "content": "Please send a message, voice note, or image."}
        yield {"type": "done"}
        return

    # Step 3: Detect task type and build agent
    task = detect_task(text)
    role = user.get("role", "student") if user else "student"

    try:
        agent = build_agent(role, school_id, task, user_id=user.get("id") if user else None)
        history = load_history(session_id)

        # Step 4: Run agent
        result = await agent.ainvoke({
            "input": text,
            "chat_history": history,
        })

        # Step 5: Yield response
        output = result.get("output", "I couldn't process that request.")
        tool_data = extract_tool_results(result)

        # Stream the response
        yield {"type": "text", "content": output}

        if tool_data:
            yield {"type": "tool_result", "data": tool_data}

        # Step 6: Save conversation
        user_id = user.get("id", "") if user else ""
        await save_message(session_id, user_id, "user", text, school_id)
        await save_message(session_id, user_id, "assistant", output, school_id, tool_data)

    except Exception as e:
        error_msg = f"I encountered an error: {str(e)}. Please try again."
        yield {"type": "text", "content": error_msg}

    yield {"type": "done"}
import os
import django
import asyncio
from dotenv import load_dotenv

# Load env variables
load_dotenv()

from app.services.langchain_agent import build_agent

async def test():
    # Build agent without fallbacks to see traceback
    from langchain_google_genai import ChatGoogleGenerativeAI
    from app.tools import get_all_tools, filter_tools_by_role
    
    role = "student"
    school_id = "11111111-1111-1111-1111-111111111111"
    
    llm = ChatGoogleGenerativeAI(
        model=os.getenv("GEMINI_MODEL", "gemini-1.5-flash"),
        temperature=0.3,
        max_tokens=8192,
        google_api_key=os.getenv("GOOGLE_API_KEY")
    )
    all_tools = get_all_tools(school_id)
    tools = filter_tools_by_role(all_tools, role, school_id)
    
    from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
    from langchain.agents import AgentExecutor
    from langchain.agents.format_scratchpad import format_to_tool_messages
    from langchain.agents.output_parsers import ToolsAgentOutputParser
    from langchain_core.runnables import RunnablePassthrough
    from app.agents.prompts import get_system_prompt

    prompt = ChatPromptTemplate.from_messages([
        ("system", get_system_prompt(role, school_id)),
        MessagesPlaceholder("chat_history"),
        ("human", "{input}"),
        ("system", "CRITICAL REMINDER: If the user is asking to generate, download, or export any document (PDF, Excel, CSV) or image, you MUST call the appropriate tool ('generate_document' or 'generate_image') first to create the file. NEVER output a download link manually."),
        MessagesPlaceholder("agent_scratchpad"),
    ])

    model_with_tools = llm.bind_tools(tools)
    agent = (
        RunnablePassthrough.assign(
            agent_scratchpad=lambda x: format_to_tool_messages(x["intermediate_steps"])
        )
        | prompt
        | model_with_tools
        | ToolsAgentOutputParser()
    )
    
    executor = AgentExecutor(
        agent=agent,
        tools=tools,
        verbose=True
    )
    
    try:
        print("Invoking agent directly...")
        res = await executor.ainvoke({
            "input": "Please generate a PDF summary of physical chemistry concepts.",
            "chat_history": []
        })
        print("Result:", res)
    except Exception as e:
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test())

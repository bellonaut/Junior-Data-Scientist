from __future__ import annotations

import os
from functools import lru_cache
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlmodel import Session
from sentence_transformers import SentenceTransformer

from carms.api.schemas import SemanticHit, SemanticQueryRequest, SemanticQueryResponse
from carms.core.database import get_session

router = APIRouter(prefix="/semantic", tags=["semantic"])


@lru_cache(maxsize=1)
def _get_model() -> SentenceTransformer:
    return SentenceTransformer("all-MiniLM-L6-v2")


def _maybe_generate_answer(question: str, hits: List[SemanticHit]) -> Optional[str]:
    """
    Optional LangChain-backed summarization when OPENAI_API_KEY is present.
    Falls back to None when no key or library issues occur.
    """
    if not hits:
        return None

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return None

    try:
        from langchain.chains.combine_documents import create_stuff_documents_chain
        from langchain.prompts import ChatPromptTemplate
        from langchain.schema import Document
        from langchain_openai import ChatOpenAI
    except Exception:
        return None

    llm = ChatOpenAI(api_key=api_key, model="gpt-4o-mini", temperature=0)
    prompt = ChatPromptTemplate.from_template(
        "Use the program snippets to answer the question. "
        "Keep answers grounded and cite program_stream_id when useful.\n\n"
        "Question: {question}\n\nSnippets:\n{context}"
    )
    chain = create_stuff_documents_chain(llm=llm, prompt=prompt)
    docs = [
        Document(
            page_content=hit.description_snippet or "",
            metadata={
                "program_stream_id": hit.program_stream_id,
                "discipline_name": hit.discipline_name,
                "province": hit.province,
            },
        )
        for hit in hits
    ]

    try:
        return chain.invoke({"input_documents": docs, "question": question})
    except Exception:
        return None


@router.post("/query", response_model=SemanticQueryResponse)
def semantic_query(
    payload: SemanticQueryRequest,
    session: Session = Depends(get_session),
) -> SemanticQueryResponse:
    if payload.top_k < 1 or payload.top_k > 20:
        raise HTTPException(status_code=422, detail="top_k must be between 1 and 20")

    model = _get_model()
    query_embedding = model.encode(payload.query, normalize_embeddings=True).tolist()

    stmt = text(
        """
        SELECT
            program_stream_id,
            program_name,
            program_stream_name,
            discipline_name,
            province,
            description_text,
            1 - (embedding <=> (:query_embedding)::vector) AS similarity
        FROM gold_program_embedding
        WHERE (:province IS NULL OR province = :province)
          AND (:discipline IS NULL OR discipline_name ILIKE '%' || :discipline || '%')
        ORDER BY embedding <=> (:query_embedding)::vector
        LIMIT :top_k
        """
    )

    rows = session.exec(
        stmt,
        {
            "query_embedding": query_embedding,
            "province": payload.province,
            "discipline": payload.discipline,
            "top_k": payload.top_k,
        },
    ).mappings()

    hits: List[SemanticHit] = []
    for row in rows:
        text_val = row.get("description_text")
        snippet = text_val[:320] + "..." if text_val and len(text_val) > 320 else text_val
        hits.append(
            SemanticHit(
                program_stream_id=row["program_stream_id"],
                program_name=row["program_name"],
                program_stream_name=row["program_stream_name"],
                discipline_name=row["discipline_name"],
                province=row["province"],
                similarity=float(row["similarity"]),
                description_snippet=snippet,
            )
        )

    answer = _maybe_generate_answer(payload.query, hits)
    return SemanticQueryResponse(hits=hits, answer=answer, top_k=payload.top_k)

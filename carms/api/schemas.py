from typing import List, Optional

from pydantic import BaseModel


class ProgramListItem(BaseModel):
    program_stream_id: int
    program_name: str
    program_stream_name: str
    program_stream: str
    discipline_name: str
    school_name: str
    program_site: str
    program_url: Optional[str] = None
    province: str
    is_valid: bool

    # list-friendly
    description_preview: Optional[str] = None


class ProgramDetail(ProgramListItem):
    # detail view includes full text
    description_text: Optional[str] = None


class ProgramListResponse(BaseModel):
    items: List[ProgramListItem]
    limit: int
    offset: int
    total: Optional[int] = None


class SemanticQueryRequest(BaseModel):
    query: str
    province: Optional[str] = None
    discipline: Optional[str] = None
    top_k: int = 5


class SemanticHit(BaseModel):
    program_stream_id: int
    program_name: str
    program_stream_name: str
    discipline_name: str
    province: str
    similarity: float
    description_snippet: Optional[str] = None


class SemanticQueryResponse(BaseModel):
    hits: List[SemanticHit]
    answer: Optional[str] = None
    top_k: int

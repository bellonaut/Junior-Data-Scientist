from typing import List, Optional

import sqlalchemy as sa
from pgvector.sqlalchemy import Vector
from sqlmodel import Field, SQLModel


class GoldProgramProfile(SQLModel, table=True):
    __tablename__ = "gold_program_profile"
    program_stream_id: int = Field(primary_key=True)
    program_name: str
    program_stream_name: str
    program_stream: str
    discipline_name: str = Field(index=True)
    province: str = Field(default="UNKNOWN", index=True)
    school_name: str = Field(index=True)
    program_site: str
    program_url: Optional[str] = None
    description_text: Optional[str] = None
    is_valid: bool = True


class GoldGeoSummary(SQLModel, table=True):
    __tablename__ = "gold_geo_summary"
    province: str = Field(primary_key=True)
    discipline_name: str = Field(primary_key=True)
    program_count: int
    avg_quota: Optional[float] = None


class GoldProgramEmbedding(SQLModel, table=True):
    __tablename__ = "gold_program_embedding"

    program_stream_id: int = Field(primary_key=True)
    program_name: str
    program_stream_name: str
    discipline_name: str = Field(index=True)
    province: str = Field(index=True)
    description_text: Optional[str] = None
    # Store normalized embedding (384-dim for all-MiniLM-L6-v2) in pgvector.
    embedding: List[float] = Field(sa_column=sa.Column(Vector(384)))

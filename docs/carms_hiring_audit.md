# CaRMS Project Hiring Audit (Junior Data Scientist Target)

## Phase 1 — Executive Verdict

- **Would this project get an interview?** **Yes, likely first-round interview.**
- **Would this impress a Lead Data Scientist?** **Partially.** It shows initiative and architecture intent, but not enough production depth.
- **Seniority signal:** **Upper-junior / early-mid** for data platform foundations.
- **Strongest signal:** End-to-end thinking (Dagster assets, SQLModel entities, FastAPI services, Dockerized local stack).
- **Biggest red flag:** Data engineering correctness gaps (model/transform mismatch, lack of migrations/governance/index strategy) and duplicate code trees (`app/` and `carms/`) that suggest maintainability risk.
- **Final verdict:** **Interview-worthy (not strong hire-ready yet).**

## Phase 2 — Data Engineering Audit

### Data architecture

**Strengths**
- Bronze → Silver → Gold layering is explicit in both docs and code.
- Gold tables are purpose-driven (`gold_program_profile`, `gold_geo_summary`) and API-facing.

**Weaknesses**
- Missing explicit relational constraints (foreign keys, uniqueness contracts beyond PKs).
- No warehouse-style conformed dimensions/facts; currently shaped as operational convenience tables.
- `SilverProgram` quota extraction references `match_iteration_name`, but Bronze program model does not define that column, creating dead-path transformation logic.
- No partitioning or indexing strategy documented for growth.

**Verdict:** Better than scripting, but not yet warehouse-mature.

### ETL design

**Strengths**
- Dagster assets are modularized per layer.
- Reload behavior is deterministic via delete+reload semantics.

**Weaknesses**
- Idempotence achieved by full table truncation semantics (`delete(...)`) rather than upsert/incremental logic.
- No quality checks, source freshness checks, or asset checks.
- Limited observability: mostly simple logs and row counts.
- Lineage exists structurally, but no runtime metadata, run tags, asset checks, or failure classification.

### SQL quality

**Strengths**
- API filters and counting patterns are straightforward and readable.

**Weaknesses**
- No explicit indexing on filter-heavy fields (`province`, `discipline_name`, `school_name`).
- No complex SQL optimization patterns demonstrated.
- Reliance on ORM-generated queries with minimal query planning awareness.

### Data contracts

**Weaknesses**
- No schema versioning strategy in practice (Alembic scaffold present but unused).
- Assumptions are partially documented but not encoded as formal contracts/tests.
- No drift detection against source files.

### Migration mindset (Informatica → Python/Postgres)

**Assessment**
- Demonstrates directional capability: layered ETL, orchestration, API serving.
- Missing enterprise controls required for real migration programs: audit columns, reconciliation, SCD logic, contract tests, change management.

## Phase 3 — Platform Engineering Audit

### FastAPI layer

**Strengths**
- Useful routes: search/list/detail, disciplines, map data, pipeline trigger.
- Security basics included (optional API key + rate limit).

**Weaknesses**
- CORS is fully open.
- Route layer directly accesses ORM session with no repository/service abstraction.
- Pipeline trigger couples API runtime to Dagster GraphQL assumptions.

### SQLAlchemy/SQLModel usage

**Strengths**
- Basic dependency-injected session pattern is correct.

**Weaknesses**
- Session/transaction strategy is simplistic.
- No separation for read/write domains, no retry strategy, no pool tuning, no statement timeouts.

### Containerization

**Strengths**
- Docker Compose stack is runnable and coherent.

**Weaknesses**
- Dockerfile is minimal and lacks hardened production setup (non-root user, layer optimization, health commands, startup command).
- Dependency pinning is loose for most core libs; heavyweight ML deps are included without clear runtime need.

### AWS readiness

**Assessment**
- **Prototype deployable** to ECS/EC2+RDS with effort.
- Not production-ready for AWS operations yet (no IaC, secrets strategy, CI/CD, structured env promotion, observability stack).

## Phase 4 — Data Science Signal

- Strongest DS-adjacent signal is **data product enablement** (searchable program profile + geography aggregate).
- Preference modeling/simulation/policy analysis are mostly roadmap statements, not implemented analytics.
- Net: **mostly data plumbing with light analytical framing**.

## Phase 5 — Enterprise Maturity Scores (1–10)

- Code organization: **6/10**
- Naming conventions: **7/10**
- Logging: **4/10**
- Testing presence: **5/10**
- Documentation quality: **7/10**
- README clarity: **8/10**
- Reproducibility: **6/10**
- Version control hygiene: **5/10**

## Phase 6 — What CaRMS Would Care About Most

A Lead Data Scientist at CaRMS would likely focus on:
1. Whether this can become a trusted warehouse foundation.
2. Whether ETL can be modernized without introducing data integrity risk.
3. Whether outputs can support matching/planning analytics.
4. Whether teams can operate and extend it collaboratively.

**Current signal:**
- Maintain warehouse: **partial**.
- Modernize ETL: **partial-positive**.
- Support algorithm inputs: **weak today**.
- Operational data products: **moderate**.
- Cross-team collaboration readiness: **moderate**, limited by governance/testing depth.

## Phase 7 — Top 10 Gaps Blocking “Elite” Status

1. No migration-backed schema evolution flow (Alembic not operationalized).
2. No source-to-target reconciliation checks.
3. No asset checks / data quality constraints in Dagster.
4. No drift detection for changing source columns.
5. No indexing and performance strategy for API query paths.
6. Duplicate application trees (`app/` + `carms/`) create ownership ambiguity.
7. No formal service/repository abstraction in API.
8. No CI/CD pipeline with lint/test/build gates.
9. No deployment narrative for ECS/RDS/S3 with environment separation.
10. No implemented simulation/preference model layer.

## Phase 8 — Differentiation Score

- **Not just a student notebook project.**
- **Not yet a real platform engineer build.**
- Best classification: **serious project hobbyist trending toward junior platform engineer**.

Why:
- Positive: integrated stack and deploy intent.
- Limiting: missing enterprise hardening, contracts, and analytics depth.

## Phase 9 — Upgrade Plan to “Auto-Interview” Level

### Top 5 improvements (highest impact)

1. Implement Alembic migrations + versioned schema release notes + backward-compat policy.
2. Add Dagster asset checks (null/unique/range/freshness/reconciliation) with failure thresholds.
3. Add performance layer: indexes, query plan snapshots, pagination strategy, and API SLO targets.
4. Introduce service/repository layers and DTO boundaries in FastAPI.
5. Add CI/CD (ruff + pytest + migration smoke test + container build) with environment promotion docs.

### Top 3 “wow” features

1. Match simulation sandbox (quota shocks / province preference shifts / discipline demand scenarios).
2. Preference analytics API (ranked discipline-site insights with uncertainty bands).
3. Operational cockpit dashboard (pipeline freshness, quality scorecards, API latency, and adoption metrics).

## Phase 10 — Hiring Panel Simulation

**Lead Data Scientist:**
“Good architecture instincts for junior level and the right stack. But I don’t yet see rigorous data contracts or analytics depth to trust this in decision workflows.”

**Data Engineer:**
“I like the layered ETL and runnable compose setup. I’m concerned about schema governance, indexing, and the duplicate code trees. This needs hardening before production.”

**Director:**
“So: potential is there, polish is not. I’d approve an interview if we test for execution maturity, ownership, and ability to close enterprise gaps quickly.”

**Panel outcome:**
- **Interview: Yes**
- **Hire now: No**
- **Proceed if candidate demonstrates strong improvement velocity and technical judgment.**

## Optional Bonus

- **LangChain relevance:** currently aspirational; no concrete retrieval/embedding pipeline in production flow.
- **Matching algorithm potential:** data model can seed inputs, but no feature engineering/simulation scaffolding yet.
- **Policy insight potential:** geographic rollups are a starting point; needs longitudinal and scenario layers.
- **Visualization storytelling:** map is a good demo artifact, but still descriptive rather than decision-grade.

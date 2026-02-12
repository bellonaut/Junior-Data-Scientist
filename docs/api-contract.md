# API Contract

## Security
- Optional API key header: `X-API-Key`. Enabled when `API_KEY` is set (see `.env.example`). All routes enforce it when present.
- Rate limit: `RATE_LIMIT_REQUESTS` per `RATE_LIMIT_WINDOW_SEC` (default 120 requests / 60s) applied per client IP.

## Base URL
- Local dev: `http://localhost:8000`

## Endpoints

### `GET /health`
- Purpose: liveness check.
- Responses: `200 {"status": "ok"}` when healthy.

### `GET /programs`
- Query params:
  - `discipline` (str, optional, substring match)
  - `province` (str, optional, codes AB|BC|MB|NB|NL|NS|NT|NU|ON|PE|QC|SK|YT|UNKNOWN)
  - `school` (str, optional, substring match)
  - `limit` (int, default 100, min 1, max 500)
  - `offset` (int, default 0, min 0)
  - `include_total` (bool, default false)
  - `preview_chars` (int, default 900, max 5000)
- Responses:
  - `200` ProgramListResponse
  - `422` on validation errors.

### `GET /programs/{program_stream_id}`
- Path params: `program_stream_id` (int, required)
- Responses:
  - `200` ProgramDetail
  - `404` if not found

### `GET /disciplines`
- Purpose: active discipline lookup.
- Responses: list of disciplines.

### `POST /pipeline/run`
- Purpose: trigger Dagster asset job via GraphQL.
- Responses:
  - `200` with `{status, detail, run_id?}` on success.
  - `502` if Dagster unreachable.
  - `404/502` when job not found.

### Map endpoints
- `GET /map` (HTML choropleth UI)
- `GET /map/data.json` (province rollup JSON: province, name, lat, lon, programs)
- `GET /map/canada.geojson` (static GeoJSON)

### `POST /semantic/query`
- Purpose: semantic search over program descriptions with optional LangChain Q&A summarization.
- Body:
  - `query` (str, required)
  - `province` (str, optional, code filter)
  - `discipline` (str, optional, substring filter)
  - `top_k` (int, default 5, min 1, max 20)
- Responses:
  - `200` with `{hits: [program_stream_id, names, province, discipline, similarity, description_snippet], answer?, top_k}`
  - `422` when top_k is out of bounds.

## Error envelope
- Validation: FastAPI default `422 Unprocessable Entity` with details.
- Auth: `401` with message when API key invalid/missing.
- Rate limit: `429` with retry message.

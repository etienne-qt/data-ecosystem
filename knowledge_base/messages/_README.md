# Messages Layer — Fast-Retrieval Validated Claims

## What this layer is

The `messages/` directory is the **fast-retrieval layer** of the knowledge base. It contains validated, citable, standalone claims organized by theme. Each file covers one theme and is designed to be directly usable in:

- Narrative documents (`narratives/`)
- Slide presentations and decks
- Policy briefs and recommendation reports
- Media talking points and stakeholder communications
- The annual Portrait du Québec Tech

Unlike raw `insights/` (which index external report findings) or `internal/` analyses (which contain full methodology and caveats), message entries are **pre-digested claims** — the single sentence a policy analyst, journalist, or exec needs to cite and act on.

## When to use messages vs insights

| Layer | Use when… | Format |
|-------|-----------|--------|
| `messages/` | You need a ready-to-cite, validated claim | MSG entries (see below) |
| `insights/` | You need the full external-report context | INS entries in topic files |
| `internal/` | You need methodology, caveats, and full data | INTERNAL analysis cards |

## Message entry format

Every message entry follows this exact structure:

```markdown
### MSG-{theme}-{nn}: Short title
- **Claim:** One clear sentence with the number/finding
- **Confidence:** High | Medium | Low
- **Evidence:** INS-xxx-nn or INTERNAL-xxx-nn (insight/internal analysis IDs)
- **Implication:** One sentence on why this matters for QT's work
- **Last verified:** YYYY-MM-DD
```

### Field definitions

| Field | Rules |
|-------|-------|
| **theme** | Short slug matching the filename (e.g., `FUNDING`, `HARDTECH`, `MACRO`, `SIZE`, `TALENT`, `EXITS`, `POLICY`) |
| **nn** | Two-digit sequential number within the theme (01, 02, …) |
| **Short title** | ≤ 8 words, descriptive enough to scan |
| **Claim** | One sentence. Must include the specific number/finding. Must be falsifiable. |
| **Confidence** | High = verified from primary data with methodology; Medium = from secondary source or single internal analysis; Low = directional/preliminary |
| **Evidence** | Comma-separated IDs pointing to `internal/{id}.md` or `insights/_index.csv` |
| **Implication** | One sentence on the "so what" — why this matters for QT's mandate or deliverables |
| **Last verified** | Date the claim was last checked against primary data |

## Confidence guide

- **High** — the finding is reproducible from a named primary data source (REQ, PitchBook, Dealroom, CVCA), methodology is documented, and the claim has been validated by the data team
- **Medium** — the finding comes from a single analysis, an external secondary report, or a directional reading of data with known limitations
- **Low** — preliminary, small sample, or based on proxy data (e.g., CAE code fallback, incomplete coverage)

## Theme files in this directory

| File | Theme | Status |
|------|-------|--------|
| `ecosystem-size.md` | Total startup counts, registry universe, source breakdown | Partially populated |
| `funding-landscape.md` | Round sizes, VC deal flow, public vs private capital | Partially populated |
| `hard-tech.md` | Hardware/photonics formation rates, sector signals | Partially populated |
| `macro-trends.md` | GenAI impact, company creation trends | Partially populated |
| `talent.md` | Talent flows, compensation, workforce composition | Stub — no data yet |
| `exits.md` | M&A activity, IPOs, acquisition landscape | Stub — no data yet |
| `policy.md` | Policy levers, program effectiveness, gaps | Stub — no data yet |

## Promotion workflow

When a new internal analysis or external report insight is validated:

1. Read the `internal/{id}.md` card or `insights/_index.csv` entry
2. Draft the MSG entry following the format above
3. Choose the appropriate theme file
4. Assign the next sequential number within that theme
5. Add the entry under the appropriate section heading in the theme file
6. Record the `Evidence` ID pointing back to the source
7. Update `Last verified` to today's date

When a claim is superseded by new data, update the `Claim` field and `Last verified` — do not delete old entries. Mark superseded entries with a `> [SUPERSEDED by MSG-{theme}-{nn}]` note.

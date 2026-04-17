# Snowflake Schema Documentation

Document the shared Snowflake tables and views used across QT, RC, and CIQ.

## Shared database structure

```
shared_ecosystem/
├── qt_schema/           # Quebec Tech tables
│   ├── companies        # Dealroom-sourced company data
│   ├── funding_rounds   # Dealroom funding data
│   └── radar_metrics    # Quebec Tech Radar aggregates
├── rc_schema/           # Réseau Capital tables
│   ├── vc_deals         # PitchBook VC deal data
│   ├── pe_deals         # PitchBook PE deal data
│   └── quarterly_stats  # Quarterly aggregate summaries
├── ciq_schema/          # CIQ tables
│   ├── innovation_index # Baromètre de l'innovation data
│   └── policy_metrics   # Innovation policy tracking
└── shared_views/        # Cross-org views and joins
    ├── company_master   # Unified company view
    └── funding_timeline # Cross-source funding timeline
```

## Table details

*(Fill in as tables are documented. Include: column names, types, descriptions, source, update frequency.)*

## Query conventions

- Always use fully qualified names: `shared_ecosystem.{schema}.{table}`
- Use taxonomy codes from `taxonomy/` for filtering — never hardcode category strings
- When building aggregates for insights, apply the governance rules from `DATA-GOVERNANCE.md`
- Date fields use `YYYY-MM-DD` format
- Currency amounts are stored in CAD unless the column name specifies otherwise (e.g., `total_funding_usd`)

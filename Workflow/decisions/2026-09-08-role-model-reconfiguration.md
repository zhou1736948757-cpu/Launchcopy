# Role model reconfiguration (2026-09-08)

- **Decision owner**: User
- **Applies to**: Future Main / Chief / Worker / Reviewer dispatches
- **Runtime task state at change**: No active agent jobs
- **Worker concurrency ceiling**: Preserved at 3

## Declared configuration

| Role | Model | Thinking depth |
|---|---|---|
| Main | `gpt-5.6-sol` | `medium` |
| Chief | `gpt-6-astra` | `medium` |
| Worker | `gpt-5.6-sol` | `low` |
| Reviewer | `gpt-5.6-luna` | `max` |

## Interpretation

- User shorthand `5.6sol`, `astra`, `sol`, and `luna` is normalized to the exact model IDs above.
- This file and `Workflow/config.json` declare intended routing. They do not by themselves prove the provider's upstream model selection; Main must report observable routing evidence when available.
- Expert Worker inherits the Chief-class configuration unless a later Chief or user decision changes it.
- Existing task history and prior role/model records remain unchanged.

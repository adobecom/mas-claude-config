# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the `io` subdirectory of the Merch at Scale (M@S) monorepo, containing Adobe I/O Runtime serverless actions. It consists of two separate Adobe I/O Runtime projects:

- **www** - Main production services (MerchAtScale project)
- **studio** - Studio-specific backend services (MerchAtScaleStudio project)

Both projects deploy serverless actions to Adobe I/O Runtime and are built on Node.js 22+.

## Architecture

### www/ - Main Services

The fragment pipeline is the core service, processing multiple steps to deliver merchandising content:

1. **fetch** - Retrieves fragment data from Odin
2. **translate** - Handles locale/translation mapping
3. **settings** - Applies settings transformations
4. **replace** - Performs content replacements and placeholders
5. **wcs** - Integrates Web Content Service data
6. **corrector** - Final corrections and validation

Key files:
- `src/fragment/pipeline.js` - Main orchestration (PIPELINE array defines transformation order)
- `src/fragment/common.js` - Shared utilities (logging, timing, state management)
- `src/fragment-client.js` - Browser-compatible build of the pipeline
- `src/health-check/index.js` - Service health monitoring

The pipeline uses a context object passed through each transformer, accumulating data and timing metrics.

### studio/ - Studio Backend

Provides APIs for OST (Offer Selection Tool) and member management:

- `src/ost-products/write.js` - Queries AOS API and caches product lists (triggered daily via GitHub Actions)
- `src/ost-products/read.js` - Returns cached product list with IMS auth
- `src/members/` - Member management endpoints

## Development Commands

### Prerequisites

```bash
npm install -g @adobe/aio-cli
```

Request Adobe I/O Runtime access via #milo-dev Slack channel. Create workspace in Developer Console, download auth JSON, and run:

```bash
aio app use <filename>  # Populates .env and .aio files
```

### Running Tests

```bash
# www/
npm test                    # Run with coverage (99% required)
npm run test:watch          # Watch mode
npm run test:file -- "pattern"  # Run specific test

# studio/
npm test                    # Basic test suite
npm run test:watch          # Watch mode
```

### Linting

```bash
npm run lint                # Check for errors
npm run lint:fix            # Auto-fix issues
```

### Building

```bash
# www/ only
npm run build:client        # Build fragment-client.js for browser
                           # Output: ../../studio/libs/fragment-client.js
```

### Local Development

```bash
# www/
cd www
aio app dev                # Start dev server on localhost:9080
# Access: https://localhost:9080/api/v1/web/MerchAtScale/health-check

# studio/
cd studio
aio app dev                # Start dev server on localhost:9080
# Access: https://localhost:9080/api/v1/web/MerchAtScaleStudio/ost-products-read
```

### Deployment

**IMPORTANT**: Always deploy specific actions, not all at once:

```bash
aio app test && aio app deploy -a <action-name>

# Examples:
aio app deploy -a fragment
aio app deploy -a ost-products-read

# Force re-deploy if needed:
aio app deploy --force-deploy --no-publish -a <action-name>
```

## Configuration

### Environment Variables

Required in `.env` (generated via `aio app use`):

**www/**
- `ODIN_CDN_ENDPOINT` - Odin CDN endpoint
- `ODIN_ORIGIN_ENDPOINT` - Odin origin endpoint
- `WCS_CDN_ENDPOINT` - WCS CDN endpoint
- `WCS_ORIGIN_ENDPOINT` - WCS origin endpoint
- `AOS_API_KEY` - AOS API key
- `AOS_URL` - AOS endpoint

**studio/**
- `AOS_URL` - AOS endpoint
- `AOS_API_KEY` - AOS API key
- `OST_WRITE_API_KEY` - API key for write operations

### Runtime Configuration (www/)

Configuration stored in Adobe I/O Runtime state, managed via `aio app state` commands:

```bash
aio app state list                    # View all configs
aio app state put key value --ttl=31536000  # Set config (1 year TTL)
aio app state del key                 # Remove config
```

Key configurations in `configuration` state object:
- `wcsConfigurations` - WCS cache prefill settings
- `debugLogs` - Enable debug logging (boolean)
- `networkConfig` - Timeouts and retry settings (fetchTimeout: 2s, mainTimeout: 15s)

## Testing Against Deployed Actions

### www/
After deployment, Nala e2e tests run automatically in CI:
- Health check test: `@health` tag
- Default locale: `@e2e` tag
- French locale: `@e2e` tag with `locale=fr_FR`

Tests access deployed actions via:
```
https://<workspace>.adobeioruntime.net/api/v1/web/MerchAtScale/<action-name>
```

### studio/
OST product write is triggered daily via `.github/workflows/ost-products.yaml`

## Key Files

- `app.config.yaml` - Action definitions and I/O Runtime configuration
- `rollup.config.cjs` (www only) - Builds browser-compatible fragment-client
- `utils.js` (studio only) - Shared utility functions

## Notes

- Node.js version: >=22 (ensure 22.16+ for husky pre-commit hooks in www/)
- Both projects use Mocha/Chai for testing
- ESLint configured to ignore web-src directories
- www/ enforces 99% code coverage (with specific exclusions)
- All actions run on nodejs:22 runtime
- Fragment pipeline uses brotli compression for responses
- To run milolibs in local, use URL parameter `milolibs=local`
- Use git worktrees when delegating tasks to agents

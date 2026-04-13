---
paths:
  - io/**/*.js
  - io/www/**/*.js
  - io/studio/**/*.js
---

# Adobe I/O Runtime Serverless Actions

## Project Structure

Two separate I/O Runtime projects:

| Project | Path | Purpose |
|---------|------|---------|
| **www** | `io/www/` | Production services (MerchAtScale) |
| **studio** | `io/studio/` | Studio backend (MerchAtScaleStudio) |

## Fragment Pipeline (www/)

Core service processing merchandising content through transformers:

```
fetch → translate → settings → replace → wcs → corrector
```

### Pipeline Context Object

Context flows through all transformers accumulating data:

```javascript
// Context structure
{
    fragment: { /* fragment data */ },
    fragmentIds: { 'default-locale-id': 'parent-id' },
    locale: 'en_US',
    timing: { fetch: 120, translate: 45 },
    // ... accumulated by each transformer
}
```

### Key Files

- `src/fragment/pipeline.js` - Main orchestration (PIPELINE array)
- `src/fragment/common.js` - Shared utilities (logging, timing)
- `src/fragment-client.js` - Browser-compatible build

## Action Development

### Action Structure

```javascript
// src/my-action/index.js
async function main(params) {
    const { __ow_headers, ...rest } = params;

    // Validate IMS token if needed
    const token = __ow_headers?.authorization?.replace('Bearer ', '');

    try {
        const result = await processRequest(rest);
        return {
            statusCode: 200,
            body: result,
        };
    } catch (error) {
        return {
            statusCode: error.statusCode || 500,
            body: { error: error.message },
        };
    }
}

exports.main = main;
```

### Error Handling

```javascript
// Standard error response format
return {
    statusCode: 400,
    body: {
        error: 'Validation failed',
        details: validationErrors,
    },
};

// Common status codes
// 200 - Success
// 400 - Bad request (validation)
// 401 - Unauthorized (IMS token)
// 404 - Not found
// 500 - Internal error
```

## Testing (99% Coverage Required for www/)

```bash
# Run with coverage
npm test

# Watch mode
npm run test:watch

# Specific test file
npm run test:file -- "pipeline"
```

### Test Structure

```javascript
import { expect } from 'chai';
import sinon from 'sinon';

describe('my-action', () => {
    let sandbox;

    beforeEach(() => {
        sandbox = sinon.createSandbox();
    });

    afterEach(() => {
        sandbox.restore();
    });

    it('should process valid request', async () => {
        const result = await main({ param: 'value' });
        expect(result.statusCode).to.equal(200);
    });
});
```

## State Management

Configuration stored in I/O Runtime state:

```bash
# View all configs
aio app state list

# Set config (1 year TTL)
aio app state put key value --ttl=31536000

# Remove config
aio app state del key
```

### Key Configurations

| Key | Purpose |
|-----|---------|
| `wcsConfigurations` | WCS cache prefill settings |
| `debugLogs` | Enable debug logging |
| `networkConfig` | Timeouts (fetchTimeout: 2s, mainTimeout: 15s) |

## Local Development

```bash
# Prerequisites
npm install -g @adobe/aio-cli
aio app use <auth-file.json>  # From Developer Console

# Start dev server
cd io/www
aio app dev
# Access: https://localhost:9080/api/v1/web/MerchAtScale/health-check

# Studio backend
cd io/studio
aio app dev
```

## Deployment

### Deploy Specific Actions

```bash
# Always run tests first
aio app test && aio app deploy -a <action-name>

# Examples
aio app deploy -a fragment
aio app deploy -a ost-products-read

# Force re-deploy
aio app deploy --force-deploy --no-publish -a <action-name>
```

### Access Deployed Actions

```
https://<workspace>.adobeioruntime.net/api/v1/web/MerchAtScale/<action-name>
```

## IMS Token Validation

```javascript
// In action
const validateToken = async (token, clientId) => {
    const response = await fetch(
        `https://ims-na1.adobelogin.com/ims/validate_token/v1?client_id=${clientId}&type=access_token`,
        {
            headers: { Authorization: `Bearer ${token}` },
        }
    );
    if (!response.ok) {
        throw { statusCode: 401, message: 'Invalid token' };
    }
    return response.json();
};
```

## OST Products (studio/)

Daily-triggered caching of product lists:

```javascript
// write.js - Queries AOS API, stores in state
// read.js - Returns cached data with IMS auth

// Triggered via GitHub Actions: .github/workflows/ost-products.yaml
```

## Build Client Bundle

```bash
# Build browser-compatible fragment-client.js
cd io/www
npm run build:client

# Output: ../../studio/libs/fragment-client.js
```

## Environment Variables

**www/**
- `ODIN_CDN_ENDPOINT` - Odin CDN endpoint
- `WCS_CDN_ENDPOINT` - WCS CDN endpoint
- `AOS_API_KEY` - AOS API key

**studio/**
- `AOS_URL` - AOS endpoint
- `OST_WRITE_API_KEY` - Write operation key

## Common Patterns

### Timing Metrics

```javascript
import { startTiming, endTiming } from './common.js';

const context = { timing: {} };
startTiming(context, 'fetch');
// ... do work
endTiming(context, 'fetch');
// context.timing.fetch = 120 (ms)
```

### Brotli Compression

Responses use brotli compression:

```javascript
return {
    statusCode: 200,
    headers: {
        'Content-Encoding': 'br',
        'Content-Type': 'application/json',
    },
    body: brotliCompressed,
};
```

## Related Skills

- `io-runtime-master` - Expert I/O Runtime knowledge
- `fragment-pipeline-debugger` - Debug pipeline transformers
- `ost-products-debugger` - Debug OST product caching

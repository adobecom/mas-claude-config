---
paths:
  - "**/aem*.js"
  - "**/fragment-client*.js"
  - io/**/*.js
  - studio/src/**/aem*.js
---

# AEM Integration Patterns

## ETag Handling

ETags are critical for optimistic concurrency control in AEM.

### Always Include ETags in Updates

```javascript
async function updateFragment(fragment, etag) {
    const response = await fetch(url, {
        method: 'PUT',
        headers: {
            'If-Match': etag,  // Required for updates
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(fragment)
    });

    if (response.status === 412) {
        // ETag mismatch - fragment was modified externally
        throw new ETagConflictError('Fragment was modified by another user');
    }

    // Return new ETag from response
    return response.headers.get('ETag');
}
```

### Store ETags After Every Operation

```javascript
// After successful fetch
const etag = response.headers.get('ETag');
fragmentStore.setETag(fragmentId, etag);

// After successful update
const newEtag = response.headers.get('ETag');
fragmentStore.setETag(fragmentId, newEtag);
```

## CSRF Token Handling

### Token Acquisition Pattern

```javascript
async function getCSRFToken() {
    const response = await fetch('/libs/granite/csrf/token.json', {
        credentials: 'same-origin'
    });
    const data = await response.json();
    return data.token;
}

// Use in mutating requests
headers['CSRF-Token'] = await getCSRFToken();
```

### Token Refresh on 403

```javascript
if (response.status === 403) {
    // Token may have expired - refresh and retry
    const newToken = await getCSRFToken();
    return retryWithToken(newToken);
}
```

## Error Handling

### Standard Error Responses

| Status | Meaning | Action |
|--------|---------|--------|
| 400 | Bad Request | Check payload format |
| 401 | Unauthorized | Refresh IMS token |
| 403 | Forbidden | Refresh CSRF token |
| 404 | Not Found | Fragment doesn't exist |
| 412 | Precondition Failed | ETag conflict - reload |
| 429 | Rate Limited | Exponential backoff |
| 500+ | Server Error | Retry with backoff |

### Structured Error Handling

```javascript
class AEMError extends Error {
    constructor(message, status, details) {
        super(message);
        this.status = status;
        this.details = details;
    }
}

async function handleAEMResponse(response) {
    if (!response.ok) {
        const details = await response.json().catch(() => ({}));
        throw new AEMError(
            `AEM request failed: ${response.statusText}`,
            response.status,
            details
        );
    }
    return response;
}
```

## API Patterns

### Fragment CRUD Operations

```javascript
// Read
GET /api/assets/{path}.json

// Create
POST /api/assets/{path}
Content-Type: application/json

// Update
PUT /api/assets/{path}
If-Match: {etag}
Content-Type: application/json

// Delete
DELETE /api/assets/{path}
```

### Polling for Changes

```javascript
// Use Last-Modified header for efficient polling
const response = await fetch(url, {
    headers: {
        'If-Modified-Since': lastModified
    }
});

if (response.status === 304) {
    // Not modified - no new data
    return null;
}
```

## I/O Runtime Integration

### Context Object Structure

```javascript
const context = {
    fragmentIds: {
        'default-locale-id': 'parent-fragment-id',
        // ... other locale mappings
    },
    fragment: { /* fragment data */ },
    // ... additional context
};
```

### Transformer Pipeline

Fragments pass through transformers in `io/`:
1. Fetch from AEM
2. Locale fallback resolution
3. WCS integration (pricing)
4. Field transformation
5. Return enriched context

## Related Skills

- `aem-api-network-debugger` - Debug AEM API calls
- `fragment-operation-debugger` - Debug CRUD operations
- `fragment-pipeline-debugger` - Debug I/O Runtime pipeline
- `mas-aem-integration` - Work with AEM fragment operations

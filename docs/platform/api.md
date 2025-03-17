# SummitEthic API Documentation

## Overview

This document provides comprehensive documentation for the SummitEthic API, including endpoints, authentication methods, request/response formats, and ethical considerations.

## Base URL

The API is accessible at the following base URLs:

| Environment | Base URL                                 |
| ----------- | ---------------------------------------- |
| Production  | `https://api.summitethic.com/v1`         |
| Staging     | `https://api-staging.summitethic.com/v1` |
| Development | `https://api-dev.summitethic.com/v1`     |

## Authentication

The API supports the following authentication methods:

### JWT Authentication

For most API endpoints, JWT (JSON Web Token) authentication is required:

1. Obtain a token by making a POST request to `/auth/login` with valid credentials
2. Include the token in subsequent requests using the `Authorization` header:
   ```
   Authorization: Bearer YOUR_JWT_TOKEN
   ```
3. Tokens expire after 1 hour and can be refreshed using the `/auth/refresh` endpoint

### API Key Authentication

For server-to-server communication, API key authentication is supported:

1. Request an API key from the SummitEthic administrator
2. Include the API key in the request header:
   ```
   X-API-Key: YOUR_API_KEY
   ```

## Rate Limiting

To ensure fair usage and prevent abuse, the API implements rate limiting:

- Standard users: 100 requests per minute
- Premium users: 300 requests per minute
- API keys: Customizable limits based on use case

When the rate limit is exceeded, the API returns a `429 Too Many Requests` response.

## Endpoints

### Authentication

#### POST /auth/login

Authenticates a user and returns a JWT token.

**Request:**

```json
{
  "email": "user@example.com",
  "password": "your_password"
}
```

**Response:**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600
}
```

#### POST /auth/refresh

Refreshes an expired JWT token.

**Request:**

```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response:**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600
}
```

### Projects

#### GET /projects

Retrieves a list of projects the authenticated user has access to.

**Parameters:**

| Parameter | Type   | Required | Description                  |
| --------- | ------ | -------- | ---------------------------- |
| page      | number | No       | Page number (default: 1)     |
| limit     | number | No       | Items per page (default: 20) |
| status    | string | No       | Filter by status             |

**Response:**

```json
{
  "data": [
    {
      "id": "proj-123",
      "name": "Website Redesign",
      "description": "Ethical redesign of company website",
      "status": "active",
      "createdAt": "2025-01-15T08:30:00Z",
      "updatedAt": "2025-03-01T14:45:00Z"
    },
    {
      "id": "proj-124",
      "name": "Database Migration",
      "description": "Migration to privacy-focused database",
      "status": "completed",
      "createdAt": "2025-02-10T09:15:00Z",
      "updatedAt": "2025-02-28T16:20:00Z"
    }
  ],
  "meta": {
    "total": 15,
    "page": 1,
    "limit": 20,
    "pages": 1
  }
}
```

#### GET /projects/{id}

Retrieves detailed information about a specific project.

**Response:**

```json
{
  "id": "proj-123",
  "name": "Website Redesign",
  "description": "Ethical redesign of company website",
  "status": "active",
  "createdAt": "2025-01-15T08:30:00Z",
  "updatedAt": "2025-03-01T14:45:00Z",
  "members": [
    {
      "id": "user-101",
      "name": "Jane Smith",
      "role": "Project Lead"
    },
    {
      "id": "user-102",
      "name": "John Doe",
      "role": "Developer"
    }
  ],
  "tasks": [
    {
      "id": "task-201",
      "title": "Design Privacy-First Forms",
      "status": "completed"
    },
    {
      "id": "task-202",
      "title": "Implement Accessible Navigation",
      "status": "in_progress"
    }
  ],
  "ethicalConsiderations": [
    "Accessibility compliance",
    "Data minimization",
    "Transparent user consent"
  ]
}
```

#### POST /projects

Creates a new project.

**Request:**

```json
{
  "name": "New Ethical Project",
  "description": "Project with ethical considerations",
  "ethicalConsiderations": [
    "Accessibility compliance",
    "Data minimization",
    "Transparent user consent"
  ]
}
```

**Response:**

```json
{
  "id": "proj-125",
  "name": "New Ethical Project",
  "description": "Project with ethical considerations",
  "status": "active",
  "createdAt": "2025-03-17T10:30:00Z",
  "updatedAt": "2025-03-17T10:30:00Z",
  "ethicalConsiderations": [
    "Accessibility compliance",
    "Data minimization",
    "Transparent user consent"
  ]
}
```

#### PUT /projects/{id}

Updates an existing project.

**Request:**

```json
{
  "name": "Updated Project Name",
  "description": "Updated description with ethical focus",
  "status": "in_progress"
}
```

**Response:**

```json
{
  "id": "proj-123",
  "name": "Updated Project Name",
  "description": "Updated description with ethical focus",
  "status": "in_progress",
  "createdAt": "2025-01-15T08:30:00Z",
  "updatedAt": "2025-03-17T11:45:00Z"
}
```

### Users

#### GET /users/me

Retrieves the profile of the authenticated user.

**Response:**

```json
{
  "id": "user-101",
  "name": "Jane Smith",
  "email": "jane@example.com",
  "role": "Project Manager",
  "permissions": ["create_project", "manage_users", "view_reports"],
  "createdAt": "2024-11-05T09:20:00Z",
  "updatedAt": "2025-02-10T14:30:00Z"
}
```

#### GET /users

Retrieves a list of users (requires admin permissions).

**Response:**

```json
{
  "data": [
    {
      "id": "user-101",
      "name": "Jane Smith",
      "email": "jane@example.com",
      "role": "Project Manager"
    },
    {
      "id": "user-102",
      "name": "John Doe",
      "email": "john@example.com",
      "role": "Developer"
    }
  ],
  "meta": {
    "total": 25,
    "page": 1,
    "limit": 20,
    "pages": 2
  }
}
```

### Ethical Assessments

#### GET /assessments

Retrieves ethical assessments for projects.

**Response:**

```json
{
  "data": [
    {
      "id": "assess-001",
      "projectId": "proj-123",
      "score": 85,
      "completedAt": "2025-02-15T11:30:00Z",
      "categories": {
        "privacy": 90,
        "accessibility": 80,
        "fairness": 85,
        "transparency": 85
      }
    },
    {
      "id": "assess-002",
      "projectId": "proj-124",
      "score": 92,
      "completedAt": "2025-03-01T14:15:00Z",
      "categories": {
        "privacy": 95,
        "accessibility": 90,
        "fairness": 90,
        "transparency": 95
      }
    }
  ],
  "meta": {
    "total": 12,
    "page": 1,
    "limit": 20,
    "pages": 1
  }
}
```

#### POST /assessments

Creates a new ethical assessment for a project.

**Request:**

```json
{
  "projectId": "proj-125",
  "categories": {
    "privacy": 85,
    "accessibility": 90,
    "fairness": 80,
    "transparency": 95
  },
  "notes": "Initial assessment shows good privacy and transparency practices, but fairness could be improved."
}
```

**Response:**

```json
{
  "id": "assess-003",
  "projectId": "proj-125",
  "score": 87.5,
  "completedAt": "2025-03-17T12:00:00Z",
  "categories": {
    "privacy": 85,
    "accessibility": 90,
    "fairness": 80,
    "transparency": 95
  },
  "notes": "Initial assessment shows good privacy and transparency practices, but fairness could be improved."
}
```

## Error Handling

The API uses standard HTTP status codes and returns detailed error information:

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid or expired token",
    "details": "The authentication token has expired. Please refresh your token."
  }
}
```

Common error codes:

| Status Code | Error Code       | Description                                       |
| ----------- | ---------------- | ------------------------------------------------- |
| 400         | BAD_REQUEST      | Invalid request format or parameters              |
| 401         | UNAUTHORIZED     | Authentication required or failed                 |
| 403         | FORBIDDEN        | Insufficient permissions for the requested action |
| 404         | NOT_FOUND        | Requested resource not found                      |
| 422         | VALIDATION_ERROR | Input validation failed                           |
| 429         | RATE_LIMITED     | Too many requests, exceeding rate limit           |
| 500         | SERVER_ERROR     | Internal server error                             |

## Ethical API Design Principles

The SummitEthic API is designed with the following ethical principles:

### 1. Data Minimization

The API implements data minimization principles:

- Only essential data is collected and processed
- Unused fields can be excluded using the `fields` parameter
- PII (Personally Identifiable Information) is handled with special care

### 2. Transparency

The API promotes transparency through:

- Clear documentation of all data handling practices
- Explicit indication of data usage in responses
- Comprehensive audit logs for all operations

### 3. Fairness and Non-Discrimination

The API is designed to be fair and non-discriminatory:

- Rate limits are applied consistently across users
- Resource allocation is monitored for equitable access
- Regular audits ensure no unintended bias in data processing

### 4. Security

The API incorporates robust security measures:

- End-to-end encryption for all communications
- Strict authentication and authorization controls
- Regular security assessments and penetration testing

### 5. Resource Efficiency

The API is optimized for resource efficiency:

- Response compression to reduce bandwidth usage
- Efficient caching strategies to minimize redundant processing
- Batch operations to reduce the number of requests

## Versioning

The API uses semantic versioning in the URL path (`/v1/`). When breaking changes are introduced, a new version will be released, and the previous version will be supported for at least 12 months.

## Pagination

List endpoints support pagination using the following parameters:

- `page`: Page number (1-based)
- `limit`: Number of items per page (default: 20, max: 100)

Pagination metadata is included in the `meta` section of the response.

## Support

For API support or to report issues:

- Email: api-support@summitethic.com
- Support Portal: https://support.summitethic.com/api
- API Status Page: https://status.summitethic.com

## Changelog

### v1.0.0 (2025-01-15)

- Initial release of the SummitEthic API
- Authentication endpoints
- Project management endpoints
- User management endpoints
- Ethical assessment endpoints

### v1.1.0 (2025-03-01)

- Added batch operations for projects
- Improved rate limiting with user-specific quotas
- Enhanced ethical assessment functionality
- Added detailed audit logs

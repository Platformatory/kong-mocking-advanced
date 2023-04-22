# Overview

Enable schema (OpenAPI) driven mocking for Kong.

# Features

- Supports 3 modes:
  - auto: Automatically generates mocks using Lua faker, based on the determined response schema
  - example_literal: Uses response examples
  - example_template: Supports template variables (request context, API caller info and several random generator functions)
- Supports request validation
  - with type coercion
  - optionally ignore extraneous parameters
- OpenaAPI support
  - Full OpenAPI 3.0 support with references
  - Supports schema format hints
  - enums
  - oneOf, anyOf, allOf  

# Installation

```
luarocks install kong-mocking-advanced
```

# Configuration

| Parameter | Default  | Required | description |
| --------- | -------- | -------- | ----------- |
| config.oas3_spec | | Yes | HTTP/S or Local file path |
| config.mode | auto | No | can be example_literal, example_template or auto |
| config.validate_requests | false | no | Whether to validate requests |
| config.response_code_hint_source | x-kong-response-code | no | Clients can hint which rsponse code is desired. Relevantly when validate_requests is turned of and mode is auto |


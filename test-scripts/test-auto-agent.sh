#!/bin/bash
curl -s -X GET http://localhost:8000/customers/3456?context=recent_website_activity -H "x-kong-response-code:200" | jq

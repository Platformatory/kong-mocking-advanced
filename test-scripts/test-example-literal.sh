#!/bin/bash
curl -s -X GET http://localhost:8000/customers -H "x-kong-response-code:200" | jq

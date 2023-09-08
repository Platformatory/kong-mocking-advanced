#!/bin/bash
curl -s -X GET "http://localhost:8000/customers?customer_id=3456&name=HeWhoMustNotBeNamed" -H "x-kong-response-code:200" | jq

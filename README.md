# Overview

This plugin enables turning your Kong API Gateway into an event source. It can be configured to take API logs and relay them to configurable Kafka topics, supporting the CloudEvents format. It also supports authentication to Kafka using SASL/PLAIN (and therefore supports confluent cloud)

# Installation

```
luarocks install kong-event-pub
```

# Configuration

| Parameter | Default  | Required | description |
| --------- | -------- | -------- | ----------- |
| config.bootstrap_servers | | Yes | Kafka Bootstrap |
| config.port | 9092 | Yes | Kafka port |
| config.ssl | true | Yes | Whether SSL/TLS is enabled |
| config.sasl_mechanism | PLAIN | yes | Presently only PLAIN is supported; Support for Kerberos, SCRAM-SHA-512 coming up |
| config.sasl_user | | Yes | SASL Username |
| config.sasl_password | | Yes | SASL Password |
| encoding | application/json | Yes | Encoding of the data. Presently only JSON is supported; Avro will follow |
| format | CloudEventsKafkaProtocolBinding | Yes | Cloud events protocol binding. Defaults to Kafka; Other mechanisms maybe supported later | 
| config.eventmaps[] | | Yes | Array of destination inputs. Each takes the following parameters to perform event map matches; request_path_match, position, http_method, response_codes (array), destination_topic, key, data |
| config.dlc | No | No | A Dead-letter channel to send unmatched events to |

# Future Features

- Fully Configurable Message Payload Callbacks
- Transformation Callbacks
- Avro & Confluent Schema Registry Support


# Copyright Materialize, Inc. and contributors. All rights reserved.
#
# Use of this software is governed by the Business Source License
# included in the LICENSE file at the root of this repository.
#
# As of the Change Date specified in that file, in accordance with
# the Business Source License, use of this software will be governed
# by the Apache License, Version 2.0.

$ set schema={
    "type": "record",
    "name": "envelope",
    "fields": [
      {
        "name": "before",
        "type": [
          {
            "name": "row",
            "type": "record",
            "fields": [
              {"name": "a", "type": "long"},
              {"name": "b", "type": "long"}
            ]
          },
          "null"
        ]
      },
      { "name": "after", "type": ["row", "null"] }
    ]
  }

$ set trxschemakey={
      "name": "io.debezium.connector.common.TransactionMetadataKey",
      "type": "record",
      "fields": [
          {
              "name": "id",
              "type": "string"
          }
      ]
  }

$ set trxschema={
    "type":"record", "name":"TransactionMetadataValue", "namespace":"io.debezium.connector.common",
    "fields":[
    {"name":"status","type":"string"},
    {"name":"id","type": "string"},
    {"name": "event_count",
    "type": ["null", "long"],
    "default": null
    },
    {"name":"data_collections","type":["null",{"type":"array",
    "items": {"type":"record",
    "name":"ConnectDefault",
    "namespace":"io.confluent.connect.Avro",
    "fields": [ {
    "name": "data_collection",
    "type": "string"
    },
    {
    "name": "event_count",
    "type": "long" }]}}],
    "default": null}],
    "connect.name": "io.debezium.connector.common.TransactionMetadataValue"
    }

$ kafka-ingest format=avro topic=input-consistency timestamp=1 schema=${trxschemakey}
{"id": "52"}

$ kafka-ingest format=avro topic=input-consistency timestamp=1 schema=${trxschema}
{"status":"BEGIN","id":"52","event_count":null,"data_collections":null}
{"status":"END","id":"52","event_count":{"long": 2},"data_collections":{"array": [{"event_count": 2, "data_collection": "testdrive-input-${testdrive.seed}"}]}}

$ kafka-ingest format=avro topic=input schema=${schema} timestamp=14
{"before": null, "after": {"row": {"a": 4, "b": 1}}}
{"before": null, "after": {"row": {"a": 5, "b": 2}}}

> SELECT * FROM input_byo
a  b
------
1   1
2   1
3   1
1   2
11  11
22  11
3   4
5   6
4  1
5  2

$ kafka-verify format=avro sink=materialize.public.output sort-messages=true
{"before": null, "after": {"row": {"a": 1, "b": 1}}, "transaction": {"id": "1"}}
{"before": null, "after": {"row": {"a": 1, "b": 2}}, "transaction": {"id": "1"}}
{"before": null, "after": {"row": {"a": 2, "b": 1}}, "transaction": {"id": "1"}}
{"before": null, "after": {"row": {"a": 3, "b": 1}}, "transaction": {"id": "1"}}

$ kafka-verify format=avro sink=materialize.public.output sort-messages=true
{"before": null, "after": {"row": {"a": 11, "b": 11}}, "transaction": {"id": "2"}}
{"before": null, "after": {"row": {"a": 22, "b": 11}}, "transaction": {"id": "2"}}

$ kafka-verify format=avro sink=materialize.public.output sort-messages=true
{"before": null, "after": {"row": {"a": 3, "b": 4}}, "transaction": {"id": "3"}}
{"before": null, "after": {"row": {"a": 5, "b": 6}}, "transaction": {"id": "3"}}

$ kafka-verify format=avro sink=materialize.public.output sort-messages=true
{"before": null, "after": {"row": {"a": 4, "b": 1}}, "transaction": {"id": "4"}}
{"before": null, "after": {"row": {"a": 5, "b": 2}}, "transaction": {"id": "4"}}

> SELECT * FROM reingest_rt_sink
a  b
------
1   1
2   1
3   1
1   2
11  11
22  11
3   4
5   6
4  1
5  2

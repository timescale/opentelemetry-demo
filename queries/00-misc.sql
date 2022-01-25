View "ps_trace.span"
┌────────────────────────────────┬──────────────────────────┬
│             Column             │           Type           │
├────────────────────────────────┼──────────────────────────┼
│ trace_id                       │ trace_id                 │
│ span_id                        │ bigint                   │
│ trace_state                    │ text                     │
│ parent_span_id                 │ bigint                   │
│ is_root_span                   │ boolean                  │
│ service_name                   │ text                     │
│ span_name                      │ text                     │
│ span_kind                      │ span_kind                │
│ start_time                     │ timestamp with time zone │
│ end_time                       │ timestamp with time zone │
│ time_range                     │ tstzrange                │
│ duration_ms                    │ double precision         │
│ span_tags                      │ tag_map                  │
│ dropped_tags_count             │ integer                  │
│ event_time                     │ tstzrange                │
│ dropped_events_count           │ integer                  │
│ dropped_link_count             │ integer                  │
│ status_code                    │ status_code              │
│ status_message                 │ text                     │
│ instrumentation_lib_name       │ text                     │
│ instrumentation_lib_version    │ text                     │
│ instrumentation_lib_schema_url │ text                     │
│ resource_tags                  │ tag_map                  │
│ resource_dropped_tags_count    │ integer                  │
│ resource_schema_url            │ text                     │
└────────────────────────────────┴──────────────────────────┴

-- distinct service names
SELECT value#>>'{}'
FROM _ps_trace.tag
WHERE key = 'service.name'
;

-- distinct operations per service
SELECT DISTINCT span_name
FROM _ps_trace.operation
WHERE service_name_id IN
(
    SELECT id
    FROM _ps_trace.tag
    WHERE key = 'service.name'
    AND value#>>'{}' IN (${service:sqlstring})
);


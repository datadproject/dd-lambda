# Datadog Lambda Forwarder inside reusable ECS module

## ECS module
- Add `ecs-module/datadog-forwarder.tf`.
- Merge `ecs-module/variables-forwarder.tf` into the module variables.
- Merge the `archive` provider from `ecs-module/versions-snippet.tf` into the existing `required_providers` block.

## Consumer/environment repo
- Merge `consumer/variables-forwarder.tf` into consumer variables.
- Add `consumer/main-module-call.snippet.tf` arguments to the existing ECS module call.
- Add the environment values from `consumer/ecs.tfvars.example`.

## Logging path
ECS -> awslogs -> CloudWatch Logs -> Datadog Forwarder Lambda -> Datadog

Keep the existing Datadog Agent for APM/metrics. Do not enable a second direct application-log path to Datadog or logs will be duplicated.

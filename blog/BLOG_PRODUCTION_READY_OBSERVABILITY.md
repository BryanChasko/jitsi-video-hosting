# Production-Ready Jitsi on ECS Express: Observability, Safety & Cost Control

**Date**: December 27, 2025  
**Account**: 170473530355 (us-west-2)  
**Status**: Implementation Plan Ready

---

## Overview

We've designed a comprehensive production-ready infrastructure for Jitsi on ECS Express that adds enterprise-grade observability, deployment safety, and cost controls. This post covers the key improvements, particularly **CloudWatch Metrics with AWS Distro for OpenTelemetry (ADOT)**.

---

## Key Improvements

### 1. **CloudWatch Metrics with ADOT (Collector-Less OTLP)**

**Problem**: Traditional observability requires sidecars or collectors, adding complexity and overhead.

**Solution**: AWS Distro for OpenTelemetry (ADOT) with collector-less OTLP sends metrics directly to CloudWatch via **Embedded Metric Format (EMF)**.

**Implementation**:
```bash
OTEL_METRICS_EXPORTER=awsemf
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=https://logs.us-west-2.amazonaws.com/v1/metrics
OTEL_EXPORTER_OTLP_METRICS_PROTOCOL=http/protobuf
```

**Benefits**:
- ✅ No sidecar container needed
- ✅ Direct to CloudWatch (no collector overhead)
- ✅ EMF format enables high-cardinality metrics
- ✅ Automatic trace-to-metric correlation
- ✅ Native CloudWatch integration

**Reference**: [AWS Distro for OpenTelemetry - CloudWatch Metrics](https://aws-otel.github.io/docs/getting-started/cloudwatch-metrics)

---

### 2. **Full Observability Stack**

**Traces**: Direct to X-Ray OTLP endpoint
```bash
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=https://xray.us-west-2.amazonaws.com/v1/traces
OTEL_TRACES_EXPORTER=otlp
```

**Logs**: Direct to CloudWatch OTLP endpoint
```bash
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=https://logs.us-west-2.amazonaws.com/v1/logs
OTEL_EXPORTER_OTLP_LOGS_HEADERS=x-aws-log-group=/ecs/jitsi-app,x-aws-log-stream=default
OTEL_LOGS_EXPORTER=otlp
```

**Metrics**: CloudWatch EMF format
```bash
OTEL_METRICS_EXPORTER=awsemf
```

**Result**: Complete observability without sidecars or collectors.

---

### 3. **Path-Based ALB Routing (Extensible)**

**Current**: `/public/*` → Jitsi Web (port 80)

**Future-Ready**:
- `/auth/*` → Auth Service (port 8001)
- `/stream/*` → Stream Service (port 8002)
- `/ingest/*` → Ingest Service (port 8003)
- `/api/v1/*` → API Service (port 8004)

**Benefit**: Single ALB, multiple services, clean separation of concerns.

---

### 4. **Health Checks (Container + ALB)**

**Container Level**:
```
Command: curl -f http://localhost/health || exit 1
Interval: 30s, Timeout: 5s, Retries: 3, StartPeriod: 60s
```

**ALB Level**:
```
Protocol: HTTP, Path: /health, Port: 80
Interval: 30s, Timeout: 5s
Healthy: 2 consecutive successes
Unhealthy: 3 consecutive failures
```

**Benefit**: Automatic failure detection and safe rollbacks.

---

### 5. **ECS Deployment Circuit Breaker**

**Configuration**:
```hcl
deployment_circuit_breaker {
  enable   = true
  rollback = true
}
```

**Behavior**:
- Monitors ALB, container, and CloudMap health checks
- Failure threshold: 2 tasks (50% of 3 desired count)
- Automatic rollback on health check failures
- Service remains available during rollback

**Benefit**: Zero-downtime deployments with automatic recovery.

---

### 6. **CloudWatch Alarms for Canary Monitoring**

**5xx Error Rate**:
- Metric: `HTTPCode_Target_5XX_Count`
- Threshold: > 5 errors in 60 seconds
- Action: SNS notification to ops

**Latency (p99)**:
- Metric: `TargetResponseTime`
- Threshold: > 2 seconds
- Action: SNS notification to ops

**Benefit**: Early detection of issues before they impact users.

---

### 7. **AWS Budgets for Cost Control**

**5 Budget Thresholds**:
- $5, $10, $20, $40, $60 (monthly)
- Notification type: FORECASTED (alert before overspend)
- Notification threshold: 100% of budget
- Channel: SNS to ops email

**Benefit**: Prevent unexpected AWS bills.

---

## Architecture

```
Account 170473530355 (us-west-2)
├── ALB (HTTPS:443)
│   ├── /public/* → Jitsi Web (port 80)
│   ├── /auth/* → Auth Service (port 8001) [future]
│   ├── /stream/* → Stream Service (port 8002) [future]
│   ├── /ingest/* → Ingest Service (port 8003) [future]
│   └── /api/v1/* → API Service (port 8004) [future]
│
├── ECS Service (Circuit Breaker Enabled)
│   ├── Desired Count: 3
│   ├── Deployment Controller: ECS (rolling update)
│   └── Auto-Rollback: Enabled
│
└── ECS Task Definition
    ├── Container Health Check (30s interval)
    ├── ADOT Environment Variables
    │   ├── Traces → X-Ray OTLP
    │   ├── Logs → CloudWatch OTLP
    │   └── Metrics → CloudWatch EMF
    └── CloudWatch Logs: /ecs/jitsi-app

Observability & Monitoring
├── CloudWatch X-Ray: Traces (aws/spans log group)
├── CloudWatch Logs: Application logs (/ecs/jitsi-app)
├── CloudWatch Metrics: EMF format metrics
├── CloudWatch Alarms: 5xx errors, latency p99
├── SNS Topics: deployment-alerts, budget-alerts
└── AWS Budgets: $5, $10, $20, $40, $60 thresholds
```

---

## Why ADOT Collector-Less OTLP?

### Traditional Approach (Sidecar)
```
Application → Sidecar Container → CloudWatch
```
- Extra container overhead
- More resources needed
- Additional complexity
- Potential failure point

### ADOT Collector-Less Approach
```
Application → CloudWatch OTLP Endpoint (direct)
```
- No sidecar needed
- Minimal overhead
- Simple configuration
- Direct integration

**Result**: Same observability, less complexity.

---

## Implementation Status

✅ **Design Complete**: 7-task production-ready plan  
✅ **Terraform Code Ready**: All infrastructure as code  
✅ **Documentation Complete**: Deployment guide, verification procedures  
⏳ **Deployment Pending**: Ready to deploy to account 170473530355

---

## Next Steps

1. Deploy to account 170473530355 using Terraform
2. Verify all components (routing, health checks, observability, alarms, budgets)
3. Test canary deployments and rollback
4. Monitor CloudWatch dashboards for traces, logs, metrics
5. Add future services (`/auth/*`, `/stream/*`, etc.) as needed

---

## References

- [AWS Distro for OpenTelemetry - CloudWatch Metrics](https://aws-otel.github.io/docs/getting-started/cloudwatch-metrics)
- [CloudWatch Agent OpenTelemetry](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-OpenTelemetry-metrics.html)
- [ECS Deployment Circuit Breaker](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-circuit-breaker.html)
- [ALB Health Checks](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html)
- [AWS Budgets](https://docs.aws.amazon.com/awsaccountmanagement/latest/userguide/budgets-managing-costs.html)

---

**Author**: Kiro CLI  
**Account**: 170473530355  
**Region**: us-west-2  
**Status**: Ready for Deployment

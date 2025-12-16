# ECS Express + On-Demand NLB Deployment Checklist

## Pre-Deployment ✅

- [x] **Terraform Configuration**: Validated successfully
- [x] **Module Structure**: JVB NLB module created and initialized  
- [x] **Scripts Enhanced**: scale-up.pl, scale-down.pl, register-nlb-targets.pl
- [x] **Cost Analysis**: Updated for on-demand model ($0.24/month idle)
- [x] **State Backup**: terraform.tfstate.backup.20241216_134224
- [x] **Configuration**: config.json created with jitsi-hosting profile

## Authentication Required ⚠️

- [ ] **AWS SSO Login**: `aws sso login --profile jitsi-hosting`
- [ ] **Verify Access**: `aws sts get-caller-identity --profile jitsi-hosting`

## Deployment Execution

### Phase 1: SSM Migration (5 minutes)
```bash
cd /Users/bryanchasko/Code/Projects/jitsi-video-hosting

# Deploy SSM parameters only (low risk)
terraform apply -var="aws_profile=jitsi-hosting" -var="domain_name=meet.example.com" \
  -target=aws_ssm_parameter.jicofo_component_secret \
  -target=aws_ssm_parameter.jicofo_auth_password \
  -target=aws_ssm_parameter.jvb_component_secret \
  -target=aws_ssm_parameter.jvb_auth_password \
  -target=aws_ssm_parameter.jigasi_auth_password

# Verify SSM parameters created
aws ssm get-parameters --names \
  "/jitsi-video-platform/jicofo_component_secret" \
  "/jitsi-video-platform/jicofo_auth_password" \
  "/jitsi-video-platform/jvb_component_secret" \
  "/jitsi-video-platform/jvb_auth_password" \
  "/jitsi-video-platform/jigasi_auth_password" \
  --profile jitsi-hosting --region us-west-2
```

**Success Criteria**:
- [ ] 5 SSM parameters created
- [ ] Parameters accessible via AWS CLI
- [ ] No errors in Terraform apply

### Phase 2: ECS Service Connect (10 minutes)
```bash
# Deploy Service Connect and ECS updates
terraform apply -var="aws_profile=jitsi-hosting" -var="domain_name=meet.example.com" \
  -target=aws_service_discovery_private_dns_namespace.jitsi \
  -target=aws_ecs_service.jitsi \
  -target=aws_ecs_task_definition.jitsi

# Verify Service Connect namespace
aws servicediscovery list-namespaces --profile jitsi-hosting --region us-west-2
```

**Success Criteria**:
- [ ] Service Discovery namespace created
- [ ] ECS service updated with Service Connect
- [ ] Task definition references SSM parameters
- [ ] No service disruption (desired_count=0)

### Phase 3: Full Infrastructure (5 minutes)
```bash
# Apply all remaining changes
terraform apply -var="aws_profile=jitsi-hosting" -var="domain_name=meet.example.com"

# Verify clean state
terraform plan -var="aws_profile=jitsi-hosting" -var="domain_name=meet.example.com"
```

**Success Criteria**:
- [ ] All resources deployed successfully
- [ ] Terraform plan shows no pending changes
- [ ] NLB module ready (but not created)

## Functional Testing

### Scale-Up Test (5 minutes)
```bash
# Test NLB creation and ECS scaling
./scripts/scale-up.pl

# Expected sequence:
# 1. Create NLB via Terraform
# 2. Wait for NLB active (max 5 min)
# 3. Scale ECS to 1 instance
# 4. Register task IPs with target groups
# 5. Verify target health
```

**Success Criteria**:
- [ ] NLB created successfully
- [ ] ECS task starts and becomes healthy
- [ ] Task IP registered with UDP and TCP target groups
- [ ] Target health checks pass

### Connectivity Test (5 minutes)
```bash
# Get NLB DNS name
terraform output jvb_nlb_dns_name

# Test HTTPS access (Service Connect ALB)
curl -k https://meet.example.com/

# Test UDP/TCP ports (if tools available)
# nc -u <nlb-dns> 10000  # UDP test
# nc <nlb-dns> 4443      # TCP test
```

**Success Criteria**:
- [ ] HTTPS web interface accessible
- [ ] NLB DNS resolves correctly
- [ ] UDP and TCP ports respond

### Scale-Down Test (3 minutes)
```bash
# Test ECS scaling and NLB destruction
./scripts/scale-down.pl

# Expected sequence:
# 1. Scale ECS to 0 instances
# 2. Destroy NLB via Terraform
# 3. Verify cleanup completion
```

**Success Criteria**:
- [ ] ECS service scaled to zero
- [ ] NLB destroyed successfully
- [ ] No orphaned resources remain

## Cost Validation

### Immediate Verification
```bash
# Run cost analysis
./scripts/cost-analysis.pl

# Check AWS billing (after 1 hour)
aws ce get-cost-and-usage --profile jitsi-hosting \
  --time-period Start=2024-12-16,End=2024-12-17 \
  --granularity DAILY \
  --metrics BlendedCost
```

**Success Criteria**:
- [ ] Cost analysis shows $0.24/month idle
- [ ] Running costs match $0.2205/hour projection
- [ ] AWS billing reflects actual usage

### 24-Hour Monitoring
- [ ] **Idle State**: Verify $0.24/month projection
- [ ] **Running State**: Monitor hourly costs during testing
- [ ] **Billing Dashboard**: Confirm no unexpected charges

## Rollback Procedures

### If Deployment Fails
```bash
# Restore previous state
cp terraform.tfstate.backup.20241216_134224 terraform.tfstate
terraform apply -var="aws_profile=jitsi-hosting" -var="domain_name=meet.bryanchasko.com"
```

### If Testing Fails
```bash
# Scale down to minimize costs
./scripts/scale-down.pl

# Investigate issues
aws logs describe-log-groups --profile jitsi-hosting --region us-west-2
aws ecs describe-services --cluster jitsi-video-platform-cluster --profile jitsi-hosting --region us-west-2
```

## Post-Deployment

### Documentation Updates
- [ ] Update OPERATIONS.md with new procedures
- [ ] Document actual vs projected costs
- [ ] Create troubleshooting guide
- [ ] Update team training materials

### Monitoring Setup
- [ ] Configure CloudWatch dashboards
- [ ] Set up cost alerts
- [ ] Create performance baselines
- [ ] Document operational procedures

---

**Total Estimated Time**: 30-45 minutes  
**Risk Level**: LOW (incremental changes, rollback available)  
**Prerequisites**: AWS SSO authentication for jitsi-hosting profile  
**Success Criteria**: All checkboxes completed without errors

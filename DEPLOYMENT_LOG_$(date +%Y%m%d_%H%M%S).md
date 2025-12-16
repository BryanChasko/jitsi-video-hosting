# ECS Express + On-Demand NLB Deployment Log

**Date**: December 16, 2024  
**Time**: 13:42 PST  
**Profile**: jitsi-hosting  
**Environment**: Development  

## 1. PREREQUISITE CHECKS ✅

### AWS Authentication Status
- **Profile**: jitsi-hosting  
- **Status**: ❌ Requires SSO authentication  
- **Action Required**: `aws sso login --profile jitsi-hosting`

### Terraform State Backup
- **Backup Created**: terraform.tfstate.backup.20241216_134224
- **Original State**: Preserved with existing random passwords and bucket suffix

### Terraform Plan Analysis
```bash
terraform plan -var="aws_profile=jitsi-hosting" -var="domain_name=meet.example.com"
```

**Expected Changes Detected**:
- ✅ SSM Parameter Store migration (secrets_manager_arn → ssm_parameter_prefix)
- ✅ Domain name update for testing
- ✅ No infrastructure changes (output-only changes)

## 2. DEPLOYMENT READINESS ✅

### Configuration Validation
- **Terraform**: Configuration validates successfully
- **Modules**: JVB NLB module initialized and ready
- **Variables**: All required variables defined
- **Outputs**: Conditional outputs configured for NLB resources

### Implementation Status
- ✅ **Phase 1**: JVB NLB Terraform module created
- ✅ **Phase 2**: ECS Service Connect configured  
- ✅ **Phase 3**: Scripts enhanced for NLB lifecycle
- ✅ **Phase 4**: JVB TCP fallback configured
- ✅ **Phase 5**: Cost analysis updated for on-demand model

## 3. DEPLOYMENT PLAN

### Step 1: SSM Migration (Low Risk)
```bash
# Apply SSM parameter changes only
terraform apply -var="aws_profile=jitsi-hosting" -var="domain_name=meet.example.com" -target=aws_ssm_parameter.jicofo_component_secret -target=aws_ssm_parameter.jicofo_auth_password -target=aws_ssm_parameter.jvb_component_secret -target=aws_ssm_parameter.jvb_auth_password -target=aws_ssm_parameter.jigasi_auth_password
```

**Expected Results**:
- 5 SSM parameters created
- No service disruption (service at desired_count=0)
- Secrets Manager resources remain until ECS update

### Step 2: ECS Service Update
```bash
# Apply ECS Service Connect and task definition changes
terraform apply -var="aws_profile=jitsi-hosting" -var="domain_name=meet.example.com" -target=aws_service_discovery_private_dns_namespace.jitsi -target=aws_ecs_service.jitsi -target=aws_ecs_task_definition.jitsi
```

**Expected Results**:
- Service Discovery namespace created
- ECS service updated with Service Connect
- Task definition updated with SSM parameter references
- Port mappings updated with names

### Step 3: Full Infrastructure Apply
```bash
# Apply all remaining changes
terraform apply -var="aws_profile=jitsi-hosting" -var="domain_name=meet.example.com"
```

**Expected Results**:
- All resources aligned with new architecture
- NLB module ready (but not created due to nlb_enabled=false)
- Clean state with no pending changes

## 4. FUNCTIONAL TESTING PLAN

### Scale-Up Test
```bash
./scripts/scale-up.pl
```

**Expected Sequence**:
1. Create NLB via `terraform apply -var="nlb_enabled=true"`
2. Wait for NLB active state (max 5 minutes)
3. Scale ECS service to desired_count=1
4. Wait for task to start and become healthy
5. Register task IP with NLB target groups (UDP:10000, TCP:4443)
6. Verify target health

### Connectivity Test
- **HTTPS Web Interface**: Access via Service Connect ALB
- **UDP/10000**: JVB primary media port via NLB
- **TCP/4443**: JVB fallback port via NLB
- **Health Checks**: HTTP/8080 for both target groups

### Scale-Down Test
```bash
./scripts/scale-down.pl
```

**Expected Sequence**:
1. Scale ECS service to desired_count=0
2. Wait for tasks to stop
3. Destroy NLB via `terraform apply -var="nlb_enabled=false"`
4. Verify no orphaned resources

## 5. COST VALIDATION

### Expected Idle Costs (Monthly)
- **S3 Storage**: ~$0.23 (10GB recordings)
- **SSM Parameters**: $0.00 (free tier)
- **S3 Log Archive**: ~$0.01 (2GB archived logs)
- **Total**: ~$0.24/month (under $0.73 target)

### Expected Running Costs (Hourly)
- **ECS Fargate**: $0.198/hour (4 vCPU, 8GB RAM)
- **Network Load Balancer**: $0.0225/hour
- **Total**: $0.2205/hour

### Break-Even Analysis
- **vs Always-On ALB**: 73 hours/month
- **Light Usage (10h/month)**: $2.45/month
- **Medium Usage (50h/month)**: $11.27/month

## 6. SUCCESS CRITERIA

### Infrastructure Deployment
- [ ] All Terraform applies succeed without errors
- [ ] SSM parameters created and accessible
- [ ] ECS Service Connect configured correctly
- [ ] NLB module ready for on-demand creation

### Functional Testing
- [ ] NLB creates and destroys on-demand via scripts
- [ ] ECS tasks start and register with NLB target groups
- [ ] Jitsi web interface accessible via HTTPS
- [ ] UDP and TCP connectivity verified

### Cost Validation
- [ ] Idle cost ≤ $0.50/month verified in AWS billing
- [ ] Running costs match projections
- [ ] Scale-up/down cycle completes in < 5 minutes

## 7. ROLLBACK PLAN

### If Deployment Fails
1. **Restore State**: `cp terraform.tfstate.backup.20241216_134224 terraform.tfstate`
2. **Revert Changes**: `terraform apply` with original configuration
3. **Verify Service**: Ensure ECS service returns to previous state

### If Testing Fails
1. **Scale Down**: `./scripts/scale-down.pl` to minimize costs
2. **Investigate**: Review CloudWatch logs and AWS console
3. **Fix Issues**: Address configuration problems
4. **Retry**: Re-run deployment after fixes

## 8. NEXT STEPS

### Post-Deployment
1. **Monitor Costs**: Track actual AWS billing for 24 hours
2. **Performance Testing**: Load test with multiple participants
3. **Documentation**: Update operational procedures
4. **Team Training**: Brief team on new architecture

### Production Planning
1. **Migration Strategy**: Plan migration from current setup
2. **Monitoring Setup**: Configure alerts and dashboards
3. **Backup Procedures**: Document disaster recovery
4. **Scaling Policies**: Define usage-based scaling rules

---

**Deployment Status**: READY FOR EXECUTION  
**Prerequisites**: AWS SSO authentication required  
**Risk Level**: LOW (incremental changes, rollback available)  
**Estimated Duration**: 30-45 minutes total

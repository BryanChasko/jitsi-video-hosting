# ECS Express with On-Demand NLB - Implementation Tasks

## Phase 1: Foundation Setup

### Task 1.1: Create JVB NLB Terraform Module
**Status**: Not Started
**Effort**: Medium
**Depends on**: None

#### Implementation:
1. Create directory `modules/jvb-nlb/`
2. Create `modules/jvb-nlb/main.tf` with:
   - `aws_lb` (network, external)
   - `aws_lb_target_group` (UDP/10000, IP target type)
   - `aws_lb_listener` (UDP/10000)
3. Create `modules/jvb-nlb/variables.tf` with inputs
4. Create `modules/jvb-nlb/outputs.tf` with DNS, ARNs

#### Files:
- `modules/jvb-nlb/main.tf` (NEW)
- `modules/jvb-nlb/variables.tf` (NEW)
- `modules/jvb-nlb/outputs.tf` (NEW)

#### Acceptance:
- [ ] Module validates with `terraform validate`
- [ ] Module can be applied independently
- [ ] NLB created with correct UDP listener

---

### Task 1.2: Add Module Reference to main.tf
**Status**: Not Started
**Effort**: Small
**Depends on**: Task 1.1

#### Implementation:
1. Add module block referencing `./modules/jvb-nlb`
2. Pass VPC ID, subnet IDs, security group from existing resources
3. Add `count = 0` to prevent auto-creation (scripts manage lifecycle)

#### Files:
- `main.tf` (MODIFY - add module block after VPC section)

#### Code:
```hcl
module "jvb_nlb" {
  source = "./modules/jvb-nlb"
  count  = var.nlb_enabled ? 1 : 0  # Controlled by variable

  project_name      = var.project_name
  vpc_id            = aws_vpc.jitsi.id
  subnet_ids        = aws_subnet.public[*].id
  security_group_id = aws_security_group.jitsi.id
}
```

#### Acceptance:
- [ ] Module referenced correctly
- [ ] Variable `nlb_enabled` controls creation
- [ ] Outputs accessible from root module

---

### Task 1.3: Add NLB Control Variable
**Status**: Not Started
**Effort**: Small
**Depends on**: None

#### Implementation:
1. Add `nlb_enabled` variable to `variables.tf`
2. Default to `false` (scripts will toggle via `-var`)
3. Add output for NLB DNS name (conditional)

#### Files:
- `variables.tf` (MODIFY)
- `outputs.tf` (MODIFY)

#### Acceptance:
- [ ] Variable defined with default `false`
- [ ] Output handles null case when disabled

---

## Phase 2: ECS Service Connect (Express Mode)

### Task 2.1: Create Service Discovery Namespace
**Status**: Not Started
**Effort**: Small
**Depends on**: None

#### Implementation:
1. Add `aws_service_discovery_private_dns_namespace` resource
2. Associate with VPC
3. Name: `${var.project_name}.local`

#### Files:
- `main.tf` (MODIFY - add after VPC section)

#### Acceptance:
- [ ] Namespace created in VPC
- [ ] Tagged correctly

---

### Task 2.2: Configure ECS Service Connect
**Status**: Not Started
**Effort**: Medium
**Depends on**: Task 2.1

#### Implementation:
1. Add `service_connect_configuration` block to ECS service
2. Configure for port 80 (web)
3. Add logging configuration
4. Remove any manual ALB configuration if present

#### Files:
- `main.tf` (MODIFY - ECS service resource)

#### Acceptance:
- [ ] Service Connect enabled
- [ ] Logs to CloudWatch
- [ ] No manual ALB references

---

### Task 2.3: Update Task Definition Port Mappings
**Status**: Not Started  
**Effort**: Small
**Depends on**: None

#### Implementation:
1. Add `name` field to port mappings (required for Service Connect)
2. Ensure web container port named "web"
3. Ensure JVB port named "jvb-udp"

#### Files:
- `main.tf` (MODIFY - task definition)

#### Code:
```hcl
portMappings = [
  {
    name          = "web"
    containerPort = 80
    protocol      = "tcp"
  }
]
```

#### Acceptance:
- [ ] Port mappings have names
- [ ] Service Connect can reference by name

---

## Phase 3: Script Enhancements

### Task 3.1: Enhance scale-up.pl with NLB Creation
**Status**: Not Started
**Effort**: Medium
**Depends on**: Tasks 1.1, 1.2, 1.3

#### Implementation:
1. Add NLB creation via `terraform apply -var="nlb_enabled=true" -target=module.jvb_nlb`
2. Add NLB active wait loop
3. Add target registration (register task IPs)
4. Update health checks to include NLB

#### Files:
- `scripts/scale-up.pl` (MODIFY)

#### Acceptance:
- [ ] Creates NLB before ECS scale
- [ ] Waits for NLB active state
- [ ] Registers targets after tasks start
- [ ] Verifies end-to-end connectivity

---

### Task 3.2: Enhance scale-down.pl with NLB Teardown
**Status**: Not Started
**Effort**: Medium
**Depends on**: Tasks 1.1, 1.2, 1.3

#### Implementation:
1. Add NLB destruction via `terraform apply -var="nlb_enabled=false"`
2. Ensure proper ordering (ECS first, then NLB)
3. Add verification of resource cleanup
4. Update cost reporting

#### Files:
- `scripts/scale-down.pl` (MODIFY)

#### Acceptance:
- [ ] Destroys NLB after ECS scale-down
- [ ] Verifies no orphaned resources
- [ ] Reports cost savings

---

### Task 3.3: Create Target Registration Script
**Status**: Not Started
**Effort**: Medium
**Depends on**: Task 1.1

#### Implementation:
1. Create `scripts/register-nlb-targets.pl`
2. Query running ECS task IPs
3. Register IPs with NLB target group
4. Verify target health

#### Files:
- `scripts/register-nlb-targets.pl` (NEW)

#### Acceptance:
- [ ] Discovers task IPs correctly
- [ ] Registers to target group
- [ ] Verifies healthy status

---

## Phase 4: JVB Configuration

### Task 4.1: Update JVB Environment Variables
**Status**: Not Started
**Effort**: Small
**Depends on**: Task 1.1

#### Implementation:
1. Ensure JVB_PORT = 10000
2. Add JVB_TCP_PORT = 4443 (fallback)
3. Configure DOCKER_HOST_ADDRESS placeholder
4. Add TCP harvester configuration

#### Files:
- `main.tf` (MODIFY - JVB container environment)

#### Acceptance:
- [ ] UDP primary on 10000
- [ ] TCP fallback on 4443
- [ ] NAT traversal configured

---

### Task 4.2: Update Security Group for TCP Fallback
**Status**: Not Started
**Effort**: Small
**Depends on**: None

#### Implementation:
1. Add TCP/4443 ingress rule to security group
2. Ensure UDP/10000 rule exists

#### Files:
- `main.tf` (MODIFY - security group)

#### Acceptance:
- [ ] TCP 4443 allowed
- [ ] UDP 10000 allowed

---

## Phase 5: Testing & Validation

### Task 5.1: Update test-platform.pl
**Status**: Not Started
**Effort**: Medium
**Depends on**: All previous tasks

#### Implementation:
1. Add NLB creation verification
2. Add UDP connectivity test
3. Add TCP fallback test
4. Add NLB teardown verification

#### Files:
- `scripts/test-platform.pl` (MODIFY)

#### Acceptance:
- [ ] Tests full lifecycle
- [ ] Verifies UDP video works
- [ ] Verifies TCP fallback works
- [ ] Verifies clean teardown

---

### Task 5.2: Update cost-analysis.pl
**Status**: Not Started
**Effort**: Small
**Depends on**: None

#### Implementation:
1. Update idle cost to $0.73/month
2. Add per-hour running cost
3. Update descriptions for on-demand model

#### Files:
- `scripts/cost-analysis.pl` (MODIFY)

#### Acceptance:
- [ ] Reflects new cost model
- [ ] Shows hourly vs monthly comparison

---

## Phase 6: Documentation

### Task 6.1: Update README.md
**Status**: Not Started
**Effort**: Small
**Depends on**: Task 5.1

#### Implementation:
1. Update architecture diagram
2. Update cost section
3. Document on-demand NLB approach

#### Files:
- `README.md` (MODIFY)

#### Acceptance:
- [ ] Accurate architecture description
- [ ] Correct cost figures

---

### Task 6.2: Update OPERATIONS.md
**Status**: Not Started
**Effort**: Small
**Depends on**: Task 5.1

#### Implementation:
1. Document NLB lifecycle
2. Update scale-up/scale-down procedures
3. Add troubleshooting for NLB issues

#### Files:
- `OPERATIONS.md` (MODIFY)

#### Acceptance:
- [ ] Clear operational procedures
- [ ] Troubleshooting guidance

---

### Task 6.3: Update Blog Posts
**Status**: Not Started
**Effort**: Small
**Depends on**: Task 5.1

#### Implementation:
1. Update BLOG_JITSI_ECS_EXPRESS.md with on-demand NLB approach
2. Document learnings and tradeoffs

#### Files:
- `blog/BLOG_JITSI_ECS_EXPRESS.md` (MODIFY)

#### Acceptance:
- [ ] Documents implementation journey
- [ ] Shares learnings

---

## Execution Order

```
Phase 1: Foundation (Tasks 1.1 → 1.2 → 1.3)
    ↓
Phase 2: ECS Service Connect (Tasks 2.1 → 2.2 → 2.3)
    ↓
Phase 3: Script Enhancements (Tasks 3.1, 3.2, 3.3 - parallel)
    ↓
Phase 4: JVB Configuration (Tasks 4.1 → 4.2)
    ↓
Phase 5: Testing (Tasks 5.1 → 5.2)
    ↓
Phase 6: Documentation (Tasks 6.1, 6.2, 6.3 - parallel)
```
## Kiro CLI Command

```bash
# In Kiro CLI, execute:
@autonomous-agent "Implement the ECS Express with On-Demand NLB spec in .kiro/specs/ecs-express-ondemand-nlb/tasks.md. 

Start with Phase 1 - create the JVB NLB Terraform module in modules/jvb-nlb/. 
Then proceed through phases sequentially.

Key requirements:
1. NLB module must support being created/destroyed independently
2. ECS service must use Service Connect for Express ALB
3. Scripts must manage NLB lifecycle (create on scale-up, destroy on scale-down)
4. Idle cost target: $0.73/month or less

Use Perl for all scripts per project conventions. Reference JitsiConfig module for configuration."
```

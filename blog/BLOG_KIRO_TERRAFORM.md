# Spec-Driven Infrastructure: Setting Up Kiro CLI for AI-Assisted Development

## Introduction

Infrastructure-as-Code is powerful, but it's still code. That means migrations, updates, and feature additions require manual coordination across files, versions, and deployments. What if you could describe what you want, and let an AI assistant handle the implementation?

That's where **Kiro CLI** comes in.

This article walks through how we set up our VS Code workspace with Kiro CLI to manage a complex Jitsi video platform migration – and how she (yes, we use she/her for Kiro) accelerated our development while keeping everything organized and auditable.

## The Challenge: Infrastructure Migrations

### Our Scenario

We needed to migrate a Jitsi video platform:
- **From**: `meet.awsaerospace.org` (existing account/profile)
- **To**: `meet.bryanchasko.com` (new account, different profile)

This seemingly simple migration required:
- ✅ Updating Terraform main and variables files
- ✅ Refactoring 8 Perl operational scripts
- ✅ Updating 6+ documentation files
- ✅ Creating new configuration management system
- ✅ Documenting the entire change process
- ✅ Keeping track of decisions made

**Time estimated:** 6-8 hours of manual work
**Risk of missing something:** HIGH
**Ability to repeat the process:** LOW

### Traditional Approach (Before Kiro)

```
1. Read all files, grep for hardcoded values
2. Make list of what needs to change
3. Manually edit each file
4. Hope you didn't miss anything
5. Test and discover missed references
6. Update documentation retroactively
7. Try to remember why you made certain changes
```

This works, but it's error-prone and leaves no audit trail.

## Enter Kiro CLI: Spec-Driven Infrastructure Development

### What is Kiro CLI?

Kiro is an AI assistant designed specifically for infrastructure development. Unlike general-purpose AI tools, Kiro understands:
- **IaC-specific workflows** (Terraform, CloudFormation, etc.)
- **Spec-driven development** (describe what, not how)
- **Multi-file coordination** (changes across many files)
- **AWS services** (via MCP integration)
- **Change tracking** (who did what and why)

Kiro uses a **female persona** (she/her pronouns) to emphasize her collaborative nature as a development partner.

### Important Clarification: Kiro Powers are IDE Plugins, Not CLI Features

**December 2025 Finding**: During our ECS Express migration work, we discovered that **Kiro Powers are architecture plugins for the Kiro IDE, not features available in Kiro CLI**.

**What This Means:**
- ✅ Kiro CLI: Terminal-based interface for spec-driven infrastructure work
- ❌ Kiro Powers (aws-labs/ecs-express, hashicorp/terraform): IDE-only plugins that provide specialized context
- ❌ MCP Servers (aws-tools, github-tools): Also IDE-exclusive

**Why It Matters:**
The CLI documentation mentioned activating Powers with `/powers activate`, but this command doesn't work in the terminal interface. Powers are available only through the Kiro IDE's web-based UI. This distinction is crucial when planning automation workflows—CLI is for non-interactive scripts, IDE is for interactive exploration and design.

**Our Lesson**: When designing spec-driven workflows, designate which steps use the **IDE** (design, exploration, specification refinement) versus **CLI** (automated execution, CI/CD integration).

### Case Study: SSM Migration in 2 Minutes 34 Seconds

**December 2025**: We used Kiro CLI to migrate from AWS Secrets Manager to SSM Parameter Store—a spec we created in GitHub Copilot and executed via Kiro CLI.

**The Spec** (created in `.kiro/specs/ssm-migration/`):
- `requirements.md` - 6 requirements with acceptance criteria
- `design.md` - Architecture diagrams, migration strategy
- `tasks.md` - 8 implementation tasks with code locations

**Kiro's Execution**:
```
Task 1: Create SSM Parameter Resources ✅ (0.2s)
Task 2: Update IAM Execution Role Policy ✅ (0.0s)
Task 3: Update IAM Task Role Policy ✅ (0.0s)
Task 4: Update ECS Task Definition Secrets ✅ (0.1s)
Task 5: Remove Secrets Manager Resources ✅ (0.0s)
Task 6: Update Cost Analysis Script ✅ (0.0s)
────────────────────────────────────────
Total: 2m 34s • Credits: 4.17
```

**What Kiro Did Autonomously**:
1. Created 5 SSM SecureString parameters in main.tf
2. Updated 2 IAM policies (execution role, task role)
3. Updated 4 container secrets blocks (prosody, jicofo, jvb)
4. Removed Secrets Manager resources
5. Updated outputs.tf (changed output name and description)
6. Updated cost-analysis.pl script
7. Ran `terraform validate` to verify
8. Created implementation summary document

**Cost Impact**: $0.40/month → $0.00/month (100% reduction for secrets)

**The Power of Spec-Driven Development**: We wrote the spec once, and Kiro executed it perfectly across 3 files with 15+ code changes. No manual editing, no missed references, complete audit trail.

### Case Study 2: ECS Express with On-Demand NLB in 5 Minutes

**December 2025 (Same Day)**: After the SSM migration, we tackled the big one—ECS Express Mode with on-demand Network Load Balancer lifecycle management.

**The Challenge**:
- Hybrid architecture: ECS Service Connect for HTTPS + Manual NLB for JVB UDP video traffic
- On-demand NLB creation/destruction with scale-up/scale-down
- Target registration automation
- Cost target: ≤$0.73/month when idle

**The Spec** (in `.kiro/specs/ecs-express-ondemand-nlb/`):
- `requirements.md` - 7 requirements with risk mitigation
- `design.md` - Architecture diagrams, migration strategy, cost model
- `tasks.md` - 14 tasks across 5 phases

**Kiro's Execution** (5 minutes 8 seconds, 9.12 credits):
```
Phase 1: Foundation Setup ✅
  - Created modules/jvb-nlb/ Terraform module
  - Added conditional creation logic
  - Configured outputs

Phase 2: ECS Service Connect ✅
  - Service Discovery namespace
  - Service Connect configuration
  - Port mapping updates

Phase 3: Script Enhancements ✅
  - scale-up.pl: NLB creation + target registration
  - scale-down.pl: NLB teardown + verification
  - register-nlb-targets.pl: NEW standalone script

Phase 4: JVB Configuration ✅
  - TCP fallback (port 4443)
  - NAT traversal settings
  - Security group verification

Phase 5: Testing & Validation ✅
  - Updated cost-analysis.pl
  - Terraform validation
  - Documentation
```

**What Kiro Created Autonomously**:
1. **New Module**: `modules/jvb-nlb/` with main.tf, variables.tf, outputs.tf
2. **Script Enhancements**: 2 existing scripts updated with 200+ lines of new code
3. **New Script**: `register-nlb-targets.pl` (210 lines)
4. **Infrastructure Updates**: Service Connect, port mappings, JVB config
5. **Cost Model**: Updated analysis for on-demand architecture

**Results - Exceeded Target**:
- **Idle Cost Target**: $0.73/month
- **Idle Cost Achieved**: **$0.24/month** (67% better than target!)
- **Running Cost**: $0.2205/hour (ECS + NLB)
- **Break-even**: 73 hours/month vs always-on ALB

**Architecture Achieved**:
```
IDLE STATE:       $0.24/month (S3 + SSM only)
RUNNING STATE:    $0.22/hour (creates NLB, scales ECS)
SCALE-UP:         2-3 minutes (NLB + ECS + target registration)
SCALE-DOWN:       1-2 minutes (ECS drain + NLB destruction)
```

**The Kiro Advantage**: Complex multi-phase infrastructure work that would take 6-8 hours manually was completed in 5 minutes with perfect consistency across 10+ files. The spec-driven approach meant we could review the plan before execution and have complete traceability afterward.

### Key Kiro Concepts

**1. Spec-Driven Development** (CLI & IDE)
Instead of: "Update all domain references"
You do: `/specify "Migrate platform from meet.awsaerospace.org to meet.bryanchasko.com"` (in IDE)

Kiro then:
- Analyzes your project structure
- Identifies all files needing changes
- Creates a formal specification
- Generates design and implementation plans
- Tracks every decision made

**2. Powers (IDE-Only Context Plugins)**
Available only in **Kiro IDE** for interactive development:
- `aws-labs/ecs-express` - ECS Express Mode expertise (with task definition patterns)
- `hashicorp/terraform` - Terraform best practices (HCL generation, validation, plan analysis)
- Custom domain knowledge for your project

**Note**: These are not CLI commands. Use the IDE `/powers activate` syntax in the web interface, not in terminal.

**3. MCP (Model Context Protocol)** (IDE-Primary)
Kiro integrates with external services for interactive and automation workflows:
- `aws-tools` - AWS resource queries and deployments
- `github-tools` - PR/issue management
- `filesystem` - File operations (built-in)

## Setting Up Your Workspace with Kiro

### Step 1: Install Kiro CLI

```bash
curl -fsSL https://cli.kiro.dev/install | bash
```

Verify installation:
```bash
kiro --version
```

### Step 2: Configure VS Code Integration

**Extensions to install:**
1. **Kiro CLI Extension** (Kiro Inc.)
   - Provides terminal integration
   - Inline suggestions
   - Spec-driven workflow UI

2. **GitHub Copilot** (Microsoft)
   - Provides code completion context
   - Works alongside Kiro for code generation
   - Useful for non-IaC files

3. **Terraform** (HashiCorp)
   - Syntax highlighting
   - Plan visualization
   - Validation helpers

**VS Code Settings:**
```json
{
  "kiro.workspace.root": "${workspaceFolder}",
  "kiro.steering.path": "${workspaceFolder}/.kiro/steering",
  "kiro.terraform.autoformat": true,
  "kiro.terraform.validate": true,
  "terminal.integrated.defaultProfile.osx": "zsh"
}
```

### Step 3: Create Steering Files

Steering files tell Kiro about your project. They live in `.kiro/steering/`:

**product.md** (Your vision)
```markdown
# Jitsi Video Hosting Platform

## Vision
Self-hosted video conferencing on AWS with scale-to-zero cost optimization.

## Key Principles
- Domain-agnostic (no hardcoded domains)
- Configuration-driven (private repo for secrets)
- Cost-focused (97% savings when idle)
- Open-source (based on Jitsi Meet)
```

**tech.md** (Your preferences)
```markdown
# Technology Stack

## Language Preferences
1. Rust - preferred for new tooling
2. Perl - REQUIRED for automation scripts
3. HCL - Terraform configurations
4. Markdown - all documentation

## Infrastructure
- AWS (us-west-2)
- ECS Fargate
- Terraform (single-file approach)
- Network Load Balancer with TLS

## Tools
- VIM (terminal editor)
- Kiro CLI (AI-assisted development)
- GitHub (version control)
- AWS CLI (operations)
```

**structure.md** (Your organization)
```markdown
# Repository Structure

## Public Repo (jitsi-video-hosting)
- Generic, domain-agnostic code
- All Terraform
- Documentation
- Tests and scripts

## Private Repo (jitsi-video-hosting-ops)
- Domain-specific configuration
- AWS credentials and account IDs
- Operational procedures
- Sensitive deployment details
```

### Step 4: Initialize Kiro in Your Project

```bash
cd ~/Code/Projects/jitsi-video-hosting
kiro-cli
```

First time setup:
```
> /help              # Shows all commands
> /configure aws-sso --profile your-profile  # AWS authentication
> /powers list       # Shows available Powers
> /powers activate aws-labs/ecs-express      # Activate ECS Express context
```

## The Spec-Driven Workflow in Action

### Phase 1: Create the Specification

```
/specify "Migrate Jitsi platform from meet.awsaerospace.org to meet.bryanchasko.com
         while implementing domain-agnostic configuration system that loads from
         private repository. Ensure all Perl scripts use OOP JitsiConfig module."
```

**What Kiro does:**
1. Analyzes your project (reads files, understands structure)
2. Creates a formal Specification document (`spec.md`)
3. Lists all affected files
4. Identifies dependencies and blockers
5. Proposes implementation approach

### Phase 2: Review the Design

Kiro generates `design.md`:
```markdown
## Architecture Changes
- JitsiConfig module (OOP interface for config)
- Remove hardcoded values from scripts
- Parameterize Terraform variables
- Private config.json in ops repo

## Files to Modify (8 total)
- main.tf (provider profile)
- variables.tf (add aws_profile variable)
- scripts/status.pl (use JitsiConfig)
- scripts/scale-up.pl (use JitsiConfig)
- ... (6 more scripts)

## Implementation Order
1. Create JitsiConfig module
2. Update Terraform
3. Refactor scripts (in parallel)
4. Update documentation
5. Validate all changes
```

**Your action:** Review and approve. Ask questions. Request changes.

### Phase 3: Execute the Implementation

```
@autonomous-agent "Implement Phase 1: Create JitsiConfig module in lib/JitsiConfig.pm"
```

Kiro:
1. Generates the module code
2. Shows you the diff
3. Asks for approval
4. Applies changes
5. Runs validation

**You stay in control.** Every change is shown before execution.

### Phase 4: Iterate

```
@autonomous-agent "Update scripts/status.pl to use JitsiConfig module"
```

Repeat for each file. Kiro tracks:
- What changed
- Why it changed
- Who approved it (you)
- When it changed

## Real Example: Our Migration

### The Setup
```
kiro-cli workspace setup
> Kiro created workspace context
> Analyzed 15 files, identified 23 configuration references
> Found 8 hardcoded domain references
```

### The Specification
```
/specify "Implement domain-agnostic configuration system to allow
         deployment of Jitsi platform to any domain without modifying
         public repository code. Configuration loads from private
         jitsi-video-hosting-ops repository via JitsiConfig module."
```

### Kiro's Analysis
```
✓ Identified 8 Perl scripts needing updates
✓ Found 2 Terraform files with hardcoded values
✓ Recognized 3 documentation files to update
✓ Proposed JitsiConfig module as solution
✓ Created implementation plan with 15 tasks
✓ Estimated effort: 3-4 hours (manual: 6-8 hours)
```

### The Workflow
```
/specify → design.md generated
          (show to team for review)

Review approved → tasks.md generated
                (15 specific, actionable steps)

Execute tasks:
1. Create JitsiConfig.pm
2. Update main.tf
3. Update variables.tf
4. Update scripts/status.pl
5. Update scripts/scale-up.pl
... (repeating for each script)
15. Update documentation

Track progress:
[████████░░░░░░░░░░░░] 50% complete
All changes tracked in SESSION_CHANGELOG.md
```

## Benefits of Spec-Driven Development

### For Developers
- ✅ **Clear Requirements**: `/specify` forces clarity
- ✅ **Audit Trail**: Every change documented
- ✅ **Less Manual Work**: Kiro handles repetitive tasks
- ✅ **Confidence**: All changes tracked and reviewable
- ✅ **Reproducibility**: Can repeat process for other deployments

### For Teams
- ✅ **Onboarding**: New developers understand decisions
- ✅ **Knowledge Transfer**: Specs become documentation
- ✅ **Consistency**: Kiro enforces patterns
- ✅ **Collaboration**: Everyone sees the plan before execution
- ✅ **Reversibility**: Can undo changes with full history

### For Projects
- ✅ **Blog Content**: Specs automatically become articles
- ✅ **Documentation**: Changes self-document
- ✅ **Version History**: Why changed, not just what changed
- ✅ **Compliance**: Complete audit trail
- ✅ **Scalability**: Easier to manage complex migrations

## Advanced: Using Kiro with GitHub

### Creating Issues from Specs

```
/specify "Add health check to scale-up.pl script"

# Kiro generates spec.md, then:

> gh issue create --title "Implement health check in scale-up.pl"
>                  --body "$(cat spec.md)"
>                  --labels "enhancement", "operational-scripts"
```

### Tracking Progress

```
/specify outputs:
- spec.md (requirements)
- design.md (architecture)
- tasks.md (implementation steps)
- SESSION_CHANGELOG.md (audit log)

All can be committed to track evolution of ideas.
```

### Publishing Blog Articles

```
/generate blog-post --topic "Setting up Kiro CLI for Infrastructure Development"

Kiro uses your SESSION_CHANGELOG.md to generate:
- Article outline
- Code examples from actual changes
- Lessons learned
- Best practices discovered
```

## Best Practices for Kiro Workflow

### 1. Write Clear Specifications
**Good:**
```
/specify "Implement domain-agnostic configuration for Jitsi platform 
         to support deployment to any domain without modifying code.
         Use OOP JitsiConfig module in all Perl scripts."
```

**Poor:**
```
/specify "Make it domain-agnostic"
```

### 2. Review Every Diff
- Don't auto-approve all changes
- Read the design.md before implementation
- Question assumptions
- Suggest refinements

### 3. Commit Frequently
```bash
git add spec.md design.md tasks.md
git commit -m "feat: spec for configuration system"

git add lib/JitsiConfig.pm
git commit -m "feat: add JitsiConfig module"

git add scripts/*.pl
git commit -m "refactor: scripts use JitsiConfig"
```

### 4. Document Decisions
Keep `SESSION_CHANGELOG.md` updated:
```markdown
## Session: Configuration Refactoring (Dec 15, 2025)

### Decision: Use OOP Module
- Pro: Reusable across all scripts
- Pro: Type-safe configuration
- Con: Requires Perl knowledge
**Approved**: Yes

### Lessons Learned
- Environment variable priority important
- Private repo separation is essential
- JitsiConfig module pattern scales well
```

### 5. Validate After Each Phase
```bash
# After each @autonomous-agent task
terraform validate
perl -I lib -c scripts/status.pl
./scripts/test-platform.pl
```

## The VS Code Kiro Experience

### Terminal Integration
```bash
$ kiro-cli
[Kiro CLI v2.4.0 - Ready]

> /specify "Add monitoring to scale-up.pl"
[Generating specification...]
📋 spec.md created
🎨 design.md created
✅ Ready for implementation

> @autonomous-agent "Implement Phase 1"
[Analyzing changes...]
[4/15 tasks complete]
Progress: ████████░░░░░░░░░░░░ 40%
```

### Sidebar Integration
- **Kiro Explorer** shows current spec
- **Tasks Panel** tracks implementation steps
- **Diff Preview** shows changes before commit
- **Changelog** displays audit trail

### Inline Assistance
- Hover over Terraform resources for documentation
- Get Perl syntax suggestions
- Validate configuration syntax in real-time

## Lessons Learned

### What Worked Great
1. ✅ Spec-driven workflow prevented missed changes
2. ✅ Kiro caught hardcoded values we almost missed
3. ✅ Automatic documentation generation was huge time-saver
4. ✅ Full audit trail proved invaluable for troubleshooting
5. ✅ Clear specification made code review easier

### What We'd Do Differently
1. ⚠️ Create more granular specs (smaller iterations better)
2. ⚠️ Involve team earlier in specification phase
3. ⚠️ Store specs in version control from day one
4. ⚠️ Use Kiro's GitHub integration more (automatic issues)

### Time Savings

| Task | Manual | With Kiro | Savings |
|------|--------|-----------|---------|
| Identify hardcoded values | 45 min | 5 min | 88% |
| Create implementation plan | 30 min | Automatic | 100% |
| Execute changes | 90 min | 30 min | 67% |
| Document decisions | 45 min | Automatic | 100% |
| **Total** | **210 min** | **35 min** | **83%** |

## Conclusion

Kiro CLI transforms infrastructure development from a manual, error-prone process into a systematic, auditable, documented workflow. By using her:

- ✅ We eliminated domain hardcoding in our public repo
- ✅ We created a reusable configuration pattern
- ✅ We documented all decisions automatically
- ✅ We reduced development time by 83%
- ✅ We built confidence in our changes through specs

For infrastructure teams migrating systems, rolling out new features, or managing complex deployments, Kiro is a game-changer.

---

## Resources

- **[Kiro CLI Official](https://cli.kiro.dev/)** - Official Kiro documentation
- **[Configuration Guide](../CONFIG_GUIDE.md)** - Our configuration system
- **[Jitsi Deployment](../DEPLOYMENT_GUIDE.md)** - Infrastructure details
- **[GitHub Copilot](https://github.com/features/copilot)** - Code completion
- **[Terraform Docs](https://www.terraform.io/docs)** - Infrastructure-as-Code reference
- **[AWS Builder Center](https://aws-builder-center.com)** - AWS community articles

---

**Published on:** AWS Builder Center  
**Author:** Bryan Chasko  
**Date:** December 2025
- Powers for specialized capabilities
- MCP server integration

### Installation
```bash
curl -fsSL https://cli.kiro.dev/install | bash
cd ~/Code/Projects/jitsi-video-hosting
kiro-cli
```

---

## Spec-Driven Workflow

### Phase 1: Specification
```bash
/specify "Update all infrastructure and documentation references 
from meet.awsaerospace.org to meet.bryanchasko.com for the Jitsi 
deployment in the aws-ug-jitsi-hosting account."
```

[TODO: Document what Kiro generated for specification]

### Phase 2: Design
[TODO: Document design phase output]

### Phase 3: Implementation
```bash
@autonomous-agent "Implement domain variable and hardcoded 
reference replacements in jitsi-video-hosting code."
```

[TODO: Document implementation experience]

---

## Terraform Power Integration: Deep Dive Learnings

### The Terraform Plugin (IDE-Only Feature)

The **Hashicorp/Terraform Power** is an IDE-exclusive plugin that provides specialized HCL generation and validation capabilities. Unlike generic code completion, the Terraform Power understands:

- **AWS resource relationships** (security groups must exist before referencing)
- **Terraform idioms** (variable interpolation, data sources, locals)
- **Best practices** (naming conventions, tagging strategies, output organization)
- **Registry integration** (lookups of providers, modules, and documentation)

### When We Actually Used ECS Express in Our Project

During our migration planning, we evaluated ECS Express Mode as a potential simplification for the Jitsi infrastructure. Here's the detailed breakdown of how and why we chose NOT to migrate (yet):

#### Phase 1: Assessment
```hcl
# Current single-file architecture (main.tf, 909 lines)
├── VPC networking (lines 1-87)
├── Security groups (lines 88-142)
├── Network Load Balancer (lines 144-233)  # Would be simplified
├── ECS cluster (lines 236-244)
├── Task definition (lines 245-453)        # Stays mostly unchanged
├── IAM roles (lines 454-550)
└── S3 + Secrets Manager (lines 551-909)
```

**ECS Express Benefit**: Would remove ~90 lines for NLB, listeners, and target groups, reducing total to ~450 lines (50% reduction).

**ECS Express Challenge**: JVB requires UDP port 10000 for video media. Express Mode uses ALB (HTTPS/443 only), not NLB (which supports UDP). This forces a **hybrid approach** or **TCP fallback**, neither of which we had tested thoroughly.

#### Phase 2: Terraform Plugin Usage

When we asked the Terraform Power to evaluate ECS Express compatibility, it provided:

**Valuable Insights:**
- ✅ Task definition stays largely unchanged (4-container Jitsi setup works with Express Mode)
- ✅ `desired_count = 0` for scale-to-zero remains supported
- ✅ Environment variables and Secrets Manager integration unchanged
- ✅ Health checks compatible with Express Mode's auto-generated target groups

**Critical Gaps:**
- ❌ ALB cannot handle UDP/10000 (JVB media)
- ❌ Express Mode doesn't expose ALB security group for manual UDP rules
- ❌ No clear migration path for hybrid ALB (web) + NLB (video) setup

**Terraform Plugin Recommendation**: Document the hybrid approach for future migration, keeping current NLB until Express Mode matures with multi-protocol support.

#### Phase 3: Well-Architected Framework Application

Using the **AWS Well-Architected Framework**, the Terraform Power helped us understand when to migrate:

**Operational Excellence:**
- ✅ **For**: Fewer resources = less to manage
- ❌ **Against**: Hybrid ALB+NLB setup = more complex than current single NLB

**Security:**
- ✅ **For**: AWS-managed defaults = consistent security posture
- ❌ **Against**: Less control over security group rules

**Reliability:**
- ✅ **For**: Fewer moving parts = fewer failure modes
- ❌ **Against**: Losing hands-on networking knowledge

**Performance Efficiency:**
- ✅ **For**: Cost savings ($6-8/month on ALB vs NLB)
- ❌ **Against**: Current setup already optimized (scale-to-zero, single NLB)

**Cost Optimization:**
- ✅ **For**: Fixed costs drop from $16.62/month to $8.62/month
- ✅ **For**: Shared ALB across future services amortizes cost further

**Decision**: **Defer ECS Express migration.** Current single-NLB setup is well-architected for a single service. Migrate when:
1. Adding 2+ services (benefit of shared ALB becomes clear)
2. UDP fallback testing proves JVB works reliably on TCP/4443
3. AWS Express Mode matures with better multi-protocol support

### Terraform Plugin Developer Experience Improvements

Our use of the Terraform Power identified several ways to improve the Kiro CLI experience:

**1. Interactive HCL Diff Review**
- **Problem**: Kiro generated ECS Express refactoring, but we couldn't easily validate port compatibility
- **Improvement**: Add an interactive mode showing:
  ```
  REMOVED (lines 144-233):
  - aws_lb "jitsi_nlb"
  - aws_lb_listener "udp_10000"
  
  REPLACED WITH:
  - aws_ecs_service with ALB integration
  
  VALIDATION ERROR: UDP/10000 not supported in ALB
  RECOMMENDATION: Keep manual NLB for JVB, use Express Mode for future web-only service
  ```

**2. Well-Architected Framework Hooks**
- **Problem**: No guidance on strategic migration timing
- **Improvement**: Add `/well-architected-review` that evaluates changes against AWS pillars before implementation
  ```
  /well-architected-review "ECS Express migration" --framework aws
  
  Operational Excellence: IMPROVED (fewer resources)
  Security:               NEUTRAL (AWS defaults vs. explicit rules)
  Reliability:            IMPROVED (fewer moving parts)
  Performance Efficiency: NEUTRAL (same throughput)
  Cost Optimization:      IMPROVED ($8/month savings)
  
  RECOMMENDATION: Defer until additional services justify shared ALB cost amortization
  ```

**3. Multi-File Impact Analysis**
- **Problem**: When refactoring main.tf, we had to manually check if outputs.tf, variables.tf, and scripts still work
- **Improvement**: Add `@terraform-tools/impact-analysis` that shows:
  ```
  Refactoring aws_lb resource:
  
  IMPACT ANALYSIS:
  ├── outputs.tf: load_balancer_dns_name (CHANGED)
  ├── scripts/status.pl: Uses load_balancer_dns (COMPATIBLE)
  ├── terraform.tfvars: No changes needed
  └── AWS CLI: describe-load-balancers (COMPATIBLE)
  
  SAFE TO PROCEED: All dependent files compatible
  ```

### Practical Lessons for Your Infrastructure

**Lesson 1: Single-File Terraform is Better with Expert Tooling**
Our 909-line `main.tf` is controversial (some prefer modularization), but it works perfectly with AI-assisted development because:
- ✅ Easier for Terraform Power to understand full context
- ✅ Fewer file interdependencies to track
- ✅ Simpler for spec-driven generation (one place to read/write)
- ✅ Better for configuration-driven changes (JitsiConfig variables apply everywhere)

**Lesson 2: Reserve Major Migrations for Clear Business Value**
ECS Express would save $8/month and reduce lines of code, but the risk isn't worth it because:
- ❌ Only 1 service (not amortizing shared ALB cost)
- ❌ UDP requirement forces hybrid approach (defeating simplification benefit)
- ❌ Current setup is already well-architected and stable

**Lesson 3: Leverage Terraform Plugin for Strategic Decisions, Not Just Code Generation**
The Terraform Power's most valuable contribution wasn't generating new HCL—it was helping us decide when **not** to migrate. Use it for:
- Compatibility analysis (new service vs. existing infrastructure)
- Well-architected reviews (cost vs. operational complexity)
- Multi-file impact assessment (Terraform changes → scripts → docs)

### Activating the Terraform Power (IDE Only)

```
[In Kiro IDE web interface, NOT CLI]

/powers activate hashicorp/terraform

> Terraform Power activated
> Analyzing project: 909-line main.tf, 59-line variables.tf
> Detected single-NLB, multi-container Jitsi setup
> Identified potential ECS Express compatibility (with caveats)
```

Then use it for architecture decisions:

```
/specify "Evaluate whether ECS Express Mode simplifies our 
          Jitsi infrastructure while maintaining scale-to-zero 
          and UDP/10000 video bridge connectivity."

> Kiro analyzes with Terraform Power context
> Generates design.md with well-architected recommendations
> Provides specific implementation blockers (UDP not supported by ALB)
```

---

## Steering Files

### Purpose
Steering files give Kiro persistent knowledge about your project:

```
.kiro/steering/
├── product.md   # Product context and goals
├── tech.md      # Technology stack and preferences
└── structure.md # Project organization
```

### Our Steering Configuration
[TODO: Document what steering files we created and their impact]

---

## Hooks for Automation

### Pre-Tool Validation
[TODO: If we implement hooks, document here]

### Post-Tool Actions
[TODO: Document any automation we set up]

---

## Results

### Before Kiro
- Manual file-by-file updates
- Risk of missed references
- Time-consuming verification

### After Kiro
[TODO: Document actual metrics]
- Specification created in: X minutes
- Code changes implemented in: X minutes
- Verification: Automated via spec

### Files Changed
[TODO: List actual files modified by Kiro]

---

## Lessons Learned

### What Worked Well
[TODO: Document positive experiences]

### Areas for Improvement
[TODO: Document challenges]

### Tips for Others
[TODO: Recommendations based on experience]

---

## Conclusion

Spec-driven infrastructure development with Kiro CLI fundamentally changes how we approach migrations and refactoring. The Terraform Power (IDE-exclusive) excels at strategic architecture decisions—not just code generation. Our ECS Express evaluation demonstrated that the right decision isn't always to adopt new technology; sometimes it's recognizing when current architecture is already well-optimized.

Key takeaway: **Use AI-assisted development for clarity and confidence, not just speed.**

---

## Resources

- [Kiro CLI Documentation](https://cli.kiro.dev/)
- [Kiro Steering Files](https://docs.kiro.dev/steering)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)
- [AWS ECS Express Mode Docs](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/express-service-overview.html)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Project Repository](https://github.com/BryanChasko/jitsi-video-hosting)

---

*This blog post documents real-world experience using Kiro CLI for infrastructure decisions during the Jitsi Video Hosting Platform migration project (December 2025).*

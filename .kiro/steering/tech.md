# Technology Stack - Jitsi Video Hosting Platform

## Infrastructure
- **Cloud Provider**: AWS (ECS Fargate, NLB, S3, Secrets Manager)
- **IaC**: Terraform (single-file architecture in `main.tf`)
- **Container Platform**: ECS Fargate with scale-to-zero capability
- **Load Balancing**: Network Load Balancer with TLS termination

## Application Stack
- **Video Platform**: Jitsi Meet (4-container stack)
  - jitsi-web: Frontend (nginx)
  - prosody: XMPP server
  - jicofo: Conference focus
  - jvb: Video bridge (AWS NAT traversal configured)

## Developer Preferences

### Languages (Priority Order)
1. **Rust** - Preferred for new tooling and performance-critical code
2. **Perl** - Required for automation scripts (not shell scripts)
3. **HCL** - Terraform configurations
4. **Markdown** - All documentation

### Tools
- **Editor**: VIM (terminal), Kiro CLI (AI-assisted)
- **Terminal**: zsh on macOS
- **Version Control**: Git + GitHub
- **AI Tooling**: Kiro CLI, GitHub Copilot, MCP servers

### Philosophy
- **Tooling > Creating**: Prefer implementing/integrating tools over building from scratch
- **Agent-to-Agent**: Interest in MCP tooling and autonomous agent workflows
- **Scale-to-Zero**: All infrastructure must support powering down when idle

## Data Storage
- **Documentation**: Markdown format
- **Data**: Vector format compatible with Amazon S3 Vectors
- **State**: Terraform state (local, future: S3 backend)
- **Secrets**: AWS Secrets Manager (never hardcoded)

## CI/CD
- **Current**: Manual Terraform apply with `tfplan` safety
- **Future**: Kiro CLI spec-driven deployment with ECS Express

## Monitoring
- **Logs**: CloudWatch Log Groups
- **Metrics**: CloudWatch Metrics (CPU, memory, participant count)
- **Alerts**: SNS notifications for service health

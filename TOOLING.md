# Development Tooling & AI-Assisted Workflow

This document outlines the development tools and AI-assisted workflow used to build the Jitsi video hosting platform.

## AI-Assisted Development with Amazon Q

This project was built using **Amazon Q Developer** as the primary AI assistant, demonstrating modern AI-assisted infrastructure development practices.

### Amazon Q IDE Integration

**Setup**: Amazon Q plugin installed in IDE for real-time code assistance
- **Code Generation**: Infrastructure-as-Code (Terraform) generation
- **Documentation**: Automated documentation generation and updates
- **Debugging**: Real-time error analysis and resolution
- **Best Practices**: AWS security and architecture recommendations

### Amazon Q GitHub Integration

**GitHub Integration**: Connected Amazon Q to GitHub repository for automated development workflows

#### Slash Commands Used:
- `/q dev` - Automatically implement features and bug fixes via pull requests (use in **issues**)
- `/q review` - Automated code reviews with security and quality feedback (use in **PRs**)
- `/q help` - Access Amazon Q Developer documentation and features

#### Required Labels:
- **"Amazon Q development agent"** - Triggers feature development from issues
- **"Amazon Q transform agent"** - Triggers Java code transformation

#### Correct Workflow:
1. **Create GitHub Issue** with requirements and `/q dev` command
2. **Add "Amazon Q development agent" label** to trigger implementation
3. **Amazon Q creates new PR** with complete implementation
4. **Amazon Q automatically reviews** the PR for code quality
5. **Use `/q review`** for additional reviews or `/q` for questions
6. **Merge PR** after review and testing

## Command Line Tools

### GitHub CLI (`gh`)
Used for repository management and issue creation:

```bash
# Create issues with AI automation
gh issue create --title "Feature Title" --body "Description\n\n/q dev" --assignee "bryanChasko"

# Repository management
gh repo view
gh pr list
```

### AWS CLI with SSO
Multi-account AWS management with Identity Center:

```bash
# Infrastructure account (us-west-2)
aws sso login --profile jitsi-dev

# DNS/Domain account (us-east-2) 
aws sso login --profile aerospaceug-admin
```

### Terraform Infrastructure-as-Code

**Primary Tool**: Terraform for complete AWS infrastructure management

#### Project Architecture
- **Single Configuration**: All infrastructure defined in `main.tf`
- **Multi-Account**: Infrastructure (668383289911) + DNS (211125425201)
- **Scale-to-Zero**: ECS service with `desired_count = 0` for cost control
- **Security First**: IAM roles, SSL certificates, encrypted storage

#### Key Terraform Resources
```hcl
# Core Infrastructure
resource "aws_vpc" "main"                    # Custom VPC (10.0.0.0/16)
resource "aws_subnet" "public"                # Multi-AZ public subnets
resource "aws_security_group" "jitsi"         # Ports 443/TCP, 10000/UDP
resource "aws_lb" "jitsi"                     # Network Load Balancer
resource "aws_lb_listener" "jitsi_https_tls"  # TLS listener with certificate

# Container Platform
resource "aws_ecs_cluster" "jitsi"            # Fargate cluster
resource "aws_ecs_service" "jitsi"            # Scale-to-zero service
resource "aws_ecs_task_definition" "jitsi"    # Jitsi container config

# Storage & Security
resource "aws_s3_bucket" "jitsi_recordings"   # Video storage
resource "aws_iam_role" "ecs_task"            # Least privilege access
resource "aws_cloudwatch_log_group" "jitsi"   # Container logs
```

#### Terraform Workflow
```bash
# Plan with output file (recommended)
terraform plan -out=tfplan
terraform apply tfplan

# Multi-profile management
terraform plan -out=tfplan                    # Infrastructure account
aws route53 change-resource-record-sets ...   # DNS account

# State management
terraform state list
terraform state show aws_lb.jitsi
```

#### Cross-Account Challenges Solved
1. **SSL Certificate**: Manual DNS validation across accounts
2. **DNS Management**: Separate AWS profiles for different accounts
3. **Resource Dependencies**: Careful ordering of cross-account resources
4. **State Isolation**: Infrastructure state separate from DNS state

#### AI-Assisted Terraform Development
- **Code Generation**: Amazon Q generated initial resource configurations
- **Best Practices**: AI recommended security groups, IAM policies, encryption
- **Error Resolution**: Real-time debugging of Terraform syntax and logic
- **Resource Optimization**: AI suggested cost-effective resource sizing
- **Documentation**: Automated generation of resource descriptions and tags

## Development Workflow

### 1. AI-Assisted Planning
- Amazon Q analyzed requirements and suggested architecture
- Generated initial Terraform configurations
- Provided security and best practices guidance

### 2. Iterative Development
- Real-time code assistance during development
- Automated error resolution and debugging
- Documentation generation and updates

### 3. GitHub Integration
- Created issues with `/q dev` for automated implementation
- Amazon Q generated pull requests with complete solutions
- Automated code reviews and security analysis

### 4. Cross-Account Management
- AI-assisted AWS profile configuration
- Automated DNS and SSL certificate management
- Multi-region resource coordination

## Key Benefits Demonstrated

### Development Speed
- **Infrastructure Generation**: Complete AWS infrastructure in hours vs. days
- **Error Resolution**: Real-time debugging and fixes
- **Documentation**: Automated generation and maintenance

### Code Quality
- **Security**: Built-in AWS security best practices
- **Architecture**: AI-recommended patterns and structures
- **Consistency**: Standardized code formatting and structure
- **Terraform Best Practices**: Proper resource naming, tagging, and dependencies
- **Infrastructure Validation**: AI-assisted plan review and error detection

### Operational Excellence
- **Automation**: Fully automated deployment pipeline
- **Monitoring**: AI-suggested CloudWatch configurations
- **Cost Optimization**: Scale-to-zero architecture recommendations

## Lessons Learned

### AI Collaboration Best Practices
1. **Clear Requirements**: Detailed project goals enable better AI assistance
2. **Proper Labels**: Use "Amazon Q development agent" label for `/q dev` to work
3. **Issue-Based Development**: Start with GitHub issues, not PRs, for implementation
4. **PR-Based Review**: Use pull requests for code review and iteration
5. **Iterative Feedback**: Continuous interaction improves AI understanding
6. **Context Sharing**: Providing full project context enhances AI recommendations
7. **Tool Integration**: Combining multiple AI tools (IDE + GitHub) amplifies benefits

### Technical Insights
1. **Cross-Account Complexity**: AI helped navigate AWS multi-account challenges
2. **Security First**: AI consistently recommended security best practices
3. **Terraform Expertise**: AI provided advanced Terraform patterns and resource configurations
4. **State Management**: AI guided proper Terraform state handling and resource imports
5. **Documentation**: AI-generated docs require human review but save significant time
6. **Error Patterns**: AI quickly identifies and resolves common infrastructure issues

## Future Enhancements

### Lambda Function Standards
**Architecture**: AWS Graviton (arm64) for cost efficiency  
**Language Preference**: Rust > Python > Go > Others  
**Runtimes**: 
- `provided.al2023` (Rust custom runtime)
- `python3.12` on arm64
- `go1.x` on arm64

### Planned AI Integrations
- **Terraform Testing**: AI-generated Terratest suites for infrastructure validation
- **Performance Optimization**: AI-driven resource optimization and right-sizing
- **Security Scanning**: Continuous AI-powered security analysis with Checkov integration
- **Cost Management**: AI-assisted cost optimization recommendations
- **State Management**: AI-powered Terraform state analysis and cleanup
- **Module Development**: AI-generated reusable Terraform modules
- **Lambda Functions**: AI-generated Rust/Python functions on Graviton processors

## Troubleshooting Amazon Q GitHub Integration

### `/q dev` Not Working?
1. **Check Labels**: Ensure "Amazon Q development agent" label exists and is applied to issue
2. **Use in Issues**: `/q dev` works in GitHub **issues**, not pull requests
3. **Wait for Processing**: Amazon Q may take a few minutes to create the PR
4. **Check Permissions**: Ensure Amazon Q app has repository access

### `/q review` Not Working?
1. **Use in PRs**: `/q review` works in **pull requests**, not issues
2. **Automatic Reviews**: Amazon Q automatically reviews new/reopened PRs
3. **Manual Trigger**: Use `/q review` for additional reviews in existing PRs

### Key Differences:
- **Issues + Label**: Triggers implementation (`/q dev` + "Amazon Q development agent" label)
- **Pull Requests**: Triggers review (`/q review` or automatic)

This project serves as a reference implementation for AI-assisted infrastructure development using Amazon Q Developer and modern DevOps practices.
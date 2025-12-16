# Kiro CLI Guide for Jitsi Platform

**Status**: Living Document
**Context**: Jitsi Video Hosting Migration Project

This guide distills the essential Kiro CLI concepts, Powers, and workflows needed for our infrastructure refactoring and migration to `meet.bryanchasko.com`.

---

## 1. Getting Started

### Installation
```bash
curl -fsSL https://cli.kiro.dev/install | bash
```

### Starting a Session
Navigate to the project root and launch Kiro:
```bash
cd ~/Code/Projects/jitsi-video-hosting
kiro-cli
```

---

## 2. Kiro Powers & AWS Services

**Kiro Powers** are expertise modules (MCP + steering files) that give Kiro agents specialized knowledge. **AWS Services** (like ECS Express) are infrastructure capabilities you'll be migrating to.

### Powers Used in This Project

#### `hashicorp/terraform` (Active)
- **Purpose**: Authoring, validating, and operating Terraform with spec-driven assistance.
- **Capabilities**:
  - HCL generation and plan scaffolding from specifications.
  - Registry lookups (providers, modules) and documentation retrieval.
  - Validation hooks (`terraform fmt`, `terraform validate`).
  - Workspace/run management for HCP Terraform (optional).
- **Activation**: `/powers activate hashicorp/terraform`
- **Configuration**: Optional `TFE_TOKEN` for HCP Terraform features; local CLI works without it.
- **Use Case**: Generate refactored Terraform that adopts ECS Express features while preserving scale-to-zero and health checks.

---

## 3. AWS ECS Express Mode (Target Architecture)

**What is ECS Express?** A simplified AWS ECS service launched in November 2025 that auto-manages NLB, listeners, target groups, and networking. Instead of defining these resources manually in Terraform, you declare them via service configuration.

**Why migrate?** 
- ~55% fewer Terraform lines (removes manual NLB/listener/target-group blocks)
- Same cost model (fixed + variable)
- Scale-to-zero preserved (`desired_count = 0`)
- Simpler to understand and maintain

**Kiro's role:** The `hashicorp/terraform` Power will help us refactor `main.tf` to use ECS Express patterns while preserving our domain-agnostic config and operational scripts.

---

## 4. MCP Servers (Model Context Protocol)

**Concept**: MCP servers connect Kiro to external systems (AWS, GitHub, Databases) to perform actions.

### Key MCP Servers

#### `aws-tools`
- **Purpose**: Manage AWS resources directly.
- **Usage**: Deploying stacks, querying resource status.

#### `filesystem` (Built-in)
- **Purpose**: Read/write files in the workspace.

---

## 5. Spec-Driven Development Workflow

We utilize Kiro's structured workflow to ensure quality and traceability during the migration.

### Step 1: Specification (Requirements)
- **Action**: Enter a natural language prompt describing the change.
- **Example**: `/specify "Update all infrastructure to use meet.bryanchasko.com..."`
- **Output**: Kiro generates a **Requirements Document** with user stories and acceptance criteria.
- **User Action**: Refine requirements in chat, then click **"Move to design phase"**.

### Step 2: Design
- **Output**: Kiro generates a `design.md` file.
- **Content**: Architecture changes, error handling strategies, testing plans.
- **User Action**: Review `design.md`, request modifications if needed, then click **"Move to implementation plan"**.

### Step 3: Implementation Plan
- **Output**: Kiro generates a `tasks.md` file containing a checklist of steps.
- **User Action**: Click **"Start task"** on the first item.

### Step 4: Execution & Testing
- **Action**: Kiro writes code and runs commands.
- **Safety**: Kiro asks permission before installing dependencies or running tests.
- **Verification**: Review code DIFFs before they are applied.

### Step 5: Terraform Power Usage
- **Activate Power**:
  ```
  /powers activate hashicorp/terraform
  ```
- **Generate HCL from Spec**:
  ```
  /specify "Collapse manual NLB resources by adopting ECS Express-managed LB; preserve desired_count=0 and health checks"
  ```
  Kiro proposes HCL changes and shows diffs.
- **Validate & Format**:
  ```
  terraform fmt
  terraform validate
  ```
- **Plan & Apply (Safety First)**:
  ```
  terraform plan -out=tfplan
  terraform apply tfplan
  ```

---

## 6. Project Steering

Steering files provide persistent context to Kiro agents. We have established the following in `.kiro/steering/`:

- **`product.md`**: Product goals (Scale-to-Zero, Cost Efficiency).
- **`tech.md`**: Stack preferences (Rust, Perl scripts, VIM, Terraform).
- **`structure.md`**: Repo layout (Public/Private split, Single-file `main.tf`).

**Global vs. Workspace**: These are workspace-level steering files. Global steering lives in `~/.kiro/steering/`.

---

## 7. Hooks

**Concept**: Automated actions triggered by events (e.g., `preToolUse`, `postToolUse`).

**Potential Use Cases**:
- **Security**: Prevent committing secrets to public repo.
- **Logging**: Auto-update `SESSION_CHANGELOG.md` after file edits.
- **Formatting**: Run `terraform fmt` after `write` operations.

---

## 8. S3 Vectors & Knowledge

We structure our documentation (`SESSION_CHANGELOG.md`) to be compatible with **Amazon S3 Vectors**.
- **Goal**: Store project history as vector embeddings.
- **Benefit**: Semantic search across past decisions and changes using RAG (Retrieval-Augmented Generation).

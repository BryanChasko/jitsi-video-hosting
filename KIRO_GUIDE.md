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

## 2. Kiro Powers

**Concept**: Powers are specialized capability packages that add context, tools (MCP), steering, and hooks to Kiro agents on-demand. They prevent context overload by only loading what's needed.

### Powers Used in This Project

#### `aws-labs/ecs-express` (Active)
- **Purpose**: Simplified ECS Fargate deployment with "Express Mode" defaults.
- **Capabilities**: Automatic NLB provisioning, scale-to-zero patterns, simplified task definitions.
- **Activation**: `/powers activate aws-labs/ecs-express`

#### `hashicorp/terraform` (Reference)
- **Purpose**: Infrastructure as Code management.
- **Capabilities**:
  - Access Terraform Registry APIs (providers, modules).
  - Manage HCP Terraform workspaces and runs.
  - Search provider docs (`search_providers`, `get_provider_details`).
- **Configuration**: Requires `TFE_TOKEN` for HCP features.

---

## 3. MCP Servers (Model Context Protocol)

**Concept**: MCP servers connect Kiro to external systems (AWS, GitHub, Databases) to perform actions.

### Key MCP Servers

#### `aws-tools`
- **Purpose**: Manage AWS resources directly.
- **Usage**: Deploying stacks, querying resource status.

#### `filesystem` (Built-in)
- **Purpose**: Read/write files in the workspace.

---

## 4. Spec-Driven Development Workflow

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

---

## 5. Project Steering

Steering files provide persistent context to Kiro agents. We have established the following in `.kiro/steering/`:

- **`product.md`**: Product goals (Scale-to-Zero, Cost Efficiency).
- **`tech.md`**: Stack preferences (Rust, Perl scripts, VIM, Terraform).
- **`structure.md`**: Repo layout (Public/Private split, Single-file `main.tf`).

**Global vs. Workspace**: These are workspace-level steering files. Global steering lives in `~/.kiro/steering/`.

---

## 6. Hooks

**Concept**: Automated actions triggered by events (e.g., `preToolUse`, `postToolUse`).

**Potential Use Cases**:
- **Security**: Prevent committing secrets to public repo.
- **Logging**: Auto-update `SESSION_CHANGELOG.md` after file edits.
- **Formatting**: Run `terraform fmt` after `write` operations.

---

## 7. S3 Vectors & Knowledge

We structure our documentation (`SESSION_CHANGELOG.md`) to be compatible with **Amazon S3 Vectors**.
- **Goal**: Store project history as vector embeddings.
- **Benefit**: Semantic search across past decisions and changes using RAG (Retrieval-Augmented Generation).

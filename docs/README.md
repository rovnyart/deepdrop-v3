# DeepDrop Documentation Index

DeepDrop is planned as a native macOS PostgreSQL client with a fast, calm interface and optional AI assistance.

This documentation pack is intentionally AI-friendly: each document is scoped, explicit about acceptance criteria, and written so future implementation prompts can reference a single file or section.

## Documents

- [Product Requirements](./prd.md): product vision, target users, feature requirements, non-goals, success metrics.
- [UX and Interaction Design](./ux-design.md): app shell, connection flow, query editor behavior, result grid, settings, visual principles.
- [Technical Architecture](./technical-architecture.md): proposed Swift/macOS architecture, data flow, dependencies, modules, persistence, testing.
- [AI System Design](./ai-system-design.md): OpenAI integration, privacy, tool boundaries, mutation safety, prompts, structured outputs, auditability.
- [Implementation Roadmap](./implementation-roadmap.md): phased, testable build plan for getting from empty project to MVP and beyond.

## Product Principles

1. Native speed first. AI must never make the database client feel slower or less predictable.
2. Minimal surface, deep power. Prefer progressive disclosure over dense toolbars.
3. SQL remains first-class. AI assists the user, but the user stays in control.
4. Safety is a feature. Destructive queries, credential handling, and schema/data sharing must be explicit.
5. Every milestone must leave the app shippable, testable, and understandable.


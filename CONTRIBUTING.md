# Contributing Guide

Thank you for your interest in contributing to this project.

## Getting Started

1. Fork the repository
2. Clone your fork
3. Install dependencies: `cd app && pnpm install`
4. Start LocalStack: `make localstack-up`
5. Create a feature branch: `git checkout -b feature/my-feature`

## Development Workflow

### Code Style

- TypeScript for application code
- HCL (HashiCorp Configuration Language) for Terraform
- Follow existing patterns and conventions

### Commit Messages

Use conventional commits:

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`

Examples:
```
feat(api): add order cancellation endpoint
fix(worker): handle empty SQS messages gracefully
docs(readme): update architecture diagram
```

### Pull Requests

1. Update documentation if needed
2. Add tests for new features
3. Ensure all tests pass
4. Run `terraform fmt -recursive`
5. Run `cd app && pnpm lint`
6. Create PR with clear description

## Testing

### Unit Tests
```bash
cd app && pnpm test
```

### Integration Tests
```bash
make localstack-up
cd app && pnpm test:integration
```

### Terraform Validation
```bash
make validate-modules
```

## Terraform Guidelines

### Module Structure

```
modules/<name>/
├── main.tf           # Main resources
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── <resource>.tf     # Resource-specific files
└── README.md         # Module documentation
```

### Naming Conventions

- Resources: `<project>-<environment>-<region>-<resource>`
- Variables: `snake_case`
- Outputs: `snake_case`
- Locals: `snake_case`

### Best Practices

- Use variables for all configurable values
- Add descriptions to all variables and outputs
- Use `count` or `for_each` for conditional resources
- Tag all resources consistently
- Use data sources instead of hardcoding ARNs

## Application Guidelines

### TypeScript

- Strict mode enabled
- No `any` types
- Use Zod for validation
- Follow functional patterns where appropriate

### API Design

- RESTful endpoints
- Consistent error responses
- OpenAPI documentation
- Rate limiting on all endpoints

### Error Handling

- Use custom error classes
- Log errors with context
- Never expose internal errors to clients

## Architecture Decisions

For significant changes, create an ADR:

```markdown
# ADR-XXX: Title

## Status
Proposed | Accepted | Deprecated | Superseded

## Context
Why is this decision needed?

## Decision
What is the change being proposed?

## Consequences
What are the trade-offs?
```

## Code Review Checklist

- [ ] Code follows project conventions
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No security vulnerabilities
- [ ] No breaking changes (or documented)
- [ ] Performance impact considered

## Questions?

Open an issue for any questions or suggestions.

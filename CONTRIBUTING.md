# Contributing to DogfyDiet Platform

Thank you for your interest in contributing to the DogfyDiet Platform! This document provides guidelines and instructions for contributing to this project.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Process](#development-process)
- [Pull Request Process](#pull-request-process)
- [Infrastructure Changes](#infrastructure-changes)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Documentation](#documentation)
- [Security](#security)

## 📜 Code of Conduct

We are committed to providing a welcoming and inspiring community for all. Please read and follow our Code of Conduct:

- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on what is best for the community
- Show empathy towards other community members

## 🚀 Getting Started

### Prerequisites

1. **Fork the Repository**
   ```bash
   # Fork via GitHub UI, then clone your fork
   git clone https://github.com/YOUR_USERNAME/dogfydiet-platform.git
   cd dogfydiet-platform
   ```

2. **Set Up Development Environment**
   ```bash
   # Install required tools
   - terraform >= 1.5.0
   - gcloud CLI
   - kubectl
   - helm >= 3.12.0
   - node.js >= 18.0.0
   - docker
   ```

3. **Configure Git**
   ```bash
   git config user.name "Your Name"
   git config user.email "your.email@example.com"
   ```

## 💻 Development Process

### 1. Branch Naming Convention

Create branches following this pattern:
- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `refactor/description` - Code refactoring
- `test/description` - Test additions/updates
- `chore/description` - Maintenance tasks

Example:
```bash
git checkout -b feature/add-redis-cache
```

### 2. Commit Message Format

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Test additions/modifications
- `chore`: Maintenance tasks
- `perf`: Performance improvements
- `ci`: CI/CD changes

Examples:
```bash
feat(api): add rate limiting to microservice-1

- Implement rate limiting middleware
- Add configuration for rate limits
- Update documentation

Closes #123
```

### 3. Development Workflow

1. **Create a Feature Branch**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/your-feature
   ```

2. **Make Changes**
   - Write clean, documented code
   - Follow existing patterns and conventions
   - Add tests for new functionality

3. **Test Locally**
   ```bash
   # Run application tests
   cd applications/microservice-1
   npm test
   
   # Validate Terraform
   cd terraform/environments/dev
   terraform fmt -recursive
   terraform validate
   ```

4. **Commit Changes**
   ```bash
   git add .
   git commit -m "feat(scope): description"
   ```

5. **Push and Create PR**
   ```bash
   git push origin feature/your-feature
   ```

## 🔄 Pull Request Process

### 1. PR Requirements

Before submitting a PR, ensure:

- [ ] Code follows project coding standards
- [ ] All tests pass
- [ ] Documentation is updated
- [ ] Terraform is formatted (`terraform fmt`)
- [ ] No sensitive data is committed
- [ ] PR has a clear description
- [ ] Related issues are linked

### 2. PR Template

When creating a PR, use this template:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update
- [ ] Infrastructure change

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] My code follows the project style guidelines
- [ ] I have performed a self-review
- [ ] I have commented my code where necessary
- [ ] I have updated the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix/feature works
- [ ] New and existing unit tests pass locally

## Related Issues
Closes #(issue number)

## Screenshots (if applicable)
```

### 3. Review Process

1. **Automated Checks**
   - GitHub Actions will run automatically
   - All checks must pass before review

2. **Code Review**
   - At least one maintainer approval required
   - Address all feedback constructively
   - Re-request review after changes

3. **Merge Requirements**
   - All CI checks pass
   - Approved by maintainer
   - No merge conflicts
   - Up to date with main branch

## 🏗️ Infrastructure Changes

### Special Requirements for Terraform

1. **Planning Phase**
   - All Terraform changes trigger a plan in PR
   - Review the plan output carefully
   - Check for unintended changes

2. **Approval Process**
   - Infrastructure changes require senior engineer approval
   - Cost estimates should be reviewed
   - Security scan must pass

3. **Testing**
   ```bash
   # Format check
   terraform fmt -check -recursive
   
   # Validate
   terraform validate
   
   # Plan
   terraform plan
   ```

4. **Documentation**
   - Update module documentation
   - Document any new variables
   - Update architecture diagrams if needed

## 📏 Coding Standards

### JavaScript/Node.js

- Use ESLint configuration
- Follow Airbnb style guide
- Use async/await over callbacks
- Proper error handling

### Terraform

- Use meaningful resource names
- Group related resources
- Comment complex logic
- Use consistent formatting

### Vue.js

- Use Composition API
- Follow Vue style guide
- Component names in PascalCase
- Props validation required

## 🧪 Testing Requirements

### Unit Tests
- Minimum 80% code coverage
- Test edge cases
- Mock external dependencies

### Integration Tests
- Test API endpoints
- Verify database operations
- Test message queue interactions

### Infrastructure Tests
- Validate Terraform plans
- Test module inputs/outputs
- Verify security policies

## 📚 Documentation

### Code Documentation
- JSDoc for JavaScript functions
- Comments for complex logic
- README for each module

### API Documentation
- Update OpenAPI/Swagger specs
- Document all endpoints
- Include request/response examples

### Architecture Documentation
- Update diagrams for significant changes
- Document design decisions
- Keep ADRs up to date

## 🔐 Security

### Security Guidelines

1. **Never Commit Secrets**
   - No API keys, passwords, or tokens
   - Use environment variables
   - Utilize secret management

2. **Dependency Management**
   - Keep dependencies updated
   - Run `npm audit` regularly
   - Address vulnerabilities promptly

3. **Code Security**
   - Validate all inputs
   - Sanitize user data
   - Follow OWASP guidelines

### Reporting Security Issues

For security vulnerabilities, please email security@dogfydiet.com instead of creating a public issue.

## 🎯 Areas for Contribution

We welcome contributions in these areas:

1. **Features**
   - Performance optimizations
   - New API endpoints
   - UI/UX improvements

2. **Infrastructure**
   - Cost optimization
   - Security hardening
   - Monitoring improvements

3. **Documentation**
   - API documentation
   - Deployment guides
   - Architecture diagrams

4. **Testing**
   - Increase test coverage
   - Add integration tests
   - Performance testing

## 🤝 Getting Help

- Create an issue for bugs/features
- Join our Slack channel: [#dogfydiet-dev]
- Email: contributors@dogfydiet.com

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to DogfyDiet Platform! 🐕❤️
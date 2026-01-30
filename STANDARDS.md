# Standards

Coding conventions and technical guidelines for all VirtualVenues repositories.

## Code Style

### Naming Conventions

- **Files**: kebab-case (e.g., `user-service.ts`)
- **Classes**: PascalCase (e.g., `UserService`)
- **Functions**: camelCase (e.g., `getUserById`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_ATTENDEES`)
- **Variables**: camelCase (e.g., `currentUser`)

### Git Conventions

#### Branch Naming
- `feature/` - New features
- `fix/` - Bug fixes
- `refactor/` - Code refactoring
- `docs/` - Documentation updates

#### Commit Messages
Use conventional commits format:
```
type(scope): description

[optional body]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

## Documentation

- All public APIs must be documented
- README required in each repository
- Inline comments for complex logic only

## Testing

- Unit tests required for business logic
- Integration tests for API endpoints
- Test file naming: `*.test.ts` or `*.spec.ts`

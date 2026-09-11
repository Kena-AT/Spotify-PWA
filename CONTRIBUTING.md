# Contributing to Spotify PWA Wrapper

Thank you for your interest in contributing to Spotify PWA Wrapper! We welcome community contributions, bug fixes, and feature additions.

---

## Getting Started

1. **Fork the Repository**: Create your own copy of the repository on GitHub.
2. **Clone Locally**:
   ```bash
   git clone https://github.com/Kena-AT/Spotify-PWA.git
   cd Spotify-PWA/spotify_pwa
   ```
3. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

---

## Development Guidelines

### Code Formatting & Analysis
Before submitting a Pull Request, ensure your code passes static analysis and formatting checks:

```bash
# Format Dart code
dart format .

# Run static analyzer
flutter analyze
```

### Commit Message Conventions
Use clear, descriptive commit messages following Conventional Commits format:
- `feat: add deep link handler`
- `fix: resolve background service notification crash`
- `docs: update store listing specification`

---

## Pull Request Workflow

1. Create a feature branch (`git checkout -b feature/my-new-feature`).
2. Implement changes with clean, well-documented code.
3. Run `flutter analyze` and `flutter test`.
4. Push your branch (`git push origin feature/my-new-feature`).
5. Open a Pull Request on GitHub detailing your changes.

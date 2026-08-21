# Push preferred VS Code-formatted code to GitHub
git push

# Check for errors, warnings, and lints
flutter analyze

# Format code for pub.dev quality checks
dart format .

# Validate the package before publishing
flutter pub publish --dry-run

# Publish to pub.dev
flutter pub publish

# Restore your preferred GitHub formatting
git restore .
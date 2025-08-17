# MovingBox Changelog

All notable changes to the MovingBox iOS app will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive Claude Code configuration system
- Enhanced project documentation and development guidelines
- Custom slash commands for common development tasks
- Multi-Claude workflow strategies for different development roles

### Changed
- Enhanced root-level CLAUDE.md with comprehensive development guidance
- Added directory-specific CLAUDE.md files for Views, Models, and Services
- Improved development workflow documentation

### Developer Experience
- Added `.claude/commands/` directory with iOS-specific development commands
- Created `.claude/settings.json` for optimized Claude Code tool configuration
- Added `plan.md` for structured task planning and analysis
- Enhanced testing and build process documentation

---

## Changelog Guidelines

### Types of Changes
- **Added** for new features
- **Changed** for changes in existing functionality  
- **Deprecated** for soon-to-be removed features
- **Removed** for now removed features
- **Fixed** for any bug fixes
- **Security** for vulnerability fixes
- **Developer Experience** for improvements to development workflow

### Version Numbering
- **Major Version** (X.0.0): Breaking changes or significant new features
- **Minor Version** (X.Y.0): New features, backwards compatible
- **Patch Version** (X.Y.Z): Bug fixes, backwards compatible

### Entry Format
Each entry should include:
- **Date** of release
- **Version number** following semantic versioning
- **Clear description** of changes organized by type
- **Migration notes** for breaking changes (if applicable)

### Example Entry Structure
```markdown
## [1.2.0] - 2024-01-15

### Added
- New AI-powered bulk photo analysis feature
- Support for custom inventory categories
- Export functionality for insurance claims

### Changed
- Improved image compression algorithm for better storage efficiency
- Enhanced navigation flow for item creation
- Updated onboarding experience with new tutorial steps

### Fixed
- Resolved crash when importing large photo collections
- Fixed UI layout issues on iPad in landscape mode
- Corrected sync conflicts with CloudKit data

### Security
- Updated API authentication to use more secure token format
- Improved data validation for user inputs

### Developer Experience
- Added comprehensive unit tests for new features
- Improved error logging and debugging capabilities
- Enhanced documentation for new developers
```

### Maintenance Notes
- Update this file with every release
- Include both user-facing and developer-facing changes
- Link to relevant GitHub issues or pull requests when applicable
- Keep entries concise but informative
- Archive older versions to keep file manageable

### Related Resources
- **GitHub Releases**: Detailed release notes with assets
- **App Store Release Notes**: User-friendly change descriptions
- **Technical Documentation**: Detailed implementation notes
- **Migration Guides**: For breaking changes or major updates
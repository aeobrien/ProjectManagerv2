# 8. Markdown Import → Onboarding

**Entry point:** SettingsView → Import section → MigrationView

**Recent change:** Import no longer uses AI directly. The importer just reads `.md` files and extracts the project name from the first `# heading`. The raw markdown is then handed to OnboardingFlowManager as the brain dump text, where it goes through the normal onboarding discovery conversation.

There is also a `PromptTemplates.markdownImport()` method that returns a prompt for extracting structured project data from markdown files, but **it is never called anywhere** — dead code from the previous approach.

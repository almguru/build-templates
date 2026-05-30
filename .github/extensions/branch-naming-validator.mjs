// Extension: branch-naming-validator
// Validates branch names against repo conventions before pushing. Prevents non-compliant branch names by checking naming patterns defined in .github/BRANCH_NAMING.md

import { joinSession } from "@github/copilot-sdk/extension";
import { execSync } from "child_process";

const ALLOWED_PATTERNS = [
  { prefix: "features/", description: "Feature branch" },
  { prefix: "bugfix/", description: "Bug fix" },
  { prefix: "hotfix/", description: "Hotfix (production)" },
  { prefix: "docs/", description: "Documentation" },
  { prefix: "chore/", description: "Maintenance/cleanup" },
  { prefix: "dependabot/", description: "Automated dependency update" },
];

function normalizeKebabCase(input) {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9-]/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function validateBranchName(branchName) {
  // Ignore special branches
  if (branchName === "main" || branchName === "develop") {
    return { valid: true, message: "OK (protected branch)" };
  }

  // Check if branch matches any allowed pattern
  const match = ALLOWED_PATTERNS.find((p) =>
    branchName.startsWith(p.prefix)
  );

  if (!match) {
    const allowedPrefixes = ALLOWED_PATTERNS.map((p) => p.prefix).join(", ");
    const normalized = normalizeKebabCase(branchName);
    return {
      valid: false,
      message: `Branch name does not match conventions. Must start with one of: ${allowedPrefixes}`,
      suggestion: `Try renaming to: features/${normalized}`,
    };
  }

  // Check naming (kebab-case)
  const namePart = branchName.substring(match.prefix.length);
  if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(namePart)) {
    const normalized = normalizeKebabCase(namePart);
    return {
      valid: false,
      message: `Branch name part "${namePart}" doesn't follow kebab-case convention (lowercase letters, numbers, hyphens only)`,
      suggestion: `Try: ${match.prefix}${normalized}`,
    };
  }

  return { valid: true, message: `OK (${match.description})` };
}

const session = await joinSession({
  tools: [
    {
      name: "branch-naming-validator_check",
      description:
        "Validates a branch name against repo conventions (features/, bugfix/, hotfix/, docs/, chore/, dependabot/)",
      parameters: {
        type: "object",
        properties: {
          branch_name: {
            type: "string",
            description:
              "The branch name to validate (e.g., 'features/my-feature' or current branch if not specified)",
          },
        },
      },
      skipPermission: true,
      handler: async (args) => {
        let branchName = args.branch_name;

        // If no branch specified, get current branch
        if (!branchName) {
          try {
            branchName = execSync("git rev-parse --abbrev-ref HEAD")
              .toString()
              .trim();
          } catch (e) {
            return { error: "Could not determine current branch" };
          }
        }

        const result = validateBranchName(branchName);
        return result;
      },
    },
  ],
});


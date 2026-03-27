import os
import re
import sys

def audit_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    issues = []

    # 1. MainActor Check for ViewModels
    if "ViewModel" in file_path and "class" in content and "@MainActor" not in content:
        issues.append("ERROR: ViewModel likely missing @MainActor isolation.")

    # 2. Legacy GCD usage
    if "DispatchQueue.main.async" in content:
        issues.append("WARNING: Use @MainActor or Task instead of legacy DispatchQueue.main.async.")

    # 3. Memory safety (weak self)
    # Simple check for closures that might capture self strongly
    if re.search(r'\{.*self\..*\}', content) and "[weak self]" not in content:
        # Avoid false positives for simple single-line closures or init
        if "init" not in content and "self.init" not in content:
            issues.append("WARNING: Possible strong reference cycle. Check for [weak self] in closures.")

    # 4. Swift 6 Concurrency (Actors for Services)
    if "Service" in file_path and "class" in content and "actor" not in content:
        issues.append("ADVICE: Consider using 'actor' instead of 'class' for stateful services.")

    # 5. Model types (Sendable/Struct)
    if "Models/Domain" in file_path and "class" in content:
        issues.append("ADVICE: Use 'struct' for domain models to ensure Sendable compliance.")

    return issues

def main():
    root_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    
    total_issues = 0
    for root, _, files in os.walk(root_dir):
        for file in files:
            if file.endswith(".swift"):
                file_path = os.path.join(root, file)
                issues = audit_file(file_path)
                if issues:
                    print(f"\n--- Audit for {file_path} ---")
                    for issue in issues:
                        print(f"  - {issue}")
                    total_issues += len(issues)

    if total_issues == 0:
        print("✅ No immediate Swift 6 issues found in basic scan.")
    else:
        print(f"\nFound {total_issues} potential issues to review.")

if __name__ == "__main__":
    main()

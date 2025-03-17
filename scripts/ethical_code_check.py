#!/usr/bin/env python3
"""
Ethical Code Check for SummitEthic

This script analyzes code files to ensure they adhere to SummitEthic's ethical guidelines.
It checks for things like:
- Privacy considerations
- Resource efficiency
- Ethical tags and documentation
- Security best practices
- Accessibility considerations
"""

import os
import re
import sys
import yaml
import argparse
from pathlib import Path
from colorama import Fore, Style, init

# Initialize colorama
init()

# Patterns to check for
PATTERNS = {
    # Privacy considerations
    "privacy": {
        "plain_passwords": r"password\s*=\s*['\"][^'\"]+['\"]",
        "plain_credentials": r"credential|api[_\s]*key|secret[_\s]*key|token\s*=\s*['\"][^'\"]+['\"]",
        "pii_collection": r"collect\w*\s+(?:user|personal)\s+(?:data|information)",
    },
    # Resource usage
    "resources": {
        "high_resource_usage": r"max_cpu|max_memory|unlimited|infinite\s+(?:timeout|retry)",
        "inefficient_loops": r"while\s+True|for\s+\w+\s+in\s+range\(\d{7,}\)",
    },
    # Security
    "security": {
        "eval_usage": r"eval\s*\(",
        "shell_injection": r"os\.system|subprocess\.call\s*\(.*\$\{?|.*%.*\)",
        "sql_injection": r"execute\s*\(.*\+\s*|.*%.*\)|.*\.format\(.*\)",
    },
    # Ethical tags
    "ethical_tags": {
        "missing_ethical_tag": r"org\.summitethic",
        "ethical_consideration": r"ethical|privacy|fair|equitable|sustainable",
    }
}

# Ethical code guidelines by file type
ETHICAL_GUIDELINES = {
    ".py": [
        "Contains proper error handling",
        "Uses resource-efficient patterns",
        "Includes privacy considerations",
        "Has security safeguards",
        "Documents ethical considerations"
    ],
    ".yml": [
        "Uses no_log for sensitive tasks",
        "Includes ethical tags where appropriate",
        "Documents purpose and impact",
        "Has reasonable resource limits"
    ],
    ".tf": [
        "Includes ethical tags in resources",
        "Sets reasonable resource limits",
        "Uses encryption for sensitive data",
        "Implements secure defaults",
        "Provides proper documentation"
    ],
    ".sh": [
        "Has error handling",
        "Uses secure coding practices",
        "Documents ethical considerations",
        "Respects user privacy"
    ]
}

def check_file(filepath):
    """Check a file for ethical considerations"""
    if not os.path.isfile(filepath):
        return []
    
    issues = []
    file_ext = os.path.splitext(filepath)[1]
    
    try:
        with open(filepath, 'r', encoding='utf-8') as file:
            content = file.read()
            
            # Check for patterns
            for category, patterns in PATTERNS.items():
                for name, pattern in patterns.items():
                    matches = re.finditer(pattern, content, re.IGNORECASE)
                    for match in matches:
                        # Skip if it's in a comment
                        line_start = content.rfind('\n', 0, match.start()) + 1
                        line = content[line_start:content.find('\n', match.start())]
                        
                        if line.strip().startswith('#') or line.strip().startswith('//') or line.strip().startswith('/*'):
                            continue
                            
                        if category == "ethical_tags" and name == "missing_ethical_tag":
                            # This is actually good
                            continue
                        
                        if category == "ethical_tags" and name == "ethical_consideration":
                            # This is good too
                            continue
                            
                        issues.append({
                            'file': filepath,
                            'line': content[:match.start()].count('\n') + 1,
                            'category': category,
                            'issue': name,
                            'snippet': match.group(0),
                            'severity': 'high' if category in ['privacy', 'security'] else 'medium'
                        })
            
            # Check for missing ethical considerations
            if file_ext in ['.py', '.yml', '.yaml', '.tf', '.sh']:
                has_ethical_comment = re.search(r'ethical|privacy|security|accessibility|fairness|sustainability', content, re.IGNORECASE)
                if not has_ethical_comment:
                    issues.append({
                        'file': filepath,
                        'line': 1,
                        'category': 'documentation',
                        'issue': 'missing_ethical_consideration',
                        'snippet': 'No ethical considerations documented',
                        'severity': 'medium'
                    })
    
    except Exception as e:
        issues.append({
            'file': filepath,
            'line': 0,
            'category': 'error',
            'issue': 'file_read_error',
            'snippet': str(e),
            'severity': 'low'
        })
    
    return issues

def print_issue(issue):
    """Print an issue with colors"""
    color = Fore.RED if issue['severity'] == 'high' else (Fore.YELLOW if issue['severity'] == 'medium' else Fore.BLUE)
    
    print(f"{color}[{issue['severity'].upper()}]{Style.RESET_ALL} {issue['file']}:{issue['line']}")
    print(f"  {Fore.CYAN}{issue['category']}/{issue['issue']}{Style.RESET_ALL}")
    print(f"  {issue['snippet']}")
    print()

def print_guidance(file_ext):
    """Print ethical coding guidance for a file type"""
    if file_ext not in ETHICAL_GUIDELINES:
        return
    
    print(f"\n{Fore.GREEN}Ethical Coding Guidelines for {file_ext} files:{Style.RESET_ALL}")
    for guideline in ETHICAL_GUIDELINES[file_ext]:
        print(f"  - {guideline}")

def main():
    parser = argparse.ArgumentParser(description='Check code for ethical considerations')
    parser.add_argument('files', nargs='*', help='Files to check')
    parser.add_argument('--all', action='store_true', help='Check all files in the repository')
    args = parser.parse_args()
    
    files_to_check = args.files
    
    if args.all:
        # Check all files in the repository
        for root, _, files in os.walk('.'):
            if '.git' in root or 'node_modules' in root:
                continue
            for file in files:
                ext = os.path.splitext(file)[1]
                if ext in ['.py', '.yml', '.yaml', '.tf', '.sh', '.js', '.html', '.css']:
                    files_to_check.append(os.path.join(root, file))
    
    if not files_to_check:
        print(f"{Fore.YELLOW}No files to check. Specify files or use --all.{Style.RESET_ALL}")
        return 0
    
    all_issues = []
    
    for file in files_to_check:
        issues = check_file(file)
        all_issues.extend(issues)
    
    # Group issues by file
    issues_by_file = {}
    for issue in all_issues:
        if issue['file'] not in issues_by_file:
            issues_by_file[issue['file']] = []
        issues_by_file[issue['file']].append(issue)
    
    # Print issues by file
    for file, issues in issues_by_file.items():
        file_ext = os.path.splitext(file)[1]
        high_issues = [i for i in issues if i['severity'] == 'high']
        medium_issues = [i for i in issues if i['severity'] == 'medium']
        
        if high_issues or medium_issues:
            print(f"\n{Fore.CYAN}=== {file} ==={Style.RESET_ALL}")
            
            for issue in high_issues:
                print_issue(issue)
            
            for issue in medium_issues:
                print_issue(issue)
            
            print_guidance(file_ext)
    
    # Summary
    high_count = len([i for i in all_issues if i['severity'] == 'high'])
    medium_count = len([i for i in all_issues if i['severity'] == 'medium'])
    
    print(f"\n{Fore.CYAN}=== Summary ==={Style.RESET_ALL}")
    print(f"Files checked: {len(files_to_check)}")
    print(f"High severity issues: {high_count}")
    print(f"Medium severity issues: {medium_count}")
    
    if high_count > 0:
        print(f"\n{Fore.RED}✖ Ethical check failed. Please address the high severity issues.{Style.RESET_ALL}")
        return 1
    elif medium_count > 0:
        print(f"\n{Fore.YELLOW}⚠ Ethical check passed with warnings. Consider addressing the medium severity issues.{Style.RESET_ALL}")
        return 0
    else:
        print(f"\n{Fore.GREEN}✓ Ethical check passed!{Style.RESET_ALL}")
        return 0

if __name__ == "__main__":
    sys.exit(main())
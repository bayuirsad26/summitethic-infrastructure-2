#!/usr/bin/env python3
"""
SummitEthic Backup Validator Script

This script validates backup files for integrity and completeness,
ensuring that backups meet SummitEthic's ethical data handling requirements.
"""

import os
import sys
import argparse
import hashlib
import tarfile
import gzip
import zipfile
import sqlite3
import json
import yaml
from datetime import datetime, timedelta
import logging
import tempfile
import subprocess
import shutil

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger('backup-validator')


def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description='Validate backup files for integrity and completeness')
    parser.add_argument('backup_path', help='Path to backup file or directory to validate')
    parser.add_argument('--type', choices=['system', 'database', 'files', 'auto'], default='auto',
                        help='Type of backup to validate (default: auto-detect)')
    parser.add_argument('--check-content', action='store_true',
                        help='Perform deep inspection of backup content')
    parser.add_argument('--output', '-o', default='backup-validation-report.json',
                        help='Output file for the validation report')
    parser.add_argument('--verbose', '-v', action='store_true',
                        help='Enable verbose output')
    parser.add_argument('--ethical-check', action='store_true',
                        help='Perform ethical data handling checks')
    return parser.parse_args()


def detect_backup_type(filepath):
    """Detect the type of backup based on file extension and content"""
    # Check file extension
    ext = os.path.splitext(filepath)[1].lower()
    
    if ext in ['.sql', '.sql.gz', '.dump', '.dmp']:
        return 'database'
    elif ext in ['.tar', '.tar.gz', '.tgz', '.zip']:
        # Check content to determine if it's a system or files backup
        if ext == '.zip':
            with zipfile.ZipFile(filepath, 'r') as z:
                filelist = z.namelist()
        elif ext in ['.tar.gz', '.tgz']:
            with tarfile.open(filepath, 'r:gz') as t:
                filelist = t.getnames()
        elif ext == '.tar':
            with tarfile.open(filepath, 'r') as t:
                filelist = t.getnames()
        
        # Check for system backup indicators
        system_indicators = ['etc/', 'var/lib/dpkg', 'boot/', 'root/']
        if any(indicator in filelist for indicator in system_indicators):
            return 'system'
        return 'files'
    
    # Default to files
    return 'files'


def calculate_checksum(filepath, algorithm='sha256'):
    """Calculate file checksum"""
    if algorithm == 'sha256':
        h = hashlib.sha256()
    elif algorithm == 'md5':
        h = hashlib.md5()
    else:
        raise ValueError(f"Unsupported hash algorithm: {algorithm}")
    
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b''):
            h.update(chunk)
    
    return h.hexdigest()


def verify_checksum_file(filepath):
    """Verify file against its checksum file if available"""
    checksum_file = filepath + '.sha256'
    if not os.path.exists(checksum_file):
        return {'verified': False, 'reason': 'Checksum file not found'}
    
    try:
        with open(checksum_file, 'r') as f:
            expected_checksum = f.read().split()[0]
        
        calculated_checksum = calculate_checksum(filepath)
        
        if calculated_checksum == expected_checksum:
            return {'verified': True}
        else:
            return {'verified': False, 'reason': 'Checksum mismatch', 
                    'expected': expected_checksum, 'calculated': calculated_checksum}
    
    except Exception as e:
        return {'verified': False, 'reason': f'Error verifying checksum: {str(e)}'}


def check_backup_age(filepath):
    """Check if backup is within acceptable age range"""
    file_mtime = os.path.getmtime(filepath)
    file_date = datetime.fromtimestamp(file_mtime)
    now = datetime.now()
    
    age_days = (now - file_date).days
    
    if age_days > 30:
        return {'status': 'warning', 'age_days': age_days, 
                'message': f'Backup is {age_days} days old'}
    else:
        return {'status': 'ok', 'age_days': age_days}


def validate_system_backup(filepath, check_content=False):
    """Validate system backup file"""
    results = {
        'type': 'system',
        'file': filepath,
        'size': os.path.getsize(filepath),
        'age': check_backup_age(filepath),
        'checksum': calculate_checksum(filepath),
        'checksum_verification': verify_checksum_file(filepath),
        'content_checks': {},
        'status': 'unknown'
    }
    
    # Basic file checks
    if not os.path.isfile(filepath):
        results['status'] = 'error'
        results['error'] = 'File does not exist or is not a regular file'
        return results
    
    # Extract file extension
    ext = os.path.splitext(filepath)[1].lower()
    
    # Check if file is a valid archive
    try:
        if ext in ['.tar.gz', '.tgz']:
            with tarfile.open(filepath, 'r:gz') as t:
                results['content_checks']['valid_archive'] = True
                if check_content:
                    results['content_checks']['file_count'] = len(t.getnames())
                    
                    # Check for critical system files
                    critical_files = ['/etc/passwd', '/etc/shadow', '/etc/fstab', '/etc/hosts']
                    found_critical = [f for f in critical_files if any(f.lstrip('/') in name for name in t.getnames())]
                    results['content_checks']['critical_files_found'] = found_critical
        
        elif ext == '.tar':
            with tarfile.open(filepath, 'r') as t:
                results['content_checks']['valid_archive'] = True
                if check_content:
                    results['content_checks']['file_count'] = len(t.getnames())
                    
                    # Check for critical system files
                    critical_files = ['/etc/passwd', '/etc/shadow', '/etc/fstab', '/etc/hosts']
                    found_critical = [f for f in critical_files if any(f.lstrip('/') in name for name in t.getnames())]
                    results['content_checks']['critical_files_found'] = found_critical
        
        elif ext == '.zip':
            with zipfile.ZipFile(filepath, 'r') as z:
                results['content_checks']['valid_archive'] = True
                if check_content:
                    results['content_checks']['file_count'] = len(z.namelist())
                    
                    # Check for critical system files
                    critical_files = ['/etc/passwd', '/etc/shadow', '/etc/fstab', '/etc/hosts']
                    found_critical = [f for f in critical_files if any(f.lstrip('/') in name for name in z.namelist())]
                    results['content_checks']['critical_files_found'] = found_critical
        
        results['status'] = 'valid'
    
    except Exception as e:
        results['status'] = 'error'
        results['error'] = f'Invalid archive file: {str(e)}'
    
    return results


def validate_database_backup(filepath, check_content=False):
    """Validate database backup file"""
    results = {
        'type': 'database',
        'file': filepath,
        'size': os.path.getsize(filepath),
        'age': check_backup_age(filepath),
        'checksum': calculate_checksum(filepath),
        'checksum_verification': verify_checksum_file(filepath),
        'content_checks': {},
        'status': 'unknown'
    }
    
    # Basic file checks
    if not os.path.isfile(filepath):
        results['status'] = 'error'
        results['error'] = 'File does not exist or is not a regular file'
        return results
    
    # Extract file extension
    ext = os.path.splitext(filepath)[1].lower()
    
    # Check if file is a valid SQL dump
    try:
        temp_dir = None
        sql_file = filepath
        
        # If file is compressed, decompress to a temporary file for analysis
        if ext == '.gz':
            temp_dir = tempfile.mkdtemp()
            sql_file = os.path.join(temp_dir, 'temp.sql')
            with gzip.open(filepath, 'rb') as f_in:
                with open(sql_file, 'wb') as f_out:
                    f_out.write(f_in.read(1024 * 1024))  # Read first MB for analysis
        
        # Perform basic SQL file validation
        with open(sql_file, 'r', errors='ignore') as f:
            content = f.read(1024 * 1024)  # Read first MB for analysis
            
            # Check for SQL dump indicators
            if 'CREATE TABLE' in content or 'INSERT INTO' in content:
                results['content_checks']['sql_syntax_found'] = True
                
                # Try to determine database type
                if 'CREATE EXTENSION IF NOT EXISTS' in content or 'pg_catalog' in content:
                    results['content_checks']['db_type'] = 'postgresql'
                elif 'CREATE DATABASE' in content and 'ENGINE=' in content:
                    results['content_checks']['db_type'] = 'mysql'
                else:
                    results['content_checks']['db_type'] = 'unknown'
                
                if check_content:
                    # Count tables (rough estimate)
                    tables = content.count('CREATE TABLE')
                    results['content_checks']['table_count'] = tables
            else:
                results['content_checks']['sql_syntax_found'] = False
        
        if temp_dir:
            shutil.rmtree(temp_dir)
        
        if results['content_checks'].get('sql_syntax_found', False):
            results['status'] = 'valid'
        else:
            results['status'] = 'warning'
            results['warning'] = 'File may not be a valid SQL dump'
    
    except Exception as e:
        results['status'] = 'error'
        results['error'] = f'Error validating SQL file: {str(e)}'
    
    return results


def validate_files_backup(filepath, check_content=False):
    """Validate files backup"""
    results = {
        'type': 'files',
        'file': filepath,
        'size': os.path.getsize(filepath),
        'age': check_backup_age(filepath),
        'checksum': calculate_checksum(filepath),
        'checksum_verification': verify_checksum_file(filepath),
        'content_checks': {},
        'status': 'unknown'
    }
    
    # Basic file checks
    if not os.path.isfile(filepath):
        results['status'] = 'error'
        results['error'] = 'File does not exist or is not a regular file'
        return results
    
    # Extract file extension
    ext = os.path.splitext(filepath)[1].lower()
    
    # Check if file is a valid archive
    try:
        if ext in ['.tar.gz', '.tgz']:
            with tarfile.open(filepath, 'r:gz') as t:
                results['content_checks']['valid_archive'] = True
                if check_content:
                    results['content_checks']['file_count'] = len(t.getnames())
                    
                    # Categorize files
                    file_types = {}
                    for name in t.getnames():
                        if name.endswith('/'):
                            continue
                        ext = os.path.splitext(name)[1].lower()
                        file_types[ext] = file_types.get(ext, 0) + 1
                    
                    results['content_checks']['file_types'] = file_types
        
        elif ext == '.tar':
            with tarfile.open(filepath, 'r') as t:
                results['content_checks']['valid_archive'] = True
                if check_content:
                    results['content_checks']['file_count'] = len(t.getnames())
                    
                    # Categorize files
                    file_types = {}
                    for name in t.getnames():
                        if name.endswith('/'):
                            continue
                        ext = os.path.splitext(name)[1].lower()
                        file_types[ext] = file_types.get(ext, 0) + 1
                    
                    results['content_checks']['file_types'] = file_types
        
        elif ext == '.zip':
            with zipfile.ZipFile(filepath, 'r') as z:
                results['content_checks']['valid_archive'] = True
                if check_content:
                    results['content_checks']['file_count'] = len(z.namelist())
                    
                    # Categorize files
                    file_types = {}
                    for name in z.namelist():
                        if name.endswith('/'):
                            continue
                        ext = os.path.splitext(name)[1].lower()
                        file_types[ext] = file_types.get(ext, 0) + 1
                    
                    results['content_checks']['file_types'] = file_types
        
        results['status'] = 'valid'
    
    except Exception as e:
        results['status'] = 'error'
        results['error'] = f'Invalid archive file: {str(e)}'
    
    return results


def check_ethical_data_handling(results, filepath):
    """Perform ethical data handling checks on the backup"""
    ethical_results = {}
    
    # Check if backup is encrypted
    is_encrypted = False
    if filepath.endswith('.gpg') or filepath.endswith('.enc'):
        is_encrypted = True
    
    ethical_results['encrypted'] = is_encrypted
    
    # Check for potential PII based on backup type
    if results['type'] == 'database':
        ethical_results['potential_pii'] = True
        ethical_results['privacy_risk'] = 'high' if not is_encrypted else 'medium'
        
        # Additional recommendations for database backups
        ethical_results['recommendations'] = [
            "Ensure all PII is properly encrypted in the backup",
            "Verify data minimization principles are applied",
            "Implement strict access controls for this backup file"
        ]
    
    elif results['type'] == 'system':
        ethical_results['potential_pii'] = True
        ethical_results['privacy_risk'] = 'medium' if not is_encrypted else 'low'
        
        # Look for high-risk files if content checks were performed
        if 'content_checks' in results and 'critical_files_found' in results['content_checks']:
            if '/etc/shadow' in results['content_checks']['critical_files_found']:
                ethical_results['privacy_risk'] = 'high' if not is_encrypted else 'medium'
                ethical_results['sensitive_content'] = True
    
    elif results['type'] == 'files':
        ethical_results['potential_pii'] = 'unknown'
        ethical_results['privacy_risk'] = 'medium' if not is_encrypted else 'low'
    
    # Check backup age for compliance with retention policies
    if results['age']['age_days'] > 180:  # 6 months
        ethical_results['retention_concern'] = True
        ethical_results['recommendations'] = ethical_results.get('recommendations', []) + [
            "Review retention policy for compliance with data protection requirements",
            "Consider if this backup should be securely deleted"
        ]
    
    # Overall ethical assessment
    if is_encrypted and results['status'] == 'valid':
        ethical_results['assessment'] = 'compliant'
    elif not is_encrypted and ethical_results.get('privacy_risk') in ['medium', 'high']:
        ethical_results['assessment'] = 'non_compliant'
        ethical_results['compliance_issues'] = [
            "Sensitive data should be encrypted at rest",
            "Access controls should be implemented for backup files"
        ]
    else:
        ethical_results['assessment'] = 'review_needed'
    
    return ethical_results


def validate_backup(filepath, backup_type='auto', check_content=False, ethical_check=False):
    """Validate backup file based on type"""
    # Check if file exists
    if not os.path.exists(filepath):
        return {
            'status': 'error',
            'error': f'File not found: {filepath}'
        }
    
    # Auto-detect backup type if not specified
    if backup_type == 'auto':
        backup_type = detect_backup_type(filepath)
    
    # Validate based on backup type
    if backup_type == 'system':
        results = validate_system_backup(filepath, check_content)
    elif backup_type == 'database':
        results = validate_database_backup(filepath, check_content)
    elif backup_type == 'files':
        results = validate_files_backup(filepath, check_content)
    else:
        return {
            'status': 'error',
            'error': f'Unknown backup type: {backup_type}'
        }
    
    # Add ethical data handling checks if requested
    if ethical_check:
        results['ethical_checks'] = check_ethical_data_handling(results, filepath)
    
    return results


def validate_backup_directory(directory, check_content=False, ethical_check=False):
    """Validate all backup files in a directory"""
    results = {
        'directory': directory,
        'files_count': 0,
        'valid_count': 0,
        'warning_count': 0,
        'error_count': 0,
        'files': []
    }
    
    if not os.path.isdir(directory):
        results['status'] = 'error'
        results['error'] = f'Not a directory: {directory}'
        return results
    
    # Find all potential backup files
    backup_extensions = ['.sql', '.sql.gz', '.dump', '.dmp', '.tar', '.tar.gz', '.tgz', '.zip', '.gpg', '.enc']
    
    for root, _, files in os.walk(directory):
        for filename in files:
            filepath = os.path.join(root, filename)
            
            # Skip checksum files and temporary files
            if any(filepath.endswith(ext) for ext in ['.sha256', '.md5', '.tmp']):
                continue
            
            # Skip files that don't have backup extensions unless they have a checksum file
            if not any(filepath.endswith(ext) for ext in backup_extensions) and not os.path.exists(filepath + '.sha256'):
                continue
            
            # Validate the backup file
            file_result = validate_backup(filepath, 'auto', check_content, ethical_check)
            results['files'].append(file_result)
            
            results['files_count'] += 1
            if file_result['status'] == 'valid':
                results['valid_count'] += 1
            elif file_result['status'] == 'warning':
                results['warning_count'] += 1
            elif file_result['status'] == 'error':
                results['error_count'] += 1
    
    # Set overall status
    if results['error_count'] > 0:
        results['status'] = 'errors_found'
    elif results['warning_count'] > 0:
        results['status'] = 'warnings_found'
    elif results['valid_count'] > 0:
        results['status'] = 'all_valid'
    else:
        results['status'] = 'no_backups_found'
    
    return results


def generate_report(results):
    """Generate a detailed validation report"""
    report = {
        'timestamp': datetime.now().isoformat(),
        'validation_results': results,
        'summary': {}
    }
    
    # Generate summary based on result type
    if 'directory' in results:
        report['summary'] = {
            'type': 'directory',
            'path': results['directory'],
            'total_files': results['files_count'],
            'valid_files': results['valid_count'],
            'warning_files': results['warning_count'],
            'error_files': results['error_count'],
            'status': results['status']
        }
        
        # Add ethical compliance summary if available
        if any('ethical_checks' in file_result for file_result in results['files']):
            ethical_compliant = sum(1 for file in results['files'] 
                                   if file.get('ethical_checks', {}).get('assessment') == 'compliant')
            ethical_noncompliant = sum(1 for file in results['files'] 
                                      if file.get('ethical_checks', {}).get('assessment') == 'non_compliant')
            
            report['summary']['ethical_compliance'] = {
                'compliant_files': ethical_compliant,
                'non_compliant_files': ethical_noncompliant,
                'review_needed_files': results['files_count'] - ethical_compliant - ethical_noncompliant
            }
    else:
        report['summary'] = {
            'type': 'file',
            'path': results['file'],
            'status': results['status'],
            'size': results['size'],
            'age_days': results['age']['age_days']
        }
        
        # Add ethical compliance summary if available
        if 'ethical_checks' in results:
            report['summary']['ethical_compliance'] = {
                'assessment': results['ethical_checks']['assessment'],
                'privacy_risk': results['ethical_checks'].get('privacy_risk', 'unknown'),
                'encrypted': results['ethical_checks']['encrypted']
            }
    
    # Add timestamp and metadata
    report['metadata'] = {
        'generator': 'SummitEthic Backup Validator',
        'version': '1.0',
        'generated_by': os.environ.get('USER', 'unknown')
    }
    
    return report


def main():
    """Main function"""
    args = parse_arguments()
    
    # Configure logging level
    if args.verbose:
        logger.setLevel(logging.DEBUG)
    
    logger.info(f"Starting backup validation of {args.backup_path}")
    
    # Validate backup file or directory
    if os.path.isdir(args.backup_path):
        logger.info(f"Validating backup directory: {args.backup_path}")
        results = validate_backup_directory(args.backup_path, args.check_content, args.ethical_check)
    else:
        logger.info(f"Validating backup file: {args.backup_path}")
        results = validate_backup(args.backup_path, args.type, args.check_content, args.ethical_check)
    
    # Generate validation report
    report = generate_report(results)
    
    # Write report to file
    with open(args.output, 'w') as f:
        json.dump(report, f, indent=2)
    
    logger.info(f"Validation report written to: {args.output}")
    
    # Print summary to console
    if 'directory' in results:
        logger.info(f"Summary: {results['valid_count']} valid, {results['warning_count']} warnings, {results['error_count']} errors")
    else:
        logger.info(f"Status: {results['status']}")
    
    # Exit with appropriate status code
    if results.get('status') in ['error', 'errors_found']:
        sys.exit(1)
    elif results.get('status') in ['warning', 'warnings_found']:
        sys.exit(2)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()
#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2025, SummitEthic
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

from __future__ import absolute_import, division, print_function
__metaclass__ = type

DOCUMENTATION = r'''
---
module: security_check
short_description: Perform ethical security checks on infrastructure
description:
    - This module performs ethical security checks on infrastructure components.
    - It evaluates security posture against ethical guidelines and best practices.
    - Results can be used for compliance reporting and security improvements.
options:
    target:
        description:
            - The target system, file, or configuration to check.
        type: str
        required: true
    scan_type:
        description:
            - The type of security scan to perform.
        type: str
        required: true
        choices: ['config', 'network', 'permissions', 'passwords', 'compliance']
    ethical_level:
        description:
            - The ethical framework level to check against.
        type: str
        default: 'standard'
        choices: ['minimal', 'standard', 'strict']
    compliance_standards:
        description:
            - List of compliance standards to check against.
        type: list
        elements: str
        default: ['cis']
    timeout:
        description:
            - Timeout for the security check in seconds.
        type: int
        default: 60
author:
    - SummitEthic DevOps Team (@summitethic)
'''

EXAMPLES = r'''
- name: Check SSH configuration for security issues
  security_check:
    target: /etc/ssh/sshd_config
    scan_type: config
    ethical_level: strict
    compliance_standards:
      - cis
      - nist

- name: Check network security
  security_check:
    target: "{{ ansible_default_ipv4.interface }}"
    scan_type: network
    timeout: 120

- name: Check file permissions
  security_check:
    target: /etc/passwd
    scan_type: permissions
    ethical_level: standard
'''

RETURN = r'''
issues:
    description: List of security issues found
    returned: always
    type: list
    elements: dict
    contains:
        severity:
            description: Severity of the issue
            type: str
            sample: high
        description:
            description: Description of the issue
            type: str
            sample: "SSH permits root login"
        recommendation:
            description: Recommended fix
            type: str
            sample: "Set PermitRootLogin to no"
        ethical_impact:
            description: Ethical impact of the issue
            type: str
            sample: "Compromised access could lead to data breaches"
        compliant:
            description: Whether this issue affects compliance
            type: bool
            sample: false
        standard:
            description: Compliance standard relevant to the issue
            type: str
            sample: CIS 5.2.8
score:
    description: Overall security score (0-100)
    returned: always
    type: int
    sample: 85
ethical_assessment:
    description: Ethical assessment of the system
    returned: always
    type: dict
    contains:
        rating:
            description: Ethical rating
            type: str
            sample: good
        issues:
            description: Count of ethical issues
            type: int
            sample: 3
        recommendations:
            description: Ethical recommendations
            type: list
            sample: ["Implement privacy-preserving logging", "Reduce data retention period"]
compliance:
    description: Compliance status
    returned: always
    type: dict
    contains:
        status:
            description: Overall compliance status
            type: str
            sample: partial
        standards:
            description: Compliance by standard
            type: dict
            sample: {'cis': 'compliant', 'nist': 'non_compliant'}
'''

import os
import re
import json
import socket
import stat
import subprocess
import time

from ansible.module_utils.basic import AnsibleModule


def check_ssh_config(target, ethical_level, standards):
    """Check SSH configuration for security issues."""
    issues = []
    
    try:
        with open(target, 'r') as f:
            content = f.read()
            
        # Check PermitRootLogin
        root_login_match = re.search(r'^PermitRootLogin\s+(\w+)', content, re.MULTILINE)
        if root_login_match:
            if root_login_match.group(1).lower() != 'no':
                issues.append({
                    'severity': 'high',
                    'description': 'SSH permits root login',
                    'recommendation': 'Set PermitRootLogin to no',
                    'ethical_impact': 'Compromised root access could lead to data breaches and system compromise',
                    'compliant': False,
                    'standard': 'CIS 5.2.8'
                })
        else:
            issues.append({
                'severity': 'medium',
                'description': 'SSH root login configuration not found',
                'recommendation': 'Add PermitRootLogin no to SSH configuration',
                'ethical_impact': 'Default settings may allow root login, risking unauthorized system access',
                'compliant': False,
                'standard': 'CIS 5.2.8'
            })
            
        # Check PasswordAuthentication
        password_auth_match = re.search(r'^PasswordAuthentication\s+(\w+)', content, re.MULTILINE)
        if password_auth_match:
            if password_auth_match.group(1).lower() == 'yes' and ethical_level in ['standard', 'strict']:
                issues.append({
                    'severity': 'medium',
                    'description': 'SSH allows password authentication',
                    'recommendation': 'Use key-based authentication instead by setting PasswordAuthentication no',
                    'ethical_impact': 'Password authentication is vulnerable to brute force attacks',
                    'compliant': False,
                    'standard': 'CIS 5.2.12'
                })
        
        # Other SSH checks based on ethical_level
        if ethical_level == 'strict':
            # Check Protocol version
            protocol_match = re.search(r'^Protocol\s+(\d+)', content, re.MULTILINE)
            if protocol_match:
                if protocol_match.group(1) != '2':
                    issues.append({
                        'severity': 'high',
                        'description': 'SSH protocol version is not set to 2',
                        'recommendation': 'Set Protocol 2 in SSH configuration',
                        'ethical_impact': 'Older protocols have known vulnerabilities',
                        'compliant': False,
                        'standard': 'CIS 5.2.1'
                    })
            
            # Check idle timeout
            client_alive_interval = re.search(r'^ClientAliveInterval\s+(\d+)', content, re.MULTILINE)
            client_alive_count_max = re.search(r'^ClientAliveCountMax\s+(\d+)', content, re.MULTILINE)
            
            if not client_alive_interval or not client_alive_count_max:
                issues.append({
                    'severity': 'low',
                    'description': 'SSH idle timeout not properly configured',
                    'recommendation': 'Set ClientAliveInterval and ClientAliveCountMax to enforce idle timeouts',
                    'ethical_impact': 'Long-lived idle sessions increase risk of unauthorized access',
                    'compliant': False,
                    'standard': 'CIS 5.2.16'
                })
            elif client_alive_interval and client_alive_count_max:
                interval = int(client_alive_interval.group(1))
                count = int(client_alive_count_max.group(1))
                
                if interval * count > 900:  # 15 minutes
                    issues.append({
                        'severity': 'low',
                        'description': 'SSH idle timeout is longer than recommended',
                        'recommendation': 'Reduce ClientAliveInterval or ClientAliveCountMax for shorter timeout',
                        'ethical_impact': 'Excessive timeout period increases security risk',
                        'compliant': False,
                        'standard': 'CIS 5.2.16'
                    })
    
    except Exception as e:
        issues.append({
            'severity': 'high',
            'description': f'Error checking SSH config: {str(e)}',
            'recommendation': 'Ensure SSH configuration is readable and properly formatted',
            'ethical_impact': 'Unable to verify security of SSH configuration',
            'compliant': False,
            'standard': 'N/A'
        })
    
    return issues


def check_file_permissions(target, ethical_level):
    """Check file permissions for security issues."""
    issues = []
    
    try:
        st = os.stat(target)
        mode = st.st_mode
        
        # Check owner and group
        owner = st.st_uid
        group = st.st_gid
        
        if target in ['/etc/passwd', '/etc/shadow', '/etc/group', '/etc/gshadow']:
            # Critical system files
            
            # Check world-readable for sensitive files
            if target == '/etc/shadow' or target == '/etc/gshadow':
                if mode & stat.S_IROTH:
                    issues.append({
                        'severity': 'critical',
                        'description': f'{target} is world-readable',
                        'recommendation': f'Remove world-readable permission: chmod o-r {target}',
                        'ethical_impact': 'Exposes password hashes, severe privacy and security risk',
                        'compliant': False,
                        'standard': 'CIS 6.1.3'
                    })
            
            # Check owner for system files
            if owner != 0:  # Not owned by root
                issues.append({
                    'severity': 'high',
                    'description': f'{target} is not owned by root',
                    'recommendation': f'Change owner to root: chown root {target}',
                    'ethical_impact': 'Improper ownership can lead to unauthorized modifications',
                    'compliant': False,
                    'standard': 'CIS 6.1.2'
                })
            
            # Check group for sensitive files
            if target == '/etc/shadow' or target == '/etc/gshadow':
                if group != 0 and group != 42:  # Not root or shadow
                    issues.append({
                        'severity': 'high',
                        'description': f'{target} has incorrect group',
                        'recommendation': f'Change group to shadow: chgrp shadow {target}',
                        'ethical_impact': 'Improper group can lead to unauthorized access',
                        'compliant': False,
                        'standard': 'CIS 6.1.3'
                    })
        
        # Check world-writable for all files
        if mode & stat.S_IWOTH:
            issues.append({
                'severity': 'high',
                'description': f'{target} is world-writable',
                'recommendation': f'Remove world-writable permission: chmod o-w {target}',
                'ethical_impact': 'World-writable files can be modified by any user, risking integrity',
                'compliant': False,
                'standard': 'CIS 6.1.9'
            })
        
        # In strict mode, check for SUID/SGID
        if ethical_level == 'strict':
            if mode & (stat.S_ISUID | stat.S_ISGID):
                issues.append({
                    'severity': 'medium',
                    'description': f'{target} has SUID/SGID bit set',
                    'recommendation': f'Review if SUID/SGID is necessary: chmod -s {target}',
                    'ethical_impact': 'SUID/SGID files present privilege escalation risk if compromised',
                    'compliant': False,
                    'standard': 'CIS 6.1.14'
                })
    
    except Exception as e:
        issues.append({
            'severity': 'medium',
            'description': f'Error checking file permissions: {str(e)}',
            'recommendation': 'Ensure the file exists and is accessible',
            'ethical_impact': 'Unable to verify security of file permissions',
            'compliant': False,
            'standard': 'N/A'
        })
    
    return issues


def check_network_security(target, ethical_level):
    """Check network interface security."""
    issues = []
    
    try:
        # Check open ports using ss or netstat
        try:
            output = subprocess.check_output(['ss', '-tuln'], universal_newlines=True)
        except (subprocess.SubprocessError, FileNotFoundError):
            try:
                output = subprocess.check_output(['netstat', '-tuln'], universal_newlines=True)
            except (subprocess.SubprocessError, FileNotFoundError):
                output = ""
                issues.append({
                    'severity': 'medium',
                    'description': 'Unable to check for open ports, ss/netstat not available',
                    'recommendation': 'Install iproute2 or net-tools package',
                    'ethical_impact': 'Cannot verify network security posture',
                    'compliant': False,
                    'standard': 'N/A'
                })
        
        # Check for sensitive ports
        sensitive_ports = {
            '21': 'FTP',
            '23': 'Telnet',
            '25': 'SMTP',
            '53': 'DNS',
            '137': 'NetBIOS',
            '139': 'NetBIOS',
            '445': 'SMB',
            '1433': 'MS SQL',
            '3306': 'MySQL',
            '5432': 'PostgreSQL'
        }
        
        for port, service in sensitive_ports.items():
            if re.search(rf':{port}\s', output):
                severity = 'medium'
                if port in ['23', '137', '139']:  # Especially risky services
                    severity = 'high'
                
                issues.append({
                    'severity': severity,
                    'description': f'Port {port} ({service}) is open',
                    'recommendation': f'If not required, disable the {service} service or restrict access with firewall',
                    'ethical_impact': f'Open {service} port may expose sensitive services to unauthorized access',
                    'compliant': False,
                    'standard': 'CIS 3.2'
                })
        
        # Check for all listening on 0.0.0.0 (all interfaces)
        if ethical_level in ['standard', 'strict']:
            all_interfaces = re.findall(r'0\.0\.0\.0:(\d+)', output)
            for port in all_interfaces:
                if port not in ['22', '80', '443']:  # Common exceptions
                    issues.append({
                        'severity': 'medium',
                        'description': f'Service on port {port} is listening on all interfaces (0.0.0.0)',
                        'recommendation': 'Configure the service to listen only on required interfaces',
                        'ethical_impact': 'Services exposed on all interfaces increase attack surface',
                        'compliant': False,
                        'standard': 'CIS 3.4'
                    })
        
        # Check firewall status if in strict mode
        if ethical_level == 'strict':
            try:
                ufw_output = subprocess.check_output(['ufw', 'status'], universal_newlines=True)
                if 'inactive' in ufw_output:
                    issues.append({
                        'severity': 'high',
                        'description': 'Firewall (ufw) is inactive',
                        'recommendation': 'Enable the firewall with appropriate rules',
                        'ethical_impact': 'Systems without active firewalls are vulnerable to network attacks',
                        'compliant': False,
                        'standard': 'CIS 3.5'
                    })
            except (subprocess.SubprocessError, FileNotFoundError):
                try:
                    iptables_output = subprocess.check_output(['iptables', '-L'], universal_newlines=True)
                    if 'Chain INPUT (policy ACCEPT)' in iptables_output and 'Chain FORWARD (policy ACCEPT)' in iptables_output:
                        issues.append({
                            'severity': 'high',
                            'description': 'Firewall (iptables) has ACCEPT default policies',
                            'recommendation': 'Configure iptables with restrictive default policies',
                            'ethical_impact': 'Default ACCEPT policies allow unauthorized traffic by default',
                            'compliant': False,
                            'standard': 'CIS 3.5'
                        })
                except (subprocess.SubprocessError, FileNotFoundError):
                    issues.append({
                        'severity': 'high',
                        'description': 'Unable to check firewall status',
                        'recommendation': 'Install and configure a firewall (ufw, iptables)',
                        'ethical_impact': 'Unknown firewall state may indicate lack of network protection',
                        'compliant': False,
                        'standard': 'CIS 3.5'
                    })
    
    except Exception as e:
        issues.append({
            'severity': 'high',
            'description': f'Error checking network security: {str(e)}',
            'recommendation': 'Ensure network tools are installed and accessible',
            'ethical_impact': 'Unable to verify network security posture',
            'compliant': False,
            'standard': 'N/A'
        })
    
    return issues


def calculate_score(issues):
    """Calculate an overall security score based on issues."""
    if not issues:
        return 100
    
    # Assign weights to different severities
    severity_weights = {
        'critical': 25,
        'high': 15,
        'medium': 8,
        'low': 3
    }
    
    # Calculate the maximum possible deduction
    max_deduction = sum(severity_weights.get(issue['severity'], 5) for issue in issues)
    
    # Cap the maximum deduction at 100 to avoid negative scores
    max_deduction = min(max_deduction, 100)
    
    if max_deduction == 0:
        return 100
    
    # Calculate the actual score
    score = 100 - max_deduction
    
    # Ensure score is between 0 and 100
    return max(0, min(score, 100))


def assess_ethics(issues, ethical_level):
    """Provide an ethical assessment based on issues."""
    assessment = {
        'rating': 'good',
        'issues': 0,
        'recommendations': []
    }
    
    # Count issues by severity
    severity_counts = {'critical': 0, 'high': 0, 'medium': 0, 'low': 0}
    for issue in issues:
        severity = issue.get('severity', 'medium')
        severity_counts[severity] = severity_counts.get(severity, 0) + 1
        
        # Extract unique ethical recommendations
        if 'ethical_impact' in issue and issue['ethical_impact']:
            recommendation = issue['recommendation']
            if recommendation not in assessment['recommendations']:
                assessment['recommendations'].append(recommendation)
    
    # Determine rating based on counts and ethical level
    assessment['issues'] = sum(severity_counts.values())
    
    if severity_counts['critical'] > 0:
        assessment['rating'] = 'poor'
    elif severity_counts['high'] > 3:
        assessment['rating'] = 'poor'
    elif severity_counts['high'] > 0:
        assessment['rating'] = 'fair'
    elif severity_counts['medium'] > 5:
        assessment['rating'] = 'fair'
    elif severity_counts['medium'] > 2:
        assessment['rating'] = 'good'
    else:
        assessment['rating'] = 'excellent'
    
    # Adjust for ethical_level
    if ethical_level == 'strict' and assessment['rating'] != 'excellent':
        # Downgrade rating one level in strict mode
        if assessment['rating'] == 'good':
            assessment['rating'] = 'fair'
        elif assessment['rating'] == 'fair':
            assessment['rating'] = 'poor'
    
    # Limit recommendations to top 5
    assessment['recommendations'] = assessment['recommendations'][:5]
    
    # Add ethical considerations
    if not assessment['recommendations']:
        if assessment['rating'] == 'excellent':
            assessment['recommendations'].append('Continue maintaining current security posture')
        else:
            assessment['recommendations'].append('Address identified security issues to improve ethical standing')
    
    return assessment


def check_compliance(issues, standards):
    """Check compliance status against standards."""
    compliance = {
        'status': 'compliant',
        'standards': {}
    }
    
    # Initialize all standards as compliant
    for standard in standards:
        compliance['standards'][standard] = 'compliant'
    
    # Check for non-compliance
    for issue in issues:
        if issue.get('compliant') is False:
            # Extract the standard identifier (e.g., "CIS 5.2.8" -> "cis")
            if 'standard' in issue and issue['standard'] != 'N/A':
                std_id = issue['standard'].split()[0].lower()
                
                if std_id in compliance['standards']:
                    compliance['standards'][std_id] = 'non_compliant'
    
    # Set overall status
    if 'non_compliant' in compliance['standards'].values():
        compliance['status'] = 'partial' if 'compliant' in compliance['standards'].values() else 'non_compliant'
    
    return compliance


def main():
    """Main function."""
    module = AnsibleModule(
        argument_spec=dict(
            target=dict(type='str', required=True),
            scan_type=dict(type='str', required=True, choices=['config', 'network', 'permissions', 'passwords', 'compliance']),
            ethical_level=dict(type='str', default='standard', choices=['minimal', 'standard', 'strict']),
            compliance_standards=dict(type='list', elements='str', default=['cis']),
            timeout=dict(type='int', default=60)
        ),
        supports_check_mode=True
    )
    
    target = module.params['target']
    scan_type = module.params['scan_type']
    ethical_level = module.params['ethical_level']
    standards = module.params['compliance_standards']
    timeout = module.params['timeout']
    
    # Set timeout for long-running operations
    socket.setdefaulttimeout(timeout)
    
    issues = []
    
    # Perform the appropriate check based on scan_type
    if scan_type == 'config':
        if os.path.basename(target) == 'sshd_config':
            issues = check_ssh_config(target, ethical_level, standards)
        else:
            module.fail_json(msg=f"Config scan for {target} not implemented")
    
    elif scan_type == 'permissions':
        issues = check_file_permissions(target, ethical_level)
    
    elif scan_type == 'network':
        issues = check_network_security(target, ethical_level)
    
    elif scan_type == 'passwords':
        # Check for weak passwords in shadow file or password policies
        module.fail_json(msg="Password scan not implemented in this version")
    
    elif scan_type == 'compliance':
        # Comprehensive compliance check across multiple dimensions
        module.fail_json(msg="Comprehensive compliance scan not implemented in this version")
    
    # Calculate score based on issues
    score = calculate_score(issues)
    
    # Assess ethical implications
    ethical_assessment = assess_ethics(issues, ethical_level)
    
    # Check compliance status
    compliance_status = check_compliance(issues, standards)
    
    # Return results
    module.exit_json(
        changed=False,
        issues=issues,
        score=score,
        ethical_assessment=ethical_assessment,
        compliance=compliance_status
    )


if __name__ == '__main__':
    main()
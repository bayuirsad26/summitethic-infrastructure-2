#!/usr/bin/env python3
"""
SummitEthic Inventory Report Generator

This script generates a comprehensive report of the Ansible inventory,
including hosts, groups, variables, and resource allocation.
"""

import os
import sys
import json
import yaml
import argparse
import subprocess
from datetime import datetime
from prettytable import PrettyTable
from collections import defaultdict


def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description='Generate inventory report')
    parser.add_argument('--environment', '-e', default='production',
                        help='Environment to report on (development, staging, production)')
    parser.add_argument('--output', '-o', default='inventory-report.md',
                        help='Output file for the report')
    parser.add_argument('--format', '-f', default='markdown',
                        choices=['markdown', 'json', 'yaml', 'text'],
                        help='Output format for the report')
    parser.add_argument('--inventory-path', default='ansible/inventories',
                        help='Path to the Ansible inventories directory')
    return parser.parse_args()


def get_ansible_inventory(inventory_path, environment):
    """Get inventory data using ansible-inventory command"""
    try:
        result = subprocess.run(
            ['ansible-inventory', '--inventory', f'{inventory_path}/{environment}/inventory.yml', '--list'],
            capture_output=True, text=True, check=True
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error running ansible-inventory: {e}")
        print(f"Error output: {e.stderr}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error decoding inventory JSON: {e}")
        sys.exit(1)


def extract_groups_and_hosts(inventory_data):
    """Extract groups and hosts from inventory data"""
    groups = {}
    all_hosts = {}
    
    # Process all hosts first
    if '_meta' in inventory_data and 'hostvars' in inventory_data['_meta']:
        all_hosts = inventory_data['_meta']['hostvars']
    
    # Process groups
    for group_name, group_data in inventory_data.items():
        if group_name != '_meta' and group_name != 'all':
            hosts = []
            if 'hosts' in group_data:
                hosts = group_data['hosts']
            elif 'children' in group_data:
                # This is a parent group, gather hosts from children
                for child in group_data['children']:
                    if child in inventory_data and 'hosts' in inventory_data[child]:
                        hosts.extend(inventory_data[child]['hosts'])
            
            groups[group_name] = {
                'hosts': sorted(hosts),
                'vars': group_data.get('vars', {}),
                'children': group_data.get('children', [])
            }
    
    return groups, all_hosts


def calculate_resource_allocation(groups, hosts):
    """Calculate total resource allocation by group"""
    resources = defaultdict(lambda: {'cpu': 0, 'memory': 0, 'disk': 0, 'count': 0})
    
    for group_name, group_data in groups.items():
        for host_name in group_data['hosts']:
            if host_name in hosts:
                host_data = hosts[host_name]
                
                # Extract CPU, memory, and disk resources
                cpu = host_data.get('cpus', 0)
                memory = 0
                disk = 0
                
                # Parse memory (convert to GB)
                memory_str = host_data.get('memory', '0')
                if isinstance(memory_str, str):
                    if memory_str.endswith('G'):
                        memory = float(memory_str[:-1])
                    elif memory_str.endswith('M'):
                        memory = float(memory_str[:-1]) / 1024
                    elif memory_str.endswith('T'):
                        memory = float(memory_str[:-1]) * 1024
                elif isinstance(memory_str, (int, float)):
                    memory = memory_str
                
                # Parse disk (if available)
                if 'root_volume_size' in host_data:
                    disk = host_data['root_volume_size']
                    
                # Add to group resources
                resources[group_name]['cpu'] += cpu
                resources[group_name]['memory'] += memory
                resources[group_name]['disk'] += disk
                resources[group_name]['count'] += 1
    
    return resources


def identify_ethical_considerations(groups, hosts):
    """Identify ethical considerations based on inventory data"""
    considerations = {
        'privacy': [],
        'resource_efficiency': [],
        'security': [],
        'sustainability': []
    }
    
    # Check for potential ethical issues
    
    # Privacy considerations
    for host_name, host_data in hosts.items():
        if 'mail' in host_name and not host_data.get('mailcow_privacy_mode', True):
            considerations['privacy'].append(f"Host {host_name} has mail server without privacy mode enabled")
    
    # Resource efficiency
    high_resource_hosts = []
    for host_name, host_data in hosts.items():
        cpu = host_data.get('cpus', 0)
        memory_str = host_data.get('memory', '0G')
        
        # Parse memory value
        memory = 0
        if isinstance(memory_str, str):
            if memory_str.endswith('G'):
                memory = float(memory_str[:-1])
        
        # Check for potentially overprovisioned resources
        if cpu > 8 or memory > 32:
            high_resource_hosts.append(host_name)
    
    if high_resource_hosts:
        considerations['resource_efficiency'].append(
            f"High resource allocation on hosts: {', '.join(high_resource_hosts)}"
        )
    
    # Security considerations
    for host_name, host_data in hosts.items():
        if not host_data.get('firewall_enabled', True):
            considerations['security'].append(f"Host {host_name} may not have firewall enabled")
    
    # Count total resources for sustainability assessment
    total_cpu = sum(host_data.get('cpus', 0) for host_data in hosts.values())
    if total_cpu > 50:
        considerations['sustainability'].append(
            f"Total CPU allocation ({total_cpu} cores) suggests review for optimization"
        )
    
    return considerations


def generate_markdown_report(environment, groups, hosts, resources, considerations):
    """Generate a Markdown format report"""
    report = f"# SummitEthic Inventory Report - {environment.capitalize()}\n\n"
    report += f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
    
    # Summary section
    report += "## Summary\n\n"
    report += f"- **Environment:** {environment}\n"
    report += f"- **Total Groups:** {len(groups)}\n"
    report += f"- **Total Hosts:** {len(hosts)}\n"
    report += f"- **Total CPU Cores:** {sum(r['cpu'] for r in resources.values())}\n"
    report += f"- **Total Memory (GB):** {sum(r['memory'] for r in resources.values()):.1f}\n\n"
    
    # Groups section
    report += "## Groups\n\n"
    
    for group_name, group_data in sorted(groups.items()):
        report += f"### {group_name}\n\n"
        report += f"- **Hosts:** {len(group_data['hosts'])}\n"
        
        if group_data['children']:
            report += f"- **Children:** {', '.join(group_data['children'])}\n"
        
        if group_data['hosts']:
            report += "\n**Hosts in this group:**\n\n"
            hosts_table = PrettyTable()
            hosts_table.field_names = ["Host", "IP Address", "CPUs", "Memory", "OS"]
            hosts_table.align = "l"
            
            for host_name in group_data['hosts']:
                if host_name in hosts:
                    host_data = hosts[host_name]
                    hosts_table.add_row([
                        host_name,
                        host_data.get('ansible_host', 'N/A'),
                        host_data.get('cpus', 'N/A'),
                        host_data.get('memory', 'N/A'),
                        f"{host_data.get('ansible_distribution', 'N/A')} {host_data.get('ansible_distribution_version', '')}"
                    ])
            
            report += "```\n" + hosts_table.get_string() + "\n```\n\n"
        
        # Group variables (if any)
        if group_data['vars']:
            report += "**Group Variables:**\n\n"
            report += "```yaml\n"
            report += yaml.dump(group_data['vars'], default_flow_style=False)
            report += "```\n\n"
        
        report += "---\n\n"
    
    # Resource allocation section
    report += "## Resource Allocation\n\n"
    
    resource_table = PrettyTable()
    resource_table.field_names = ["Group", "Hosts", "Total CPUs", "Total Memory (GB)", "Average CPU/Host", "Average Memory/Host (GB)"]
    resource_table.align = "l"
    
    for group_name, group_resources in sorted(resources.items()):
        if group_resources['count'] > 0:
            resource_table.add_row([
                group_name,
                group_resources['count'],
                group_resources['cpu'],
                f"{group_resources['memory']:.1f}",
                f"{group_resources['cpu'] / group_resources['count']:.1f}",
                f"{group_resources['memory'] / group_resources['count']:.1f}"
            ])
    
    report += "```\n" + resource_table.get_string() + "\n```\n\n"
    
    # Ethical considerations section
    report += "## Ethical Considerations\n\n"
    
    for category, issues in considerations.items():
        report += f"### {category.capitalize()}\n\n"
        if issues:
            for issue in issues:
                report += f"- {issue}\n"
        else:
            report += "- No concerns identified\n"
        report += "\n"
    
    return report


def generate_text_report(environment, groups, hosts, resources, considerations):
    """Generate a plain text format report"""
    report = f"SummitEthic Inventory Report - {environment.capitalize()}\n"
    report += f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
    
    # Summary section
    report += "SUMMARY\n"
    report += "=======\n\n"
    report += f"Environment: {environment}\n"
    report += f"Total Groups: {len(groups)}\n"
    report += f"Total Hosts: {len(hosts)}\n"
    report += f"Total CPU Cores: {sum(r['cpu'] for r in resources.values())}\n"
    report += f"Total Memory (GB): {sum(r['memory'] for r in resources.values()):.1f}\n\n"
    
    # Groups section
    report += "GROUPS\n"
    report += "======\n\n"
    
    for group_name, group_data in sorted(groups.items()):
        report += f"{group_name}\n"
        report += "-" * len(group_name) + "\n\n"
        report += f"Hosts: {len(group_data['hosts'])}\n"
        
        if group_data['children']:
            report += f"Children: {', '.join(group_data['children'])}\n"
        
        if group_data['hosts']:
            report += "\nHosts in this group:\n\n"
            hosts_table = PrettyTable()
            hosts_table.field_names = ["Host", "IP Address", "CPUs", "Memory", "OS"]
            hosts_table.align = "l"
            
            for host_name in group_data['hosts']:
                if host_name in hosts:
                    host_data = hosts[host_name]
                    hosts_table.add_row([
                        host_name,
                        host_data.get('ansible_host', 'N/A'),
                        host_data.get('cpus', 'N/A'),
                        host_data.get('memory', 'N/A'),
                        f"{host_data.get('ansible_distribution', 'N/A')} {host_data.get('ansible_distribution_version', '')}"
                    ])
            
            report += hosts_table.get_string() + "\n\n"
        
        report += "\n"
    
    # Resource allocation section
    report += "RESOURCE ALLOCATION\n"
    report += "===================\n\n"
    
    resource_table = PrettyTable()
    resource_table.field_names = ["Group", "Hosts", "Total CPUs", "Total Memory (GB)", "Average CPU/Host", "Average Memory/Host (GB)"]
    resource_table.align = "l"
    
    for group_name, group_resources in sorted(resources.items()):
        if group_resources['count'] > 0:
            resource_table.add_row([
                group_name,
                group_resources['count'],
                group_resources['cpu'],
                f"{group_resources['memory']:.1f}",
                f"{group_resources['cpu'] / group_resources['count']:.1f}",
                f"{group_resources['memory'] / group_resources['count']:.1f}"
            ])
    
    report += resource_table.get_string() + "\n\n"
    
    # Ethical considerations section
    report += "ETHICAL CONSIDERATIONS\n"
    report += "======================\n\n"
    
    for category, issues in considerations.items():
        report += f"{category.capitalize()}\n"
        report += "-" * len(category) + "\n\n"
        if issues:
            for issue in issues:
                report += f"- {issue}\n"
        else:
            report += "- No concerns identified\n"
        report += "\n"
    
    return report


def main():
    """Main function"""
    args = parse_arguments()
    
    # Get inventory data
    inventory_data = get_ansible_inventory(args.inventory_path, args.environment)
    
    # Process inventory data
    groups, hosts = extract_groups_and_hosts(inventory_data)
    
    # Calculate resource allocation
    resources = calculate_resource_allocation(groups, hosts)
    
    # Identify ethical considerations
    considerations = identify_ethical_considerations(groups, hosts)
    
    # Generate report based on format
    if args.format == 'markdown':
        report = generate_markdown_report(args.environment, groups, hosts, resources, considerations)
    elif args.format == 'text':
        report = generate_text_report(args.environment, groups, hosts, resources, considerations)
    elif args.format == 'json':
        report_data = {
            'metadata': {
                'environment': args.environment,
                'generated_at': datetime.now().isoformat(),
                'total_groups': len(groups),
                'total_hosts': len(hosts)
            },
            'groups': groups,
            'hosts': hosts,
            'resources': resources,
            'ethical_considerations': considerations
        }
        report = json.dumps(report_data, indent=2)
    elif args.format == 'yaml':
        report_data = {
            'metadata': {
                'environment': args.environment,
                'generated_at': datetime.now().isoformat(),
                'total_groups': len(groups),
                'total_hosts': len(hosts)
            },
            'groups': groups,
            'hosts': hosts,
            'resources': resources,
            'ethical_considerations': considerations
        }
        report = yaml.dump(report_data, default_flow_style=False)
    
    # Write report to file
    with open(args.output, 'w') as f:
        f.write(report)
    
    print(f"Inventory report for {args.environment} environment generated: {args.output}")


if __name__ == "__main__":
    main()
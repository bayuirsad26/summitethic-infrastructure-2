#!/usr/bin/env python3
"""
SummitEthic custom Ansible filters for data transformation
"""

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

import re
import json
import hashlib
import base64
import datetime
from ansible.errors import AnsibleFilterError


class FilterModule(object):
    """
    Custom filters for SummitEthic infrastructure
    """

    def filters(self):
        return {
            'to_env_format': self.to_env_format,
            'hash_password': self.hash_password,
            'anonymize_data': self.anonymize_data,
            'ethical_resource_limits': self.ethical_resource_limits,
            'format_timestamp': self.format_timestamp,
            'camel_to_snake': self.camel_to_snake,
            'snake_to_camel': self.snake_to_camel,
            'dict_to_list': self.dict_to_list
        }

    def to_env_format(self, dict_data):
        """
        Converts a dictionary to environment variable format
        Example: {'DB_USER': 'admin', 'DB_PASS': 'secret'} -> "DB_USER=admin\nDB_PASS=secret"
        """
        if not isinstance(dict_data, dict):
            raise AnsibleFilterError('to_env_format requires a dictionary')
        
        result = []
        for key, value in sorted(dict_data.items()):
            if value is None:
                value = ''
            # Ensure the value is a string and escape properly
            value_str = str(value)
            # Escape newlines and quotes
            value_str = value_str.replace('\n', '\\n').replace('"', '\\"')
            # Format as KEY=VALUE
            result.append(f"{key}={value_str}")
        
        return '\n'.join(result)

    def hash_password(self, password, algorithm='sha256', salt=None):
        """
        Creates a secure hash of a password with optional salt
        """
        if not isinstance(password, str):
            raise AnsibleFilterError('hash_password requires a string')
        
        if not salt:
            # Generate a random salt if not provided
            salt = hashlib.sha256(str(datetime.datetime.now().timestamp()).encode()).hexdigest()[:16]
        
        hash_obj = None
        if algorithm == 'sha256':
            hash_obj = hashlib.sha256((password + salt).encode())
        elif algorithm == 'sha512':
            hash_obj = hashlib.sha512((password + salt).encode())
        elif algorithm == 'md5':
            # Not recommended for security but included for compatibility
            hash_obj = hashlib.md5((password + salt).encode())
        else:
            raise AnsibleFilterError(f'Unsupported hash algorithm: {algorithm}')
        
        return f"{algorithm}${salt}${hash_obj.hexdigest()}"

    def anonymize_data(self, data, fields_to_anonymize=None):
        """
        Anonymizes sensitive data fields for ethical data handling
        """
        if fields_to_anonymize is None:
            fields_to_anonymize = [
                'password', 'email', 'phone', 'address', 'name', 'credit_card',
                'ssn', 'social', 'secret', 'token', 'key'
            ]
        
        if isinstance(data, dict):
            result = {}
            for key, value in data.items():
                # Check if this key should be anonymized
                should_anonymize = any(sensitive in key.lower() for sensitive in fields_to_anonymize)
                
                if should_anonymize and isinstance(value, str):
                    if 'email' in key.lower() and '@' in value:
                        # Partially anonymize emails (preserve domain)
                        username, domain = value.split('@', 1)
                        result[key] = f"{username[0]}{'*' * (len(username) - 2)}{username[-1]}@{domain}"
                    else:
                        # Completely anonymize other sensitive fields
                        result[key] = '********'
                elif isinstance(value, (dict, list)):
                    # Recursively process nested structures
                    result[key] = self.anonymize_data(value, fields_to_anonymize)
                else:
                    result[key] = value
            return result
        elif isinstance(data, list):
            return [self.anonymize_data(item, fields_to_anonymize) for item in data]
        else:
            return data

    def ethical_resource_limits(self, service_type, scale='medium'):
        """
        Calculates ethical resource limits based on service type and scale
        """
        # Define base resource limits for different service types
        base_limits = {
            'web': {'cpu': 1, 'memory': 1024, 'connections': 100},
            'api': {'cpu': 2, 'memory': 2048, 'connections': 200},
            'database': {'cpu': 2, 'memory': 4096, 'connections': 50},
            'cache': {'cpu': 1, 'memory': 2048, 'connections': 500},
            'worker': {'cpu': 2, 'memory': 2048, 'connections': 20},
            'monitoring': {'cpu': 1, 'memory': 3072, 'connections': 30},
        }
        
        # Define scale multipliers
        scale_multipliers = {
            'minimal': 0.5,
            'low': 0.7,
            'medium': 1.0,
            'high': 1.5,
            'maximum': 2.0
        }
        
        if service_type not in base_limits:
            raise AnsibleFilterError(f'Unknown service type: {service_type}')
        if scale not in scale_multipliers:
            raise AnsibleFilterError(f'Unknown scale: {scale}')
        
        # Calculate limits based on scale
        multiplier = scale_multipliers[scale]
        result = {}
        for key, value in base_limits[service_type].items():
            if key in ['cpu', 'connections']:
                # Integer values
                result[key] = max(1, int(value * multiplier))
            else:
                # Memory - round to nearest 64MB
                result[key] = int(round((value * multiplier) / 64) * 64)
        
        return result

    def format_timestamp(self, timestamp, format_str='%Y-%m-%d %H:%M:%S'):
        """
        Formats a timestamp in a human-readable format
        """
        if isinstance(timestamp, (int, float)):
            dt = datetime.datetime.fromtimestamp(timestamp)
        elif isinstance(timestamp, str):
            try:
                # Try to parse as integer first
                dt = datetime.datetime.fromtimestamp(int(timestamp))
            except ValueError:
                # If that fails, try to parse as ISO format
                dt = datetime.datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
        else:
            raise AnsibleFilterError(f'Unsupported timestamp format: {type(timestamp)}')
        
        return dt.strftime(format_str)

    def camel_to_snake(self, text):
        """
        Converts camelCase to snake_case
        Example: camelCase -> camel_case
        """
        if not isinstance(text, str):
            raise AnsibleFilterError('camel_to_snake requires a string')
        
        # Insert underscore before uppercase letters and convert to lowercase
        s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', text)
        return re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1).lower()

    def snake_to_camel(self, text):
        """
        Converts snake_case to camelCase
        Example: snake_case -> snakeCase
        """
        if not isinstance(text, str):
            raise AnsibleFilterError('snake_to_camel requires a string')
        
        # Split by underscore and capitalize each word (except the first)
        components = text.split('_')
        return components[0] + ''.join(x.title() for x in components[1:])

    def dict_to_list(self, dict_data, key_name='name', value_name='value'):
        """
        Converts a dictionary to a list of dictionaries with key/value pairs
        Example: {'foo': 'bar'} -> [{'name': 'foo', 'value': 'bar'}]
        """
        if not isinstance(dict_data, dict):
            raise AnsibleFilterError('dict_to_list requires a dictionary')
        
        return [{key_name: k, value_name: v} for k, v in dict_data.items()]
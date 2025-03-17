#!/usr/bin/env python3
"""
SummitEthic security filters for Ansible
"""

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

import re
import json
import base64
import hashlib
import secrets
import string
from cryptography.fernet import Fernet
from ansible.errors import AnsibleFilterError


class FilterModule(object):
    """
    Security filters for SummitEthic infrastructure
    """

    def filters(self):
        return {
            'generate_password': self.generate_password,
            'encrypt_string': self.encrypt_string,
            'decrypt_string': self.decrypt_string,
            'mask_sensitive': self.mask_sensitive,
            'secure_random': self.secure_random,
            'validate_cert': self.validate_cert,
            'sanitize_input': self.sanitize_input,
        }

    def generate_password(self, length=16, complexity='high'):
        """
        Generates a secure random password with configurable complexity
        """
        if not isinstance(length, int) or length < 8:
            raise AnsibleFilterError('Password length must be an integer >= 8')
        
        # Define character sets based on complexity
        lower = string.ascii_lowercase
        upper = string.ascii_uppercase
        digits = string.digits
        special = r'!@#$%^&*()-_=+[]{}|;:,.<>?'
        
        if complexity == 'low':
            chars = lower + upper + digits
            requirements = [
                lambda s: any(c.islower() for c in s),
                lambda s: any(c.isupper() for c in s),
                lambda s: any(c.isdigit() for c in s)
            ]
        elif complexity == 'medium':
            chars = lower + upper + digits + special[:8]  # Fewer special chars
            requirements = [
                lambda s: any(c.islower() for c in s),
                lambda s: any(c.isupper() for c in s),
                lambda s: any(c.isdigit() for c in s),
                lambda s: any(c in special[:8] for c in s)
            ]
        elif complexity == 'high':
            chars = lower + upper + digits + special
            requirements = [
                lambda s: any(c.islower() for c in s),
                lambda s: any(c.isupper() for c in s),
                lambda s: any(c.isdigit() for c in s),
                lambda s: any(c in special for c in s),
                lambda s: len(set(s)) >= min(10, length // 2)  # Ensure character diversity
            ]
        else:
            raise AnsibleFilterError(f'Invalid complexity level: {complexity}')
        
        # Generate password until all requirements are met
        while True:
            password = ''.join(secrets.choice(chars) for _ in range(length))
            if all(req(password) for req in requirements):
                return password

    def encrypt_string(self, plaintext, key=None):
        """
        Encrypts a string using Fernet symmetric encryption
        """
        if not isinstance(plaintext, str):
            raise AnsibleFilterError('encrypt_string requires a string')
        
        try:
            # Generate a key from the provided key or create a new one
            if key:
                if len(key) < 32:
                    # Ensure key is at least 32 bytes by padding or hashing
                    key = hashlib.sha256(key.encode()).digest()
                else:
                    key = key.encode()
                
                # Convert to Fernet key format (32 url-safe base64-encoded bytes)
                fernet_key = base64.urlsafe_b64encode(key[:32])
            else:
                fernet_key = Fernet.generate_key()
            
            cipher = Fernet(fernet_key)
            encrypted = cipher.encrypt(plaintext.encode())
            
            # Return both the encrypted data and the key if none was provided
            if key:
                return encrypted.decode()
            else:
                return {
                    'encrypted': encrypted.decode(),
                    'key': fernet_key.decode()
                }
        except Exception as e:
            raise AnsibleFilterError(f'Error encrypting string: {str(e)}')

    def decrypt_string(self, encrypted, key):
        """
        Decrypts a string using Fernet symmetric encryption
        """
        if not isinstance(encrypted, str) or not isinstance(key, str):
            raise AnsibleFilterError('decrypt_string requires two strings (encrypted, key)')
        
        try:
            # Convert key to proper format if needed
            if len(key) != 44 or not key.endswith('='):
                # Ensure key is 32 bytes
                if len(key) < 32:
                    key = hashlib.sha256(key.encode()).digest()
                else:
                    key = key.encode()[:32]
                
                # Convert to Fernet key format
                key = base64.urlsafe_b64encode(key)
            else:
                key = key.encode()
            
            cipher = Fernet(key)
            decrypted = cipher.decrypt(encrypted.encode()).decode()
            return decrypted
        except Exception as e:
            raise AnsibleFilterError(f'Error decrypting string: {str(e)}')

    def mask_sensitive(self, text, mask_char='*', preserve_length=True, preserve_ends=True):
        """
        Masks sensitive data for logging and display
        """
        if not isinstance(text, str):
            return text
        
        # If the string is too short, mask completely
        if len(text) < 4:
            return mask_char * len(text)
        
        if preserve_length:
            if preserve_ends:
                # Preserve first and last character
                masked = text[0] + mask_char * (len(text) - 2) + text[-1]
            else:
                # Mask entire string but preserve length
                masked = mask_char * len(text)
        else:
            # Just use a fixed number of mask characters
            masked = mask_char * 8
        
        return masked

    def secure_random(self, length=32, type='hex'):
        """
        Generates cryptographically secure random values
        """
        if type == 'hex':
            return secrets.token_hex(length // 2)  # Each hex digit is 4 bits
        elif type == 'bytes':
            return base64.b64encode(secrets.token_bytes(length)).decode()
        elif type == 'urlsafe':
            return secrets.token_urlsafe(length)
        elif type == 'integer':
            # Generate a random integer with the specified number of digits
            return secrets.randbelow(10 ** length)
        else:
            raise AnsibleFilterError(f'Unsupported random type: {type}')

    def validate_cert(self, cert_data):
        """
        Validates certificate properties and returns metadata
        """
        # This is a simplified implementation that would need to be expanded
        # with cryptography library in a real-world scenario
        if not isinstance(cert_data, str):
            raise AnsibleFilterError('validate_cert requires a string containing certificate data')
        
        # Check for basic PEM format
        if '-----BEGIN CERTIFICATE-----' not in cert_data or '-----END CERTIFICATE-----' not in cert_data:
            return {
                'valid': False,
                'error': 'Certificate data is not in PEM format'
            }
        
        # This is where you would add proper certificate parsing
        # For now, return some basic data
        return {
            'valid': True,
            'format': 'PEM',
            'length': len(cert_data)
        }

    def sanitize_input(self, input_string, allowed_pattern=None):
        """
        Sanitizes user input to prevent injection attacks
        """
        if not isinstance(input_string, str):
            return input_string
        
        # Default pattern allows alphanumeric, space, and common punctuation
        if not allowed_pattern:
            allowed_pattern = r'^[A-Za-z0-9\s\.,\-_\(\)]+$'
        
        # Check if the string matches the allowed pattern
        if re.match(allowed_pattern, input_string):
            return input_string
        else:
            # Return sanitized version (only keeping allowed chars)
            return re.sub(r'[^A-Za-z0-9\s\.,\-_\(\)]', '', input_string)
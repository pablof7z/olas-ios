#!/usr/bin/env python3
import os
import re

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    original = content
    
    # Fix observe to subscribe
    content = re.sub(r'\.observe\(', '.subscribe(', content)
    
    # Fix NDKDataSource to NDKSubscription
    content = re.sub(r'NDKDataSource<', 'NDKSubscription<', content)
    content = re.sub(r'NDKDataSource\b', 'NDKSubscription', content)
    
    # Fix specific patterns that might appear
    content = re.sub(r'profileManager\.observe\(', 'profileManager.subscribe(', content)
    content = re.sub(r'ndk\.observe\(', 'ndk.subscribe(', content)
    
    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Fixed: {filepath}")

# Find all Swift files
for root, dirs, files in os.walk('Olas'):
    for file in files:
        if file.endswith('.swift'):
            filepath = os.path.join(root, file)
            fix_file(filepath)

print("Done!")
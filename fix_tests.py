import os
import re

for root, _, files in os.walk('test'):
    for f in files:
        if f.endswith('.dart'):
            path = os.path.join(root, f)
            with open(path, 'r') as file:
                content = file.read()
                
            # clean up first
            content = content.replace(", district: '전체'", "")
            content = content.replace(", district: '전체'공연예정'", "공연예정'")
            
            # Re-insert accurately: 
            # We look for "state: 'something'" and append ", district: '전체'"
            # Or "state: PerformanceState.xxx"
            
            # Simple approach: state: followed by anything up to the next comma or parenthesis
            content = re.sub(r"(state:\s*[^,)]+)", r"\1, district: '전체'", content)
            
            with open(path, 'w') as file:
                file.write(content)
print("done")

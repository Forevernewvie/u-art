import sys

def parse_lcov_detail(file_path):
    current_file = ""
    file_stats = {}
    
    with open(file_path, 'r') as f:
        for line in f:
            if line.startswith('SF:'):
                current_file = line.strip()[3:]
                # Exclude .g.dart files
                if current_file.endswith('.g.dart'):
                    current_file = ""
                    continue
                file_stats[current_file] = {'total': 0, 'covered': 0, 'missed_lines': []}
            elif line.startswith('DA:') and current_file:
                parts = line.strip().split(',')
                line_num = int(parts[0][3:])
                hits = int(parts[1])
                file_stats[current_file]['total'] += 1
                if hits > 0:
                    file_stats[current_file]['covered'] += 1
                else:
                    file_stats[current_file]['missed_lines'].append(line_num)
                    
    print("=== Coverage Details (Excluding .g.dart) ===")
    total_lines = 0
    covered_lines = 0
    for f, stats in file_stats.items():
        total = stats['total']
        covered = stats['covered']
        total_lines += total
        covered_lines += covered
        if total > 0 and covered < total:
            cov_pct = (covered / total) * 100
            print(f"{f}: {cov_pct:.1f}% ({covered}/{total}) - Missed: {stats['missed_lines']}")
            
    if total_lines > 0:
        print(f"Total Coverage: {(covered_lines/total_lines)*100:.2f}%")

parse_lcov_detail('coverage/lcov.info')

import os
import glob

def get_code_block(filepath, filename):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            code = f.read()
    except:
        with open(filepath, 'r', encoding='gbk') as f:
            code = f.read()
    
    return f"% {filename}\n\\begin{{lstlisting}}[language=matlab]\n{code}\n\\end{{lstlisting}}\n\n"

def main():
    base_dir = r"e:\国赛建模\B"
    
    # Problem 2
    p2_dir = os.path.join(base_dir, "问题2_第二检测点选择")
    p2_files = [
        "main_problem2.m",
        "problem2_discrete_sweep.m",
        "problem2_sweep_path.m",
        "get_continuous_region.m",
        "config_problem2.m",
        "export_problem2.m"
    ]
    p2_content = "\\subsection{问题二相关代码}\n\n"
    for f in p2_files:
        path = os.path.join(p2_dir, f)
        if os.path.exists(path):
            p2_content += get_code_block(path, f)
            
    # Problem 3
    p3_files = glob.glob(os.path.join(base_dir, "problem3_*.m"))
    p3_content = "\\subsection{问题三相关代码}\n\n"
    for path in p3_files:
        p3_content += get_code_block(path, os.path.basename(path))

    # Problem 4
    p4_files = glob.glob(os.path.join(base_dir, "problem4_*.m"))
    p4_content = "\\subsection{问题四相关代码}\n\n"
    for path in p4_files:
        p4_content += get_code_block(path, os.path.basename(path))

    all_content = p2_content + p3_content + p4_content
    
    # Read tex file
    tex_file = os.path.join(base_dir, "primary template.tex")
    with open(tex_file, 'r', encoding='utf-8') as f:
        tex_data = f.read()
        
    # Replace \end{appendices}
    tex_data = tex_data.replace("\\end{appendices}", all_content + "\\end{appendices}")
    
    with open(tex_file, 'w', encoding='utf-8') as f:
        f.write(tex_data)
        
    print("Successfully appended Problem 2, 3, 4 codes to the tex file.")

if __name__ == '__main__':
    main()

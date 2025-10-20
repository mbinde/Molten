import os

def count_loc(directory, comment_chars=['#', '//'], extensions=['.py', '.java', '.c', '.cpp', '.js', '.sh']):
    """
    Counts non-blank, non-comment lines of code in a directory tree.

    Args:
        directory (str): The root directory to start counting from.
        comment_chars (list): A list of characters or strings that denote the start of a comment.
                              (e.g., '#', '//', '/*').
        extensions (list): A list of file extensions to consider for counting.

    Returns:
        int: The total count of non-blank, non-comment lines of code.
    """
    total_loc = 0
    for root, _, files in os.walk(directory):
        for file in files:
            if any(file.endswith(ext) for ext in extensions):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                        for line in f:
                            stripped_line = line.strip()
                            if stripped_line:  # Check if not blank
                                is_comment = False
                                for char in comment_chars:
                                    if stripped_line.startswith(char):
                                        is_comment = True
                                        break
                                if not is_comment:
                                    total_loc += 1
                except Exception as e:
                    print(f"Error reading file {filepath}: {e}")
    return total_loc

if __name__ == "__main__":
    target_directory = "."  # Count from the current directory
    # Customize comment characters and extensions as needed
    loc_count = count_loc(target_directory, 
                          comment_chars=['#', '//', '/*'], 
                          extensions=['.py', '.java', '.c', '.cpp', '.js', '.sh', '.go', '.rb'])
    print(f"Total non-blank, non-comment lines of code: {loc_count}")

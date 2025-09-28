import csv
import re

def convert_effetre_to_csv(input_file, output_file):
    """
    Convert Effetre text file to CSV format.
    
    Args:
        input_file (str): Path to input text file
        output_file (str): Path to output CSV file
    """
    
    # CSV headers as specified
    headers = ['manufacturer', 'code', 'name', 'start_date', 'end_date', 
               'manufacturer_description', 'tags', 'synonyms', 'image']
    
    try:
        with open(input_file, 'r', encoding='utf-8') as txt_file:
            with open(output_file, 'w', newline='', encoding='utf-8') as csv_file:
                writer = csv.writer(csv_file)
                
                # Write headers
                writer.writerow(headers)
                
                row_count = 0
                for line in txt_file:
                    line = line.strip()
                    if line:  # Skip empty lines
                        # Parse the line: "Effetre 591XXX Name"
                        parts = line.split(' ', 2)  # Split into max 3 parts
                        
                        if len(parts) >= 3:
                            manufacturer_raw = parts[0]  # "Effetre"
                            code_raw = parts[1]          # "591XXX"
                            name = parts[2]              # Everything else
                            
                            # Transform manufacturer: Effetre -> EF
                            manufacturer = "EF"
                            
                            # Transform code: remove "591" prefix, keep zeros
                            if code_raw.startswith("591"):
                                code = code_raw[3:]  # Remove first 3 characters
                            else:
                                code = code_raw  # Fallback if format is unexpected
                            
                            # Create row with empty fields for missing data
                            row = [
                                manufacturer,  # manufacturer
                                code,          # code
                                name,          # name
                                "",            # start_date (empty)
                                "",            # end_date (empty)
                                "",            # manufacturer_description (empty)
                                "",            # tags (empty)
                                "",            # synonyms (empty)
                                ""             # image (empty)
                            ]
                            
                            writer.writerow(row)
                            row_count += 1
                        else:
                            print(f"Warning: Skipping malformed line: {line}")
                
                print(f"Successfully converted {row_count} rows from '{input_file}' to '{output_file}'")
                return True
                
    except FileNotFoundError:
        print(f"Error: Input file '{input_file}' not found.")
        return False
    except Exception as e:
        print(f"Error during conversion: {e}")
        return False

# Main execution
if __name__ == "__main__":
    input_file = "effetre.txt"
    output_file = "effetre.csv"
    
    convert_effetre_to_csv(input_file, output_file)
    
    # Optional: Print first few rows to verify
    print("\nFirst 5 rows of output:")
    try:
        with open(output_file, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            for i, row in enumerate(reader):
                if i < 6:  # Header + 5 data rows
                    print(f"Row {i}: {row}")
                else:
                    break
    except:
        pass
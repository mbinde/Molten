import csv
import json
import re
import sys
import os

def clean_quoted_values(value):
    """Clean up quoted values in the CSV data"""
    if isinstance(value, str):
        # Remove extra quotes and clean up the format
        cleaned = value.strip().strip('"')
        # Handle cases like '"clear", "transparent"'
        if cleaned.startswith('"') and cleaned.endswith('"'):
            cleaned = cleaned[1:-1]
        return cleaned
    return value

def parse_tags(tags_str):
    """Parse the tags string into a list"""
    if not tags_str or tags_str.strip() == '':
        return []
    
    # Clean the string and extract quoted values
    cleaned = clean_quoted_values(tags_str)
    # Split by comma and clean each item
    tags = [tag.strip().strip('"') for tag in cleaned.split(',')]
    return [tag for tag in tags if tag]  # Remove empty strings

def parse_synonyms(synonyms_str):
    """Parse the synonyms string into a list"""
    if not synonyms_str or synonyms_str.strip() == '':
        return []
    
    # Clean the string and extract quoted values
    cleaned = clean_quoted_values(synonyms_str)
    # Split by comma and clean each item
    synonyms = [syn.strip().strip('"') for syn in cleaned.split(',')]
    return [syn for syn in synonyms if syn]  # Remove empty strings

def convert_csv_to_json(csv_file_path, json_file_path):
    """Convert CSV file to JSON with proper structure"""
    
    data = []
    
    try:
        with open(csv_file_path, 'r', encoding='utf-8') as csvfile:
            # Read all lines to handle the header properly
            lines = csvfile.readlines()
            
            # Skip the header row and process data rows
            data_lines = lines[1:] if len(lines) > 1 else lines
            
            # Process each data line
            for line in data_lines:
                # Split the CSV line (handling quoted values)
                import csv as csv_module
                row_data = next(csv_module.reader([line]))
            
            for line in data_lines:
                # Split the CSV line (handling quoted values)
                import csv as csv_module
                row_data = next(csv_module.reader([line]))
                
                # Clean up values
                values = [val.strip() if val else None for val in row_data]
                
                # Extract values by position
                original_id = values[0] if len(values) > 0 else ""  # This was the old product code
                code = str(values[1]) if len(values) > 1 and values[1] is not None else ""
                manufacturer = values[2] if len(values) > 2 else ""
                name = values[3] if len(values) > 3 else ""
                description = values[4] if len(values) > 4 and values[4] else None
                synonyms = values[5] if len(values) > 5 and values[5] else None  # Assuming synonyms is in position 5
                
                # Create the new id by combining manufacturer and code with dash
                new_id = f"{manufacturer}-{code}" if manufacturer and code else (original_id or "")
                
                # Find and parse the tags column (usually the last one with quotes)
                tags_value = values[6] if len(values) > 6 else (values[5] if not synonyms else "")
                tags = parse_tags(tags_value) if tags_value else []
                
                # Create the JSON object
                item = {
                    "id": new_id,
                    "code": code,
                    "manufacturer": manufacturer,
                    "name": name,
                    "description": description,
                    "synonyms": synonyms,
                    "tags": tags
                }
                
                data.append(item)
        
        # Create the final JSON structure with "colors" at the top level
        final_json = {"colors": data}
        
        # Write to JSON file
        with open(json_file_path, 'w', encoding='utf-8') as jsonfile:
            json.dump(final_json, jsonfile, indent=2, ensure_ascii=False)
        
        print(f"Successfully converted {csv_file_path} to {json_file_path}")
        print(f"Converted {len(data)} records")
        
        # Display a sample of the converted data
        if data:
            print("\nSample converted data:")
            print(json.dumps(data[0], indent=2))
        
    except FileNotFoundError:
        print(f"Error: Could not find the file {csv_file_path}")
    except Exception as e:
        print(f"Error during conversion: {str(e)}")

# Example usage
if __name__ == "__main__":
    # Check if filename is provided as command line argument
    if len(sys.argv) < 2:
        print("Usage: python csv_to_json.py <input_csv_file>")
        print("Example: python csv_to_json.py 'Rod colors Sheet1.csv'")
        sys.exit(1)
    
    # Get the input filename from command line argument
    input_csv = sys.argv[1]
    
    # Check if the file exists
    if not os.path.exists(input_csv):
        print(f"Error: File '{input_csv}' not found.")
        sys.exit(1)
    
    # Generate output filename by replacing .csv with .json
    if input_csv.lower().endswith('.csv'):
        output_json = input_csv[:-4] + '.json'
    else:
        output_json = input_csv + '.json'
    
    convert_csv_to_json(input_csv, output_json)
    
    # Optional: Read and display the JSON file
    try:
        with open(output_json, 'r', encoding='utf-8') as f:
            data = json.load(f)
            colors = data.get('colors', [])
            print(f"\nFinal JSON structure with {len(colors)} items:")
            for item in colors:
                print(f"- {item['id']}: {item['name']} ({item['manufacturer']})")
    except FileNotFoundError:
        print("JSON file not created or not found")

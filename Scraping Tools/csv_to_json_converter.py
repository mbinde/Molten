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

def convert_tsv_to_json(tsv_file_path, json_file_path):
    """Convert TSV file to JSON with proper structure"""
    
    data = []
    
    try:
        with open(tsv_file_path, 'r', encoding='utf-8') as tsvfile:
            # Read the TSV with proper handling using DictReader with tab delimiter
            reader = csv.DictReader(tsvfile, delimiter='\t')
            
            for row in reader:
                # Clean up the values - map TSV columns to correct JSON fields
                manufacturer = row.get('manufacturer', '').strip() if row.get('manufacturer') else ""
                code = str(row.get('code', '')).strip() if row.get('code') else ""
                name = row.get('name', '').strip() if row.get('name') else ""
                start_date = row.get('start_date', '').strip() if row.get('start_date') else ""
                end_date = row.get('end_date', '').strip() if row.get('end_date') else ""
                # manufacturer_description column maps to manufacturer_description field
                manufacturer_description = row.get('manufacturer_description', '').strip() if row.get('manufacturer_description') else ""
                
                # Create the new id by combining manufacturer and code with dash
                # Pad the code to maintain leading zeros (assuming 3 digits)
                padded_code = code.zfill(3) if code.isdigit() else code
                item_id = f"{manufacturer}-{padded_code}" if manufacturer and code else ""
                
                # Parse tags and synonyms from their respective columns
                tags_value = row.get('tags', '')
                tags = parse_tags(tags_value) if tags_value else []
                
                # synonyms column maps to synonyms field
                synonyms_value = row.get('synonyms', '')
                synonyms = parse_synonyms(synonyms_value) if synonyms_value else []
                
                # Get coe field
                coe = row.get('coe', '').strip() if row.get('coe') else ""
                
                # Get type field - default to "other" if blank
                type_value = row.get('type', '').strip() if row.get('type') else ""
                if not type_value:
                    type_value = "other"
                
                # Get manufacturer_url field
                manufacturer_url = row.get('manufacturer_url', '').strip() if row.get('manufacturer_url') else ""
                
                # Get image path
                image_path = row.get('image_path', '').strip() if row.get('image_path') else ""
                
                # Create the JSON object
                item = {
                    "id": item_id,
                    "code": padded_code,
                    "manufacturer": manufacturer,
                    "name": name,
                    "start_date": start_date,
                    "end_date": end_date,
                    "manufacturer_description": manufacturer_description,
                    "synonyms": synonyms,
                    "tags": tags,
                    "coe": coe,
                    "type": type_value,
                    "manufacturer_url": manufacturer_url,
                    "image_path": image_path
                }
                
                data.append(item)
        
        # Create the final JSON structure with "colors" at the top level
        final_json = {"colors": data}
        
        # Write to JSON file
        with open(json_file_path, 'w', encoding='utf-8') as jsonfile:
            json.dump(final_json, jsonfile, indent=2, ensure_ascii=False)
        
        print(f"Successfully converted {tsv_file_path} to {json_file_path}")
        print(f"Converted {len(data)} records")
        
    except FileNotFoundError:
        print(f"Error: Could not find the file {tsv_file_path}")
    except Exception as e:
        print(f"Error during conversion: {str(e)}")

# Example usage
if __name__ == "__main__":
    # Check if filename is provided as command line argument
    if len(sys.argv) < 2:
        print("Usage: python tsv_to_json.py <input_tsv_file>")
        print("Example: python tsv_to_json.py 'Rod colors Sheet1.tsv'")
        sys.exit(1)
    
    # Get the input filename from command line argument
    input_tsv = sys.argv[1]
    
    # Check if the file exists
    if not os.path.exists(input_tsv):
        print(f"Error: File '{input_tsv}' not found.")
        sys.exit(1)
    
    # Generate output filename by replacing file extension with .json
    base_name = os.path.splitext(input_tsv)[0]
    output_json = base_name + '.json'
    
    convert_tsv_to_json(input_tsv, output_json)
    
    # Optional: Read and display the JSON file summary
    try:
        with open(output_json, 'r', encoding='utf-8') as f:
            data = json.load(f)
            colors = data.get('colors', [])
            print(f"\nFinal JSON created with {len(colors)} items")
    except FileNotFoundError:
        print("JSON file not created or not found")

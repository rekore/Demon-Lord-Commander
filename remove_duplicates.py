import json
import sys

def remove_duplicates(input_file, output_file):
    try:
        # Load the JSON data
        with open(input_file, 'r') as f:
            data = json.load(f)
        
        # Assume data is a list of card dictionaries
        if not isinstance(data, list):
            raise ValueError("JSON must be a list of card objects.")
        
        # Use a set to track seen cards (using sorted JSON string as key for uniqueness)
        seen = set()
        removed = []
        new_data = []
        
        for card in data:
            # Serialize the card to a sorted JSON string to use as a unique key
            card_key = json.dumps(card, sort_keys=True)
            
            if card_key in seen:
                removed.append(card)
            else:
                seen.add(card_key)
                new_data.append(card)
        
        # Alert (print) the removed cards
        if removed:
            print("Removed duplicate cards:")
            for card in removed:
                # Assuming each card has a 'name' field; adjust if needed
                card_name = card.get('name', 'Unnamed card')
                print(f"- {card_name} (duplicate entry)")
        else:
            print("No duplicates found.")
        
        # Write the cleaned data to the output file
        with open(output_file, 'w') as f:
            json.dump(new_data, f, indent=4)
        
        print(f"Cleaned library saved to {output_file}")
    
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)

# Usage: python script.py input.json output.json
if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python remove_duplicates.py <input_file> <output_file>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    remove_duplicates(input_file, output_file)
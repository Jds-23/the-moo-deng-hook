import requests
import warnings
from urllib3.exceptions import NotOpenSSLWarning
warnings.filterwarnings('ignore', category=NotOpenSSLWarning)

# ... rest of your existing code ...

def fetch_latest_price_update(id: str):
    url = f"https://hermes.pyth.network/v2/updates/price/latest?ids%5B%5D={id}"
    
    headers = {
        "accept": "application/json"
    }
    
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()  # Raise an HTTPError for bad responses (4xx and 5xx)
        data = response.json()
        # Extract and return the binary data
        return data.get("binary", {}).get("data", [])
    except requests.exceptions.RequestException as e:
        print("Error fetching data:", e)
        return []

# Call the function and print the first element of binary data
if __name__ == "__main__":
    id = "ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace"
    data = fetch_latest_price_update(id)
    if data:
        print(data[0])  # Print the first element of the binary data
    else:
        print("No data found")
import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import json
import os
import logging
from typing import List, Dict, Any, TypedDict
from google.cloud.firestore_v1 import Client as FirestoreClient # Added import

# --- Configuration ---
# IMPORTANT: Replace with the actual path to your service account key JSON file
# Ensure this file is NOT committed to version control (add to .gitignore)
SERVICE_ACCOUNT_KEY_PATH: str = os.path.join(os.path.dirname(__file__), 'serviceAccountKey.json')
# Path to your card data JSON file
CARD_DATA_FILE_PATH: str = os.path.join(os.path.dirname(__file__), 'cardData.json')
CARD_TOPICS_COLLECTION: str = 'cardTopics'

# --- Logging Setup ---
logging.basicConfig(
	level=logging.INFO,
	format='%(asctime)s - %(levelname)s - populateFirestore - %(message)s',
	datefmt='%Y-%m-%d %H:%M:%S'
)
logger: logging.Logger = logging.getLogger(__name__)

# --- Type Definitions (for type hinting and mypy) ---
class Card(TypedDict):
	text: str
	type: str # "black" or "white"
	pick: int # Optional, only for black cards

class CardTopicData(TypedDict):
	topicId: str
	topicName: str
	language: str
	description: str
	cards: List[Card]

def initialize_firebase_app() -> FirestoreClient: # Changed type hint
	"""
	Initializes the Firebase Admin SDK and returns a Firestore client.

	Raises:
		FileNotFoundError: If the service account key file is not found.
		Exception: If Firebase initialization fails.

	Returns:
		FirestoreClient: An initialized Firestore client. # Changed type hint
	"""
	logger.info("Initializing Firebase Admin SDK...")
	if not os.path.exists(SERVICE_ACCOUNT_KEY_PATH):
		error_message: str = f"Service account key file not found at: {SERVICE_ACCOUNT_KEY_PATH}"
		logger.error(error_message)
		raise FileNotFoundError(error_message)
	
	try:
		cred: credentials.Certificate = credentials.Certificate(SERVICE_ACCOUNT_KEY_PATH)
		firebase_admin.initialize_app(cred)
		db: FirestoreClient = firestore.client() # Changed type hint
		logger.info("Firebase Admin SDK initialized successfully.")
		return db
	except Exception as e:
		logger.error(f"Failed to initialize Firebase Admin SDK: {e}")
		raise

def load_card_data_from_file(file_path: str) -> List[CardTopicData]:
	"""
	Loads card topic data from a JSON file.

	Args:
		file_path (str): The path to the JSON file containing card data.

	Raises:
		FileNotFoundError: If the card data file is not found.
		json.JSONDecodeError: If the JSON file is malformed.

	Returns:
		List[CardTopicData]: A list of card topic data.
	"""
	logger.info(f"Loading card data from: {file_path}")
	if not os.path.exists(file_path):
		error_message: str = f"Card data file not found at: {file_path}"
		logger.error(error_message)
		raise FileNotFoundError(error_message)
	
	try:
		with open(file_path, 'r', encoding='utf-8') as f:
			data: List[CardTopicData] = json.load(f)
		logger.info(f"Successfully loaded {len(data)} card topic(s).")
		return data
	except json.JSONDecodeError as e:
		logger.error(f"Error decoding JSON from {file_path}: {e}")
		raise
	except Exception as e:
		logger.error(f"An unexpected error occurred while loading card data: {e}")
		raise

def populate_firestore(db: FirestoreClient, card_topics_data: List[CardTopicData]) -> None: # Changed type hint
	"""
	Populates Firestore with card topic data.
	Each topic will be a document in the CARD_TOPICS_COLLECTION.
	The document ID will be the topicId from the data.

	Args:
		db (firestore.Client): The Firestore client.
		card_topics_data (List[CardTopicData]): A list of card topics to upload.
	"""
	logger.info(f"Starting Firestore population for {len(card_topics_data)} topic(s)...")
	for topic_data in card_topics_data:
		topic_id: str = topic_data['topicId']
		# Prepare data for Firestore (excluding topicId as it's the document ID)
		firestore_topic_doc: Dict[str, Any] = {
			'topicName': topic_data['topicName'],
			'language': topic_data['language'],
			'description': topic_data['description'],
			'cards': topic_data['cards']
		}
		
		# Validate cards structure slightly
		for card_index, card_item in enumerate(firestore_topic_doc['cards']):
			if card_item.get('type') == 'black' and 'pick' not in card_item:
				logger.warning(
					f"Topic '{topic_id}', card index {card_index} ('{card_item.get('text', 'N/A')}') "
					f"is 'black' but missing 'pick' field. Defaulting pick to 1."
				)
				card_item['pick'] = 1 # Default if missing, or you could raise an error
			elif card_item.get('type') == 'white' and 'pick' in card_item:
				logger.warning(
					f"Topic '{topic_id}', card index {card_index} ('{card_item.get('text', 'N/A')}') "
					f"is 'white' but has 'pick' field. Removing it."
				)
				del card_item['pick']


		try:
			doc_ref = db.collection(CARD_TOPICS_COLLECTION).document(topic_id)
			doc_ref.set(firestore_topic_doc)
			logger.info(f"Successfully uploaded topic: {topic_id}")
		except Exception as e:
			logger.error(f"Failed to upload topic {topic_id}: {e}")
	logger.info("Firestore population completed.")

def main() -> None:
	"""
	Main function to orchestrate Firebase initialization and Firestore population.
	"""
	try:
		db_client: FirestoreClient = initialize_firebase_app() # Changed type hint
		all_card_topics: List[CardTopicData] = load_card_data_from_file(CARD_DATA_FILE_PATH)
		
		# Optional: Add a confirmation step before writing to Firestore
		# proceed = input(f"Found {len(all_card_topics)} topics. Proceed with Firestore upload? (yes/no): ")
		# if proceed.lower() != 'yes':
		#     logger.info("Upload cancelled by user.")
		#     return
			
		populate_firestore(db_client, all_card_topics)
	except FileNotFoundError:
		logger.error("A required file was not found. Please check paths and try again.")
	except Exception as e:
		logger.error(f"An unexpected error occurred in main: {e}")

if __name__ == '__main__':
	main()


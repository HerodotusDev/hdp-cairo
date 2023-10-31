#!venv/bin/python3
import sqlite3
import os, dotenv
import time
import logging
from typing import Tuple, List, Union, Optional, Any
from tools.py.fetch_block_headers import fetch_blocks_from_rpc_no_async


# Constants
DB_PATH = "blocks.db"
HIGH_BLOCK_NUMBER = 17800000
CHUNK_SIZE = 1000
MAX_RETRIES = 3
RETRY_DELAY = 5  # delay in seconds


# Load environment variables
dotenv.load_dotenv()
RPC_URL = os.getenv("RPC_URL_MAINNET")

# Setup logging
logging.basicConfig(level=logging.INFO)


# --------------------- DATABASE HANDLING ---------------------
def create_connection() -> sqlite3.Connection:
    """Create a database connection and return it"""
    return sqlite3.connect(DB_PATH)


def setup_db(conn: sqlite3.Connection) -> None:
    """
    Initializes the SQLite database and creates necessary tables and indices.
    """
    logging.info("Setting up the database...")
    with conn:
        c = conn.cursor()
        # Create table if it doesn't exist
        logging.info("Checking or creating the blocks table...")
        c.execute(
            """
            CREATE TABLE IF NOT EXISTS blocks (
                block_number INTEGER PRIMARY KEY,
                blockheader BLOB
            );
        """
        )
    logging.info("Database setup completed!")


def get_min_max_block_numbers(
    conn: sqlite3.Connection,
) -> Tuple[Optional[int], Optional[int]]:
    """Return the minimum and maximum block numbers from the database."""
    c = conn.cursor()
    c.execute("SELECT MIN(block_number), MAX(block_number) FROM blocks")
    return c.fetchone()


def fetch_block_range_from_db(
    start: int, end: int, conn: sqlite3.Connection
) -> List[Tuple[int, bytes]]:
    """
    Fetches blocks from the database for a given range.

    Args:
        start (int): Start block number.
        end (int): End block number.
        conn: The SQLite database connection object.

    Returns:
        list: List of block headers from the database.
    """
    c = conn.cursor()
    c.execute(
        "SELECT block_number, blockheader FROM blocks WHERE block_number BETWEEN ? AND ? ORDER BY block_number ASC",
        (start, end),
    )
    return c.fetchall()


# --------------------- BLOCK FETCHING & INSERTION ---------------------
def get_block_numbers(start: int, end: int) -> List[Tuple[int, bytes]]:
    """Fetch block headers within a range, handling retries."""
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            block_headers = fetch_blocks_from_rpc_no_async(
                range_from=end, range_till=start - 1, rpc_url=RPC_URL, delay=0
            )
            return [(x.number, x.raw_rlp()) for x in block_headers][::-1]
        except Exception as e:
            if attempt < MAX_RETRIES:
                logging.warning(
                    f"Error fetching block headers. Attempt {attempt}/{MAX_RETRIES}. "
                    f"Retrying in {RETRY_DELAY} seconds. Error: {e}"
                )
                time.sleep(RETRY_DELAY)
            else:
                logging.error(
                    f"Failed to fetch block headers after {MAX_RETRIES} attempts. Error: {e}"
                )
                raise


def insert_block_data(start: int, end: int, conn: sqlite3.Connection) -> None:
    """Insert fetched block data into the database."""
    block_headers = get_block_numbers(start, end)
    with conn:
        # Execute the many insertions
        conn.executemany(
            "INSERT OR IGNORE INTO blocks (block_number, blockheader) VALUES (?, ?)",
            block_headers,
        )


# --------------------- INTEGRITY CHECK ---------------------
def check_db_integrity(conn: sqlite3.Connection) -> None:
    """
    Checks database integrity by verifying block count.
    """
    min_block, max_block = get_min_max_block_numbers(conn)
    if min_block is None or max_block is None:
        logging.info("No blocks in the database yet.")
        return

    expected_count = max_block - min_block + 1

    c = conn.cursor()
    c.execute("SELECT COUNT(*) FROM blocks")
    (actual_count,) = c.fetchone()

    if expected_count != actual_count:
        raise ValueError(
            f"Database integrity check failed! Expected {expected_count} entries but found {actual_count}."
        )
    else:
        logging.info(
            f"Data integrity ok: Expected {expected_count} and got {actual_count}."
        )


# --------------------- MAIN EXECUTION ---------------------


def main() -> None:
    with create_connection() as conn:
        setup_db(conn)
        check_db_integrity(conn)

        _, max_block = get_min_max_block_numbers(conn)
        start_from = 0 if max_block is None else max_block + 1
        # Tracking fetch statistics
        total_fetch_time = 0.0
        total_fetch_count = 0

        # Main fetching loop
        print("\n")
        logging.info(f"Fetching blocks from {start_from} to {HIGH_BLOCK_NUMBER}...\n")
        while start_from <= HIGH_BLOCK_NUMBER:
            end_at = min(start_from + CHUNK_SIZE - 1, HIGH_BLOCK_NUMBER)

            t0 = time.time()
            insert_block_data(start_from, end_at, conn)
            fetch_duration = time.time() - t0

            total_fetch_time += fetch_duration
            total_fetch_count += 1
            # Logging statistics every 8 iterations
            if total_fetch_count & 7 == 0:
                average_time_per_fetch = total_fetch_time / total_fetch_count
                estimated_remaining_fetches = (HIGH_BLOCK_NUMBER - end_at) / CHUNK_SIZE
                estimated_time_remaining = (
                    average_time_per_fetch * estimated_remaining_fetches
                )

                logging.info(
                    f"Fetched and inserted blocks from {start_from} to {end_at} in {fetch_duration:.4f} seconds."
                    f"\n\tEstimated time remaining: {estimated_time_remaining/3600:.4f} hours."
                    f"\n\tAverage time per fetch: {average_time_per_fetch:.4f} seconds."
                    f"\n\tEstimated remaining fetches: {estimated_remaining_fetches}."
                )
            else:
                logging.info(
                    f"Fetched and inserted blocks from {start_from} to {end_at} in {fetch_duration:.4f} seconds."
                )

            start_from = end_at + 1
        # Post-fetching integrity check
        check_db_integrity(conn)


if __name__ == "__main__":
    main()

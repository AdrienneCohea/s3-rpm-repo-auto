import os
import subprocess
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def handler(event, context):
    """
    Lambda handler to update or initialize an RPM repository.
    """
    repo_dir = os.environ.get("REPO_PATH", "/mnt/repo")
    repodata_dir = os.path.join(repo_dir, "repodata")
    
    logger.info(f"Checking for repodata in {repo_dir}")
    
    # Check if the repository has been initialized
    if not os.path.exists(repodata_dir):
        logger.info("repodata not found. Initializing repository...")
        # Initial creation
        cmd = ["createrepo_c", repo_dir]
    else:
        logger.info("repodata found. Updating repository...")
        # Incremental update
        cmd = ["createrepo_c", "--update", repo_dir]
    
    try:
        # Run createrepo_c and capture output
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        logger.info("createrepo_c completed successfully.")
        # Log only a summary if needed, avoiding potentially verbose/sensitive output
        # logger.debug(f"createrepo_c output: {result.stdout}")
        
        return {
            'statusCode': 200,
            'body': 'Indexing completed successfully'
        }
    except subprocess.CalledProcessError as e:
        logger.error(f"Error running createrepo_c: {e.stderr}")
        return {
            'statusCode': 500,
            'body': f'Indexing failed: {e.stderr}'
        }

if __name__ == "__main__":
    # Allow local execution for testing purposes
    handler(None, None)

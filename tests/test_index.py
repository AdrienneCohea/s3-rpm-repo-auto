import os
import unittest
from unittest.mock import patch, MagicMock
import sys

# Add the lambda-image directory to the path so we can import index
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'lambda-image'))
import index

class TestLambdaHandler(unittest.TestCase):

    @patch('index.subprocess.run')
    @patch('index.os.path.exists')
    def test_handler_init(self, mock_exists, mock_run):
        # Scenario: repodata does not exist
        mock_exists.return_value = False
        mock_run.return_value = MagicMock(stdout="success", stderr="", returncode=0)
        
        event = {}
        context = MagicMock()
        
        response = index.handler(event, context)
        
        self.assertEqual(response['statusCode'], 200)
        self.assertIn('Indexing completed successfully', response['body'])
        
        # Verify createrepo_c was called without --update
        mock_run.assert_called_once()
        args, kwargs = mock_run.call_args
        self.assertEqual(args[0], ["createrepo_c", "/mnt/repo"])

    @patch('index.subprocess.run')
    @patch('index.os.path.exists')
    def test_handler_update(self, mock_exists, mock_run):
        # Scenario: repodata exists
        mock_exists.return_value = True
        mock_run.return_value = MagicMock(stdout="success", stderr="", returncode=0)
        
        event = {}
        context = MagicMock()
        
        response = index.handler(event, context)
        
        self.assertEqual(response['statusCode'], 200)
        
        # Verify createrepo_c was called with --update
        mock_run.assert_called_once()
        args, kwargs = mock_run.call_args
        self.assertEqual(args[0], ["createrepo_c", "--update", "/mnt/repo"])

    @patch('index.subprocess.run')
    @patch('index.os.path.exists')
    def test_handler_failure(self, mock_exists, mock_run):
        # Scenario: createrepo_c fails
        mock_exists.return_value = True
        import subprocess
        mock_run.side_effect = subprocess.CalledProcessError(1, 'createrepo_c', stderr='error message')
        
        event = {}
        context = MagicMock()
        
        response = index.handler(event, context)
        
        self.assertEqual(response['statusCode'], 500)
        self.assertIn('Indexing failed', response['body'])

if __name__ == '__main__':
    unittest.main()

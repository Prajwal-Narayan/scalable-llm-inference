import json
import random
from locust import HttpUser, task, between

# Tactical Scenario Prompts
PROMPTS = [
    "Explain the strategic importance of logistics in modern warfare.",
    "Analyze the difference between strategy and tactics.",
    "Summarize the key components of a Kubernetes architecture.",
    "Write a Python function to calculate the Fibonacci sequence.",
    "Draft a briefing for a high-stakes mission to deploy an AI model.",
    "What are the primary bottlenecks in GPU inference?",
    "Explain the concept of 'Fog of War' in information security.",
    "Describe the role of a Staff Engineer in a tech organization."
]

class TitanUser(HttpUser):
    # Wait 1-3 seconds between tasks (Simulate human/system thinking time)
    wait_time = between(1, 3)

    @task
    def generate_intelligence(self):
        prompt = random.choice(PROMPTS)
        
        # The Payload (OpenAI Compatible)
        payload = {
            "model": "mistralai/Ministral-3-14B-Instruct-2512",
            "messages": [
                {"role": "system", "content": "You are a high-performance reasoning engine."},
                {"role": "user", "content": prompt}
            ],
            "max_tokens": 64,  # Keep output short for throughput testing
            "temperature": 0.7
        }

        # Fire Mission
        with self.client.post(
            "/v1/chat/completions", 
            data=json.dumps(payload),
            headers={"Content-Type": "application/json"},
            catch_response=True
        ) as response:
            if response.status_code == 200:
                response.success()
            else:
                # Log casualties
                response.failure(f"Status: {response.status_code} | Error: {response.text}")
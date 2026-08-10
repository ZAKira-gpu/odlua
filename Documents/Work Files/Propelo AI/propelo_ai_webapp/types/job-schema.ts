// Canonical Job Schema

interface Job {
  jobTitle: string;
  description: string;
  budget?: number; // Optional if not available
  skills: string[];
  postedDate?: string; // Optional, could be Date string
  // Add other fields as needed based on platform specifics
}

// JSON Schema representation
const jobSchema = {
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Job Posting",
  "type": "object",
  "properties": {
    "jobTitle": {
      "type": "string"
    },
    "description": {
      "type": "string"
    },
    "budget": {
      "type": "number"
    },
    "skills": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "postedDate": {
      "type": "string",
      "format": "date-time"
    }
  },
  "additionalProperties": false, // Disallow extra fields for safety
  "required": ["jobTitle", "description"] // Ensure these are always present
};
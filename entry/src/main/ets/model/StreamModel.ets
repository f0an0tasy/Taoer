interface delta {
  "role": string,
  "content": string,
  "reasoning_content": string
}

interface choices {
  "index": number,
  "delta": delta,
  "finish_reason": string
}

interface usage {
  "prompt_tokens": number,
  "completion_tokens": number,
  "total_tokens": number
}

export interface StreamResult {
  "id": string,
  "object": string,
  "created": number,
  "model": string,
  "choices": choices[],
  "usage": usage,
  "system_fingerprint": string
}
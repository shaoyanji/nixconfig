package main

import (
	"reflect"
	"testing"
)

func TestNormalizeMessages(t *testing.T) {
	input := []interface{}{
		map[string]interface{}{"role": "system", "content": "System prompt 1"},
		map[string]interface{}{"role": "system", "content": "System prompt 2"},
		map[string]interface{}{"role": "user", "content": "Hello"},
		map[string]interface{}{"role": "user", "content": "State JSON"},
	}

	expected := []interface{}{
		map[string]interface{}{"role": "system", "content": "System prompt 1\n\nSystem prompt 2"},
		map[string]interface{}{"role": "user", "content": "Hello"},
		map[string]interface{}{"role": "user", "content": "State JSON"},
	}

	output := normalizeMessages(input)
	if !reflect.DeepEqual(output, expected) {
		t.Fatalf("Expected %+v, got %+v", expected, output)
	}
}

func TestCleanResponseContent(t *testing.T) {
	// Case 1: <think> tags followed by markdown fenced JSON
	input1 := "<think>\nThinking steps here\n</think>\n\n```json\n{\"actions\":[],\"answer\":\"Hello!\"}\n```"
	expected1 := "{\"actions\":[],\"answer\":\"Hello!\"}"
	if out := cleanResponseContent(input1, true); out != expected1 {
		t.Errorf("Test 1 failed. Expected %q, got %q", expected1, out)
	}

	// Case 2: Just <think> tags with regular text
	input2 := "<think>\nSome thought\n</think>\n\nHello there!"
	expected2 := "Hello there!"
	if out := cleanResponseContent(input2, false); out != expected2 {
		t.Errorf("Test 2 failed. Expected %q, got %q", expected2, out)
	}
}

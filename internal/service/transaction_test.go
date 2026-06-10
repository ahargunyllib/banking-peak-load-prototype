package service

import (
	"strings"
	"testing"
	"time"
)

func TestNewTransactionIDUsesSeedCompatibleFormat(t *testing.T) {
	t.Parallel()

	id := newTransactionID(time.Unix(1_700_000_000, 123_456_789))

	if !strings.HasPrefix(id, "txn") {
		t.Fatalf("expected txn prefix, got %q", id)
	}
	if len(id) != 25 {
		t.Fatalf("expected txn plus 22 digits, got %q with length %d", id, len(id))
	}
	for _, char := range id[3:] {
		if char < '0' || char > '9' {
			t.Fatalf("expected numeric suffix, got %q", id)
		}
	}
}

func TestNewTransactionIDAddsSequenceEntropy(t *testing.T) {
	t.Parallel()

	now := time.Unix(1_700_000_000, 123_456_789)
	first := newTransactionID(now)
	second := newTransactionID(now)

	if first == second {
		t.Fatalf("expected IDs generated in the same instant to differ, got %q", first)
	}
}

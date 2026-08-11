package cmd

import (
	"testing"

	"github.com/spf13/cobra"
)

func TestOptionalFloat64Flag(t *testing.T) {
	cmd := &cobra.Command{}
	var value float64
	cmd.Flags().Float64Var(&value, "value", 0, "")

	if got := optionalFloat64Flag(cmd, "value", value); got != nil {
		t.Fatalf("optionalFloat64Flag() = %v before flag is set, want nil", *got)
	}

	if err := cmd.Flags().Set("value", "1785499200.25"); err != nil {
		t.Fatalf("setting flag: %v", err)
	}
	got := optionalFloat64Flag(cmd, "value", value)
	if got == nil || *got != 1785499200.25 {
		t.Fatalf("optionalFloat64Flag() = %v after flag is set, want 1785499200.25", got)
	}
}

func TestBuildAddTwapParamsIncludesOptionalExecutionControls(t *testing.T) {
	originalStartTime, originalWorstPrice := twapStartTime, twapWorstPrice
	t.Cleanup(func() {
		twapStartTime = originalStartTime
		twapWorstPrice = originalWorstPrice
	})

	twapStartTime = 1785499200.25
	twapWorstPrice = 65000.5
	cmd := &cobra.Command{}
	cmd.Flags().Float64("start-time", 0, "")
	cmd.Flags().Float64("worst-price", 0, "")
	if err := cmd.Flags().Set("start-time", "1785499200.25"); err != nil {
		t.Fatalf("setting start-time: %v", err)
	}
	if err := cmd.Flags().Set("worst-price", "65000.5"); err != nil {
		t.Fatalf("setting worst-price: %v", err)
	}

	params := buildAddTwapParams(cmd)
	if params.StartTime == nil || *params.StartTime != twapStartTime {
		t.Fatalf("StartTime = %v, want %v", params.StartTime, twapStartTime)
	}
	if params.WorstPrice == nil || *params.WorstPrice != twapWorstPrice {
		t.Fatalf("WorstPrice = %v, want %v", params.WorstPrice, twapWorstPrice)
	}
}
